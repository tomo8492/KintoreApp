// MARK: - StoreKitClient
// CLAUDE.md §-1.14 / §11.4 準拠。com.tomo.workoutkit.pro.unlock の購入・復元・
// エンタイトルメント監視を StoreKit 2 で実装する。
//
// 設計メモ
// - actor で 1 インスタンス保持。AppDependency 経由で View に注入する(Singleton 禁止)。
// - Pro 状態の唯一の真実は Transaction.currentEntitlements。ローカルにキャッシュしない。
// - 起動時に listenForTransactions() を呼ぶことで App 外(購入の払い戻し / 家族共有解除)で
//   発生した変更も反映できる(Apple Guideline 3.1.1 必須事項)。
// - View には触れない(F2: PaywallView は別タスク)。

import Foundation
import OSLog
import StoreKit

/// 購入フローの結果。UI 層で Paywall の遷移先を決める用途。
enum PurchaseResult: Equatable, Sendable {
    /// 購入成功。エンタイトルメントは反映済み。
    case success
    /// ユーザーがダイアログでキャンセル。
    case userCancelled
    /// Ask to Buy / SCA 等で保留中。`Transaction.updates` で後追い反映される。
    case pending
    /// 検証に失敗(JWS 不正)。レシートを破棄して再試行を促す。
    case verificationFailed
    /// 既知の値以外を受け取った場合のフォールバック。
    case unknown
}

/// StoreKit 2 の購入・復元・購読を担う actor。
///
/// 利用フロー(WorkoutKitApp.swift から):
/// ```
/// let client = StoreKitClient(proGate: proGate)
/// await client.start()              // 起動時に 1 回
/// // ...
/// let result = try await client.purchase()
/// try await client.restorePurchases()
/// ```
actor StoreKitClient {

    // MARK: - 定数

    /// CLAUDE.md §-1.1 / §-1.14 の確定値。
    static let proProductID = "com.tomo.workoutkit.pro.unlock"

    // MARK: - 依存

    private let productIDs: Set<String>
    private let proGate: ProFeatureGate

    // MARK: - 状態

    /// `Product.products(for:)` で取得したキャッシュ。Paywall 表示で価格を出す用途。
    private(set) var cachedProduct: Product?

    /// `Transaction.updates` を購読するタスク。`start()` で起動 → `stop()` で破棄。
    private var transactionListener: Task<Void, Never>?

    private var didStart: Bool = false

    // MARK: - Init

    /// Test では productIDs を差し替えられるよう引数化している。
    /// 既定値で `Self.proProductID` を参照すると covariant-Self エラーになるため、
    /// 型名 `StoreKitClient.proProductID` を直接参照する。
    init(
        proGate: ProFeatureGate,
        productIDs: Set<String> = [StoreKitClient.proProductID]
    ) {
        self.proGate = proGate
        self.productIDs = productIDs
    }

    deinit {
        // actor の deinit から actor-isolated state を触るのは Swift 5.10 で許可されている。
        transactionListener?.cancel()
    }

    // MARK: - ライフサイクル

    /// 起動時に 1 度だけ呼ぶ。多重呼び出しは no-op。
    /// - Loads product metadata
    /// - Refreshes entitlements (Pro 状態の初期同期)
    /// - Starts the Transaction.updates listener
    func start() async {
        guard !didStart else { return }
        didStart = true

        await refreshProducts()
        await refreshEntitlements()
        listenForTransactions()
    }

    /// テストや明示的なクリーンアップ用。Transaction.updates の購読を止める。
    func stop() {
        transactionListener?.cancel()
        transactionListener = nil
        didStart = false
    }

    /// シーンが `.active` に復帰した直後の再同期フック。
    /// 家族共有解除や別端末での払戻しは Transaction.updates 経由でも届くが、
    /// バックグラウンド長期化やネットワーク不通から戻ってきた直後は遅延する。
    /// scene 復帰時に Transaction.currentEntitlements を即評価して `proGate.isPro` を
    /// 同期する(初回 start 後にのみ走らせ、未起動状態では no-op)。
    func refreshEntitlementsOnForeground() async {
        guard didStart else { return }
        await refreshEntitlements()
    }

    // MARK: - 購入 / 復元

    /// Pro IAP の購入フロー。
    /// `@MainActor` ではないので、UI からは `Task { try await client.purchase() }` 経由で呼ぶ。
    /// 成功すると ProFeatureGate.isPro が true になっている。
    func purchase() async throws -> PurchaseResult {
        let product = try await ensureProduct()

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            Logger.store.error("purchase failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.purchaseFailed(String(describing: error))
        }

        switch result {
        case .success(let verification):
            return try await handlePurchaseSuccess(verification)
        case .userCancelled:
            Logger.store.info("purchase cancelled by user")
            return .userCancelled
        case .pending:
            Logger.store.info("purchase pending (Ask to Buy / SCA)")
            return .pending
        @unknown default:
            Logger.store.error("purchase returned unknown result")
            return .unknown
        }
    }

    /// 復元購入。Apple Guideline 3.1.1 で Non-Consumable IAP の必須実装。
    /// AppStore.sync() でレシートを再取得 → currentEntitlements を再評価する。
    /// - Returns: 復元できた有効な Pro エンタイトルメントが1件以上あれば `true`。
    @discardableResult
    func restorePurchases() async throws -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            Logger.store.error("AppStore.sync failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.purchaseFailed(String(describing: error))
        }
        await refreshEntitlements()
        return await proGate.isPro
    }

    // MARK: - 購読 (Transaction.updates)

    /// Transaction.updates を購読し、外部要因による変更(払戻/家族共有/別端末購入)を取り込む。
    /// 既に走っているタスクがあれば作り直す。
    func listenForTransactions() {
        transactionListener?.cancel()
        transactionListener = Task.detached(priority: .background) { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { break }
                await self.handleTransactionUpdate(verification)
            }
        }
    }

    // MARK: - 内部処理

    /// Product.products(for:) を呼んでキャッシュする。失敗してもアプリは起動させる。
    /// 失敗パターン分析のため、空配列 / ID 不一致 / 例外を区別してログに残す。
    private func refreshProducts() async {
        let requestedIDs = Array(productIDs).joined(separator: ",")
        Logger.store.info("Product.products requested: ids=\(requestedIDs, privacy: .public)")
        do {
            let products = try await Product.products(for: productIDs)
            cachedProduct = products.first { $0.id == Self.proProductID }
            if cachedProduct == nil {
                if products.isEmpty {
                    // BUG 5 診断ログ: StoreKit Configuration がスキームに付いていない
                    // か、シミュレータが scheme を読んでいない場合は配列が空になる。
                    // (xcrun simctl launch 直接起動時はスキーム由来の Configuration
                    //  が適用されないので空になりがち)
                    Logger.store.error("Product.products returned empty — likely no StoreKit Configuration is attached to this run. Check the Run scheme's StoreKit Configuration setting.")
                } else {
                    let returnedIDs = products.map(\.id).joined(separator: ",")
                    Logger.store.error("Pro product not found in StoreKit response. requested=\(requestedIDs, privacy: .public) returned=\(returnedIDs, privacy: .public). Check that the Configuration file's productID matches StoreKitClient.proProductID.")
                }
            } else {
                Logger.store.info("Pro product loaded: \(self.cachedProduct?.id ?? "?", privacy: .public)")
            }
        } catch {
            let message = error.localizedDescription
            Logger.store.error("Product.products failed: \(message, privacy: .public)")
        }
    }

    /// Transaction.currentEntitlements を走査して Pro の有無を再評価する。
    /// 払戻 (revocationDate != nil) は Pro 喪失として扱う。
    private func refreshEntitlements() async {
        var hasPro = false
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            guard transaction.productID == Self.proProductID else { continue }
            if transaction.revocationDate == nil {
                hasPro = true
            }
        }
        await proGate.setIsPro(hasPro)
        Logger.store.info("entitlements refreshed: isPro=\(hasPro, privacy: .public)")
    }

    /// 購入成功時の共通処理。検証 → finish → エンタイトルメント反映。
    private func handlePurchaseSuccess(
        _ verification: VerificationResult<Transaction>
    ) async throws -> PurchaseResult {
        switch verification {
        case .verified(let transaction):
            if transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                await proGate.setIsPro(true)
            }
            await transaction.finish()
            Logger.store.info("purchase verified & finished: \(transaction.productID, privacy: .public)")
            return .success
        case .unverified(_, let error):
            Logger.store.error("purchase unverified: \(error.localizedDescription, privacy: .public)")
            return .verificationFailed
        }
    }

    /// Transaction.updates から流れてきたイベントを反映する。
    /// 外部要因(払戻/家族共有解除/別端末購入)で revocationDate が立つことがある。
    private func handleTransactionUpdate(
        _ verification: VerificationResult<Transaction>
    ) async {
        switch verification {
        case .verified(let transaction):
            guard transaction.productID == Self.proProductID else {
                await transaction.finish()
                return
            }
            let isPro = transaction.revocationDate == nil
            await proGate.setIsPro(isPro)
            await transaction.finish()
            Logger.store.info("Transaction.updates applied: isPro=\(isPro, privacy: .public)")
        case .unverified(_, let error):
            Logger.store.error("Transaction.updates unverified: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 商品ロードが終わっていなければ on-demand で取得する。
    private func ensureProduct() async throws -> Product {
        if let cachedProduct { return cachedProduct }
        await refreshProducts()
        guard let cachedProduct else {
            throw AppError.purchaseFailed("Pro product unavailable")
        }
        return cachedProduct
    }
}

// MARK: - PurchaseRestoring 準拠
// E3 Settings の Restore Purchase 抽象。
// actor 隔離を跨ぐため extension で nonisolated に再宣言する。

extension StoreKitClient: PurchaseRestoring {}


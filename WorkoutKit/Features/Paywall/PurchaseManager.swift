// MARK: - PurchaseManager
// CLAUDE.md v0.5 §-1.1 / §-1.14 / §11.4 準拠。
//
// RevenueCat の `Purchases.shared` を **唯一隠蔽するラッパ**。
// View / Store からは本 actor 越しにしか課金状態を触らない(NG リスト遵守)。
//
// 役割:
//   1. アプリ起動時に Purchases.configure(...) を 1 回呼ぶ(`AppDependency` から)
//   2. Offerings(月 / 年プラン)を取得して PaywallView に渡す
//   3. 購入 / 復元を実行し、`premium` Entitlement の有無で `ProFeatureGate.isPro` を更新
//   4. RevenueCat delegate(購入状態変更)を受け、isPro を同期
//
// 注意:
//   - RevenueCat の `Purchases.configure(withAPIKey:)` は完全な singleton API。
//     呼び忘れると `Purchases.shared` が trap する。configure(_:) で nil ガード。
//   - 既存 `StoreKitClient` は v0.5 では使わない方針だが、Restore Purchases 経路の
//     冗長性 / sandbox 検証用に残置(後続 PR で削除予定)。
//   - actor 隔離。UI からは `await pm.refreshOfferings()` で呼ぶ。
//
// Linux 環境では `import RevenueCat` ができないため、本ファイルは Mac で
// SPM 解決後にしかビルドできない。型シグネチャは RevenueCat 5.x のものに合わせる。

import Foundation
import OSLog
import RevenueCat

// MARK: - 公開エラー型

enum PurchaseError: LocalizedError {
    case notConfigured            // API キー未設定 / configure 未呼び出し
    case noOfferings              // RevenueCat ダッシュボード未設定
    case productNotAvailable      // 月 or 年のいずれかが loadable に居ない
    case userCancelled            // 購入キャンセル(エラー扱いしない)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:        return String(localized: "purchase.error.not-configured")
        case .noOfferings:          return String(localized: "purchase.error.no-offerings")
        case .productNotAvailable:  return String(localized: "purchase.error.no-product")
        case .userCancelled:        return String(localized: "purchase.error.cancelled")
        case .underlying(let msg):  return msg
        }
    }
}

// MARK: - 公開モデル(Paywall / Settings から参照)

/// View に渡す表示用の Offering 情報。RevenueCat の型を直接漏らさない。
struct PurchaseOffering: Sendable, Equatable {
    let monthly: PurchasePlan?
    let yearly: PurchasePlan?
}

struct PurchasePlan: Sendable, Equatable {
    let productID: String
    let displayPrice: String       // ロケール整形済(例: "¥980" / "¥4,900")
    let trialDays: Int?            // 7 / nil
    /// 内部用に rcPackage を握っておく(actor 越しでも Sendable のため id だけ持つ)。
    let rcIdentifier: String
}

enum PurchaseResultOutcome: Sendable, Equatable {
    case success
    case cancelled
    case pending           // App Store の保留(承認待ち)
}

// MARK: - PurchaseManager

actor PurchaseManager {

    // MARK: - Dependencies / state

    private let proGate: ProFeatureGate
    private var isConfigured: Bool = false
    /// 最後に取得した Offerings の生 Package(`purchase(_:)` 時に必要)。
    private var cachedPackages: [String: Package] = [:]

    // MARK: - Init

    init(proGate: ProFeatureGate) {
        self.proGate = proGate
    }

    // MARK: - Configure (起動時 1 回)

    /// アプリ起動時に AppDependency / WorkoutKitApp から 1 回だけ呼ぶ。
    /// API キーが nil の場合は configure をスキップしてログだけ残す(ビルド可能だが
    /// 購入は失敗する。Secrets.xcconfig 未配置時の安全弁)。
    func configureIfPossible() {
        guard !isConfigured else { return }
        guard let apiKey = AppSecrets.revenueCatAPIKey else {
            Logger.store.error("RevenueCat API key missing — Purchases.configure skipped")
            return
        }
        Purchases.configure(withAPIKey: apiKey)
        // ユーザー識別は匿名(`$RCAnonymousID:*`)で十分。Apple ID 連携は v1.1+ で検討。
        isConfigured = true
        Logger.store.info("RevenueCat configured (anonymous user)")
    }

    // MARK: - Offerings

    /// PaywallView 表示時に呼ぶ。月 / 年プランを `PurchaseOffering` として返す。
    func fetchOffering() async throws -> PurchaseOffering {
        guard isConfigured else { throw PurchaseError.notConfigured }
        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            throw PurchaseError.underlying(error.localizedDescription)
        }
        guard let current = offerings.current else { throw PurchaseError.noOfferings }

        // current.monthly / .annual は RevenueCat 標準の "duration" 命名。
        // ダッシュボード側で identifier を変えても、duration プロパティで取り出せる。
        let monthlyPkg = current.monthly
        let yearlyPkg = current.annual

        // 内部キャッシュに格納(purchase 時に identifier から逆引きする)。
        cachedPackages.removeAll()
        if let p = monthlyPkg { cachedPackages[p.identifier] = p }
        if let p = yearlyPkg  { cachedPackages[p.identifier] = p }

        return PurchaseOffering(
            monthly: monthlyPkg.map { plan(from: $0) },
            yearly:  yearlyPkg.map  { plan(from: $0) }
        )
    }

    private func plan(from package: Package) -> PurchasePlan {
        let product = package.storeProduct
        let trialDays = product.introductoryDiscount.map { Self.daysIn($0.subscriptionPeriod) }
        return PurchasePlan(
            productID: product.productIdentifier,
            displayPrice: product.localizedPriceString,
            trialDays: trialDays,
            rcIdentifier: package.identifier
        )
    }

    /// `SubscriptionPeriod` を概算「日数」に変換する。
    /// HardPaywallView の「7-day free trial」表記用なので月/年は近似でよい
    /// (商品の最少単位は通常 .day か .week なので近似誤差は気にしない)。
    private static func daysIn(_ period: SubscriptionPeriod) -> Int {
        let n = period.value
        switch period.unit {
        case .day:   return n
        case .week:  return n * 7
        case .month: return n * 30
        case .year:  return n * 365
        @unknown default: return n
        }
    }

    // MARK: - Purchase

    /// PaywallView の購入ボタンから呼ぶ。
    /// 結果に応じて `proGate.isPro` を更新する。
    @discardableResult
    func purchase(plan: PurchasePlan) async throws -> PurchaseResultOutcome {
        guard isConfigured else { throw PurchaseError.notConfigured }
        guard let pkg = cachedPackages[plan.rcIdentifier] else {
            throw PurchaseError.productNotAvailable
        }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            // RevenueCat 5.x はキャンセル時に throw せず result.userCancelled=true を返す。
            // ErrorCode 経由のキャンセル判定は冗長なので削除(NSError 化されているため
            // `as? ErrorCode` のキャスト自体が SDK 5.x では成立しない)。
            if result.userCancelled { return .cancelled }
            await applyEntitlements(result.customerInfo)
            return .success
        } catch {
            throw PurchaseError.underlying(error.localizedDescription)
        }
    }

    // MARK: - Restore

    /// Restore Purchases ボタンから呼ぶ(Settings / Paywall)。
    @discardableResult
    func restore() async throws -> Bool {
        guard isConfigured else { throw PurchaseError.notConfigured }
        do {
            let info = try await Purchases.shared.restorePurchases()
            await applyEntitlements(info)
            return await proGate.isPro
        } catch {
            throw PurchaseError.underlying(error.localizedDescription)
        }
    }

    // MARK: - Entitlement → ProFeatureGate

    /// CustomerInfo の `entitlements["premium"]?.isActive` を ProFeatureGate に反映。
    /// `MainActor` への切替は ProFeatureGate.setIsPro が同期して行う。
    private func applyEntitlements(_ info: CustomerInfo) async {
        let isPro = info.entitlements["premium"]?.isActive == true
        Logger.store.info("entitlement updated: isPro=\(isPro, privacy: .public)")
        await proGate.setIsPro(isPro)
    }

    // MARK: - Refresh (起動時 / フォアグラウンド復帰時)

    /// 起動時やフォアグラウンド復帰時に呼んで現在の entitlement を再評価する。
    func refreshEntitlements() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            await applyEntitlements(info)
        } catch {
            Logger.store.warning("customerInfo refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - PurchaseManager
// CLAUDE.md v1.0 §3-3 / §6-4 準拠。
//
// RevenueCat の `Purchases.shared` を隠蔽する @Observable + Singleton 課金マネージャ。
// View からは `.environment(PurchaseManager.shared)` で注入して、
// `@Environment(PurchaseManager.self) var purchaseManager` で参照する。
//
// 役割:
//   1. アプリ起動時に `configureIfPossible()` を 1 回だけ呼ぶ(`WorkoutKitApp.init` から)
//   2. Offerings(月 / 年プラン)を取得して PaywallView に渡す
//   3. 購入 / 復元を実行し、`premium` Entitlement の有無で `isPremium` を更新
//   4. `ProFeatureGate.setIsPro(_:)` 経由で既存の Pro ゲート機構を同期(後方互換)
//
// 設計メモ:
//   - v1.0 仕様の `@Observable + static let shared` に合わせて actor → MainActor class へ移行。
//     RevenueCat の SDK 呼び出しは internal な `await` ベースで隔離。
//   - `Purchases.shared` 直接利用は本ファイル内のみ許容(CLAUDE.md §11-5 例外)。
//   - API キー未設定時もアプリは起動できる(`configureIfPossible` が早期 return)。

import Foundation
import OSLog
import Observation
import RevenueCat

// MARK: - 公開エラー型

enum PurchaseError: LocalizedError, Sendable {
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

/// PaywallView に渡す表示用 Offering。RevenueCat の型を直接漏らさない。
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

@Observable
@MainActor
final class PurchaseManager {

    // MARK: - Singleton (CLAUDE.md v1.0 §6-4)

    /// `.environment(PurchaseManager.shared)` で View 階層に注入する。
    /// @MainActor class なので Swift 6 strict concurrency では static の lazy init を
    /// nonisolated context から触れるよう nonisolated(unsafe) を明示する。
    /// 初期化後の state アクセスは全て @MainActor 経由なのでデータ競合は起きない。
    nonisolated(unsafe) static let shared = PurchaseManager()

    // MARK: - Observable state

    /// プレミアム購入済みか。RevenueCat の `entitlements["premium"]?.isActive` を反映。
    /// View からは `@Environment(PurchaseManager.self).isPremium` で読む。
    var isPremium: Bool = false

    /// 購入 / 復元中のスピナー用フラグ。
    var isLoading: Bool = false

    /// 最新の Offering(PaywallView がバインドする)。
    var offering: PurchaseOffering?

    // MARK: - Internal state (Observable 対象外、private で十分)

    private var isConfigured: Bool = false
    private var cachedPackages: [String: Package] = [:]

    /// 既存コードベースの `ProFeatureGate.check(_:)` 経由のチェックを壊さないため、
    /// `setIsPro(_:)` を呼んで isPro フラグを同期する。
    /// v1.0 で `isPremium` が正本になったが、PaywallTrigger 含め 28 箇所が
    /// 旧 API を使っているため adapter として残す。
    /// `@MainActor` クロージャ型なので、AppDependency 側で
    /// `{ [weak gate] in gate?.setIsPro(\$0) }` のように書ける(assumeIsolated 不要)。
    var proGateBridge: (@MainActor @Sendable (Bool) -> Void)?

    // MARK: - Init

    /// `Purchases.configure(...)` は configureIfPossible() で呼ぶ。
    /// init では何もせず、起動シーケンスの WorkoutKitApp 側で明示的に初期化する。
    /// `nonisolated` にすることで `static let shared` の lazy init を MainActor 外
    /// (起動直後など、まだ MainActor が確立していないコンテキスト)からも安全に
    /// 通せる。Observable state には触らないので競合なし。
    nonisolated private init() {}

    // MARK: - Configure (起動時 1 回)

    /// アプリ起動時に WorkoutKitApp から 1 回だけ呼ぶ。
    /// API キーが nil の場合は configure をスキップしてログだけ残す。
    func configureIfPossible() {
        guard !isConfigured else { return }
        guard let apiKey = AppSecrets.revenueCatAPIKey else {
            Logger.store.error("RevenueCat API key missing — Purchases.configure skipped")
            return
        }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
        Logger.store.info("RevenueCat configured")

        // 初回の entitlements を非同期で取得 → isPremium を初期化
        Task { await self.refresh() }
    }

    // MARK: - Refresh (起動時 / フォアグラウンド復帰時)

    /// 最新の CustomerInfo を取得して isPremium を更新する。
    func refresh() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            Logger.store.warning("customerInfo refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Offerings

    /// PaywallView 表示時に呼ぶ。月 / 年プランを `PurchaseOffering` として返し、
    /// `self.offering` にもキャッシュする。
    @discardableResult
    func fetchOffering() async throws -> PurchaseOffering {
        guard isConfigured else { throw PurchaseError.notConfigured }
        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            throw PurchaseError.underlying(error.localizedDescription)
        }
        guard let current = offerings.current else { throw PurchaseError.noOfferings }

        let monthlyPkg = current.monthly
        let yearlyPkg = current.annual

        cachedPackages.removeAll()
        if let p = monthlyPkg { cachedPackages[p.identifier] = p }
        if let p = yearlyPkg  { cachedPackages[p.identifier] = p }

        let result = PurchaseOffering(
            monthly: monthlyPkg.map { plan(from: $0) },
            yearly:  yearlyPkg.map  { plan(from: $0) }
        )
        self.offering = result
        return result
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
    /// PaywallView の「7-day free trial」表記用の概算なので月/年は近似でよい。
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
    @discardableResult
    func purchase(plan: PurchasePlan) async throws -> PurchaseResultOutcome {
        guard isConfigured else { throw PurchaseError.notConfigured }
        guard let pkg = cachedPackages[plan.rcIdentifier] else {
            throw PurchaseError.productNotAvailable
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            // RevenueCat 5.x はキャンセル時に throw せず result.userCancelled=true を返す。
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)
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
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return isPremium
        } catch {
            throw PurchaseError.underlying(error.localizedDescription)
        }
    }

    // MARK: - Entitlement application

    /// CustomerInfo を見て isPremium を更新し、後方互換のため ProFeatureGate にも反映。
    private func apply(_ info: CustomerInfo) {
        let active = info.entitlements["premium"]?.isActive == true
        let changed = (active != isPremium)
        isPremium = active
        if changed {
            Logger.store.info("entitlement updated: isPremium=\(active, privacy: .public)")
            // ProFeatureGate 経由の 28 call site を壊さないために bridge を呼ぶ。
            proGateBridge?(active)
        }
    }
}

// MARK: - PurchaseRestoring conformance

/// Settings → Restore Purchase が呼ぶ抽象。v1.0 サブスク版では本実装が本番経路。
/// `PurchaseRestoring` は `Sendable` を要求するが、`PurchaseManager` は
/// `@MainActor` 隔離クラスなので Swift 6 では Sendable に適合する。
extension PurchaseManager: PurchaseRestoring {
    /// `restore()` の薄いブリッジ。Bool は「有効な entitlement が復元できたか」。
    func restorePurchases() async throws -> Bool {
        try await self.restore()
    }
}

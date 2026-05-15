// MARK: - LaunchTrialTracker
// CLAUDE.md v0.5 §-1.14 準拠。
//
// 「ハードペイウォール + 初回 3 日間は試用扱い」の判定を集約する。
// UserDefaults に初回起動日を保存し、現在日との差分で試用期間内/外を返す。
//
// 用途:
//   - 起動時に `shouldShowHardPaywallOnLaunch` が true なら PaywallView を提示
//   - 期間内は `isWithinTrial` が true なので、Pro 機能アクセスは全部許容
//
// テスト容易性のため、Clock(現在時刻取得)と UserDefaults を DI 可能にする。

import Foundation

@MainActor
final class LaunchTrialTracker {

    // MARK: - Constants

    /// 初回試用期間(日数)。CLAUDE.md v0.5 §-1.14 で「初回 3 日間」と確定。
    static let trialDurationDays: Int = 3

    /// 初回起動日を保存する UserDefaults キー。
    static let firstLaunchedAtKey = "workoutkit.firstLaunchedAt"

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let now: () -> Date

    /// `AppDependency.defaultValue`(EnvironmentKey protocol 要件で nonisolated)から
    /// 構築できるよう nonisolated init。引数値の取り回しのみで MainActor 隔離された
    /// 状態には触れないので安全。
    nonisolated init(
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.now = now
    }

    // MARK: - Public API

    /// 初回起動を記録する(まだ未記録のときだけ書き込む。冪等)。
    /// `WorkoutKitApp.init` あるいは最初の RootView 表示時に 1 回呼ぶ。
    @discardableResult
    func recordFirstLaunchIfNeeded() -> Date {
        if let existing = firstLaunchedAt { return existing }
        let timestamp = now()
        defaults.set(timestamp, forKey: Self.firstLaunchedAtKey)
        return timestamp
    }

    /// 既に記録済みの初回起動日(未記録なら nil)。
    var firstLaunchedAt: Date? {
        defaults.object(forKey: Self.firstLaunchedAtKey) as? Date
    }

    /// 初回起動からの経過日数(端日も含む整数)。
    /// 未記録なら 0 を返す(=今日 1 日目とみなす)。
    var daysSinceFirstLaunch: Int {
        guard let start = firstLaunchedAt else { return 0 }
        let elapsed = now().timeIntervalSince(start)
        return max(0, Int(elapsed / 86_400))
    }

    /// 初回試用期間内かどうか。期間内は Pro 機能が解放される(§-1.14)。
    var isWithinTrial: Bool {
        daysSinceFirstLaunch < Self.trialDurationDays
    }

    /// 起動時にハードペイウォールを表示するか。
    /// - 試用期間を過ぎていて
    /// - かつ Pro 未購入(`proGate.isPro == false`)
    /// の双方を満たすときのみ true。
    func shouldShowHardPaywallOnLaunch(proGate: ProFeatureGate) -> Bool {
        !isWithinTrial && !proGate.isPro
    }
}

// MARK: - LaunchTrialTrackerTests
// CLAUDE.md v1.0 §-1.14 / §6-5 / §9-1 準拠。
// 初回 3 日試用と shouldShowHardPaywallOnLaunch の境界値を凍結する。

import Foundation
import Testing
@testable import WorkoutKit

@MainActor
@Suite("LaunchTrialTracker")
struct LaunchTrialTrackerTests {

    // MARK: - Helpers

    private static func makeDefaults() -> UserDefaults {
        let suite = "wktest.launchtrial.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
            return defaults
        }
        return .standard
    }

    /// 起点となる Date(2026-05-15 12:00 JST)。
    /// Swift 6: @Sendable な `now:` クロージャから参照されるため nonisolated にする。
    nonisolated private static let baseDate = Date(timeIntervalSince1970: 1_778_240_000)

    // MARK: - First-launch recording

    @Test("recordFirstLaunchIfNeeded は初回だけ書き込む(2 回目以降は同じ日付を返す)")
    func recordIsIdempotent() {
        let defaults = Self.makeDefaults()
        let now = Self.baseDate
        let tracker = LaunchTrialTracker(defaults: defaults, now: { now })

        let first = tracker.recordFirstLaunchIfNeeded()
        // 2 回目の呼び出しは「未来日付」を与えても初回の日付を返す。
        let tracker2 = LaunchTrialTracker(
            defaults: defaults,
            now: { now.addingTimeInterval(86_400 * 7) }
        )
        let second = tracker2.recordFirstLaunchIfNeeded()

        #expect(first == second)
    }

    // MARK: - daysSinceFirstLaunch boundary

    @Test("0 日目: daysSinceFirstLaunch == 0、試用期間内")
    func dayZero() {
        let defaults = Self.makeDefaults()
        let start = Self.baseDate
        let tracker = LaunchTrialTracker(defaults: defaults, now: { start })
        tracker.recordFirstLaunchIfNeeded()

        #expect(tracker.daysSinceFirstLaunch == 0)
        #expect(tracker.isWithinTrial == true)
    }

    @Test("2 日目(48 時間後): まだ試用期間内")
    func dayTwoStillInTrial() {
        let defaults = Self.makeDefaults()
        let start = Self.baseDate
        let trackerStart = LaunchTrialTracker(defaults: defaults, now: { start })
        trackerStart.recordFirstLaunchIfNeeded()

        let later = start.addingTimeInterval(86_400 * 2 + 60) // 2 日+1 分
        let tracker = LaunchTrialTracker(defaults: defaults, now: { later })
        #expect(tracker.daysSinceFirstLaunch == 2)
        #expect(tracker.isWithinTrial == true)
    }

    @Test("3 日目(ちょうど 72 時間後): 試用期間外(境界)")
    func dayThreeIsOutOfTrial() {
        let defaults = Self.makeDefaults()
        let start = Self.baseDate
        let trackerStart = LaunchTrialTracker(defaults: defaults, now: { start })
        trackerStart.recordFirstLaunchIfNeeded()

        let later = start.addingTimeInterval(86_400 * 3 + 60) // 3 日+1 分
        let tracker = LaunchTrialTracker(defaults: defaults, now: { later })
        #expect(tracker.daysSinceFirstLaunch == 3)
        #expect(tracker.isWithinTrial == false)
    }

    @Test("初回起動を記録していない状態だと daysSinceFirstLaunch=0、試用期間内")
    func unrecordedReturnsZero() {
        let defaults = Self.makeDefaults()
        let tracker = LaunchTrialTracker(defaults: defaults, now: { Self.baseDate })
        // recordFirstLaunchIfNeeded を呼ばない
        #expect(tracker.daysSinceFirstLaunch == 0)
        #expect(tracker.isWithinTrial == true)
    }

    // MARK: - shouldShowHardPaywallOnLaunch

    @Test("試用期間内 + 未 Pro: shouldShowHardPaywallOnLaunch=false")
    func paywallNotShownDuringTrial() {
        let defaults = Self.makeDefaults()
        let start = Self.baseDate
        let tracker = LaunchTrialTracker(
            defaults: defaults,
            now: { start.addingTimeInterval(86_400) } // 1 日後
        )
        tracker.recordFirstLaunchIfNeeded()

        let gate = ProFeatureGate()
        // isPro=false がデフォルト
        #expect(tracker.shouldShowHardPaywallOnLaunch(proGate: gate) == false)
    }

    @Test("試用期間外 + 未 Pro: shouldShowHardPaywallOnLaunch=true")
    func paywallShownAfterTrialExpiry() {
        let defaults = Self.makeDefaults()
        let start = Self.baseDate
        let trackerStart = LaunchTrialTracker(defaults: defaults, now: { start })
        trackerStart.recordFirstLaunchIfNeeded()

        let later = start.addingTimeInterval(86_400 * 5)
        let tracker = LaunchTrialTracker(defaults: defaults, now: { later })

        let gate = ProFeatureGate()
        #expect(tracker.shouldShowHardPaywallOnLaunch(proGate: gate) == true)
    }

    @Test("試用期間外 + Pro 購入済み: shouldShowHardPaywallOnLaunch=false")
    func paywallNotShownForProUser() {
        let defaults = Self.makeDefaults()
        let start = Self.baseDate
        let trackerStart = LaunchTrialTracker(defaults: defaults, now: { start })
        trackerStart.recordFirstLaunchIfNeeded()

        let later = start.addingTimeInterval(86_400 * 10)
        let tracker = LaunchTrialTracker(defaults: defaults, now: { later })

        let gate = ProFeatureGate()
        gate._setProForPreview(true)
        #expect(tracker.shouldShowHardPaywallOnLaunch(proGate: gate) == false)
    }
}

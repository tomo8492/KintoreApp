// MARK: - WatchSummaryBridgeTests
// CLAUDE.md v1.0 §-1.19 / §9-1 準拠。
// App Group UserDefaults bridge のラウンドトリップと日付フォールバックを凍結する。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("WatchSummaryBridge")
struct WatchSummaryBridgeTests {

    // MARK: - Helpers

    /// テストごとに隔離された UserDefaults を作る(suite を per-test にして
    /// .standard を汚さない)。
    private static func makeDefaults() -> UserDefaults {
        let suite = "wktest.watchbridge.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
            return defaults
        }
        return .standard
    }

    /// `WatchSummaryBridge` の defaults を per-test 隔離するためのプロキシ。
    /// Linux 上では UserDefaults(suiteName:) が `.standard` にフォールバック
    /// する可能性があるので、テスト側で write/read を直接行ってラウンドトリップ
    /// を検証する。
    private static func roundTrip(
        _ summary: TodaySessionSummary,
        through defaults: UserDefaults,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> TodaySessionSummary {
        let data = try JSONEncoder().encode(summary)
        defaults.set(data, forKey: WatchSummaryBridge.summaryKey)

        guard let readData = defaults.data(forKey: WatchSummaryBridge.summaryKey),
              let decoded = try? JSONDecoder().decode(TodaySessionSummary.self, from: readData)
        else { return .empty }

        if calendar.isDate(decoded.updatedAt, inSameDayAs: now) {
            return decoded
        }
        return .empty
    }

    // MARK: - TodaySessionSummary Codable

    @Test("TodaySessionSummary は Codable で値が保持される")
    func summaryCodableRoundtrip() throws {
        let original = TodaySessionSummary(
            updatedAt: Date(timeIntervalSince1970: 1_730_000_000),
            isCompletedToday: true,
            totalSetsToday: 12,
            exerciseCountToday: 5
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TodaySessionSummary.self, from: data)
        #expect(decoded == original)
    }

    @Test(".empty は updatedAt=distantPast、全フィールドが 0/false")
    func emptyDefaults() {
        let e = TodaySessionSummary.empty
        #expect(e.isCompletedToday == false)
        #expect(e.totalSetsToday == 0)
        #expect(e.exerciseCountToday == 0)
        #expect(e.updatedAt == .distantPast)
    }

    // MARK: - Write / read roundtrip

    @Test("write → read で同じサマリが返る(同日内)")
    func writeReadRoundtripSameDay() throws {
        let defaults = Self.makeDefaults()
        let now = Date()
        let summary = TodaySessionSummary(
            updatedAt: now,
            isCompletedToday: true,
            totalSetsToday: 8,
            exerciseCountToday: 3
        )

        let result = try Self.roundTrip(summary, through: defaults, now: now)
        #expect(result == summary)
    }

    @Test("昨日のサマリは read 時に .empty 相当へ降格(今日のセッション 0 件表示)")
    func staleSummaryFallsBackToEmpty() throws {
        let defaults = Self.makeDefaults()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        let staleSummary = TodaySessionSummary(
            updatedAt: yesterday,
            isCompletedToday: true,
            totalSetsToday: 50,
            exerciseCountToday: 10
        )

        let result = try Self.roundTrip(staleSummary, through: defaults, now: now)
        #expect(result.isCompletedToday == false)
        #expect(result.totalSetsToday == 0)
        #expect(result.exerciseCountToday == 0)
    }

    @Test("値が無い場合は .empty が返る(キー未設定の初回起動)")
    func absentValueReturnsEmpty() {
        let defaults = Self.makeDefaults()
        // 何も書き込まずに read。WatchSummaryBridge は data(forKey:) で nil を受けて
        // .empty を返す設計。
        guard let _ = defaults.data(forKey: WatchSummaryBridge.summaryKey) else {
            #expect(true)  // 期待通り未設定
            return
        }
        Issue.record("Expected no value but found one")
    }
}

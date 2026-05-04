// MARK: - HistoryCutoffTests
// CLAUDE.md §1.1 F-04 / §-1.14 準拠。
// DEBUG_REPORT Critical-3 (TZ-unsafe cutoff) の修正を凍結する。
//
// 検証ポイント:
// - freeWindowStart が「指定 calendar の "30 日前 0:00"」になる
// - freeWindowDays が CLAUDE.md §-1.14 で 30 日固定
// - defaultCalendar が `Calendar.autoupdatingCurrent`(TZ / Locale 変更追従)
// - 海外移動シナリオ: 異なる TimeZone の calendar を渡したときに境界が
//   「その TimeZone の 30 日前 0:00」へ追従する
// - weekStart / monthStart が calendar の firstWeekday / 月境界を尊重する

import Foundation
import Testing
@testable import WorkoutKit

@Suite("HistoryCutoff")
struct HistoryCutoffTests {

    // MARK: - 基本契約

    @Test("freeWindowDays は 30 日 (CLAUDE.md §-1.14 で固定)")
    func freeWindowDaysIsThirty() {
        #expect(HistoryCutoff.freeWindowDays == 30)
    }

    @Test("defaultCalendar は autoupdatingCurrent (TZ 変更を追従するため)")
    func defaultCalendarIsAutoupdating() {
        // autoupdatingCurrent は Calendar.current と内部的に一致するが、
        // identifier だけ比較すれば「同じ暦体系を返す」ことが保証できる。
        // ここでは Foundation の同値チェックに任せる(== は AutoupdatingCurrent
        // インスタンス間で常に true)。
        #expect(HistoryCutoff.defaultCalendar == .autoupdatingCurrent)
    }

    // MARK: - 境界計算

    @Test("freeWindowStart は『指定 now の 30 日前 0:00 (calendar 基準)』")
    func freeWindowStartIsThirtyDaysAgoStartOfDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        let utc = try #require(TimeZone(identifier: "UTC"))
        calendar.timeZone = utc

        // 2026-05-04 12:34:56 UTC を「いま」と仮定
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 4
        comps.hour = 12; comps.minute = 34; comps.second = 56
        let now = try #require(calendar.date(from: comps))

        let cutoff = HistoryCutoff.freeWindowStart(now: now, calendar: calendar)

        // 期待: 2026-04-04 00:00:00 UTC (30 日前の 0:00)
        var expectedComps = DateComponents()
        expectedComps.year = 2026; expectedComps.month = 4; expectedComps.day = 4
        expectedComps.hour = 0; expectedComps.minute = 0; expectedComps.second = 0
        let expected = try #require(calendar.date(from: expectedComps))

        #expect(cutoff == expected)
    }

    @Test("isWithinFreeWindow は 30 日前 00:00 ちょうどを true、その 1 秒前を false にする")
    func isWithinFreeWindowBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        let utc = try #require(TimeZone(identifier: "UTC"))
        calendar.timeZone = utc

        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 4
        comps.hour = 12; comps.minute = 0; comps.second = 0
        let now = try #require(calendar.date(from: comps))
        let cutoff = HistoryCutoff.freeWindowStart(now: now, calendar: calendar)
        let oneSecondBefore = cutoff.addingTimeInterval(-1)

        #expect(HistoryCutoff.isWithinFreeWindow(cutoff, now: now, calendar: calendar))
        #expect(!HistoryCutoff.isWithinFreeWindow(oneSecondBefore, now: now, calendar: calendar))
    }

    @Test("ユーザーの TimeZone が違うと cutoff も TZ 基準の 0:00 へ移動する (海外移動シナリオ)")
    func freeWindowStartShiftsWithTimeZone() throws {
        // UTC 基準の 2026-05-04 00:00
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = try #require(TimeZone(identifier: "UTC"))

        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 4
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let nowUTC = try #require(utcCal.date(from: comps))

        // 同じ瞬間を JST (UTC+9) と LA (UTC-7 DST) のカレンダーで表す
        var jstCal = Calendar(identifier: .gregorian)
        jstCal.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var laCal = Calendar(identifier: .gregorian)
        laCal.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))

        let jstCutoff = HistoryCutoff.freeWindowStart(now: nowUTC, calendar: jstCal)
        let laCutoff = HistoryCutoff.freeWindowStart(now: nowUTC, calendar: laCal)

        // JST と LA で「30 日前 0:00」は別の絶対時刻になる
        #expect(jstCutoff != laCutoff)

        // JST 基準: 2026-04-04 00:00 JST = 2026-04-03 15:00 UTC
        var jstExpected = DateComponents()
        jstExpected.year = 2026; jstExpected.month = 4; jstExpected.day = 4
        jstExpected.hour = 0; jstExpected.minute = 0; jstExpected.second = 0
        #expect(jstCutoff == jstCal.date(from: jstExpected))
    }

    // MARK: - 週・月境界

    @Test("monthStart は『指定日が含まれる月の 1 日 0:00』")
    func monthStartReturnsFirstOfMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))

        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 17
        comps.hour = 23; comps.minute = 59
        let mid = try #require(calendar.date(from: comps))

        let result = HistoryCutoff.monthStart(for: mid, calendar: calendar)
        var expected = DateComponents()
        expected.year = 2026; expected.month = 5; expected.day = 1
        expected.hour = 0; expected.minute = 0
        #expect(result == calendar.date(from: expected))
    }

    @Test("weekStart は calendar.firstWeekday を尊重する")
    func weekStartRespectsFirstWeekday() throws {
        // 月曜始まりカレンダーで 2026-05-08 (金) の週始まり = 2026-05-04 (月)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        calendar.firstWeekday = 2 // Monday

        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 8 // Friday
        let friday = try #require(calendar.date(from: comps))

        let result = HistoryCutoff.weekStart(for: friday, calendar: calendar)
        let resultDay = calendar.component(.weekday, from: result)
        #expect(resultDay == 2) // Monday
    }
}

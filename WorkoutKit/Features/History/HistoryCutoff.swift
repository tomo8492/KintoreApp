// MARK: - HistoryCutoff
// CLAUDE.md §1.1 F-04 / §-1.4 / §-1.14 準拠。
//
// 履歴の「直近 N 日」窓 (Free / Pro 境界) と、Charts の週・月境界を
// すべて同じ Calendar / TimeZone で計算するための単一窓口。
//
// 設計上の決め事:
// - 内部で使う Calendar は **`Calendar.autoupdatingCurrent`** に固定する。
//   `Calendar.current` は呼び出し時点のスナップショットなので、海外移動などで
//   ユーザーの TimeZone が変わってもアプリのプロセスが生きていると古い値が
//   返り、`startOfDay` が実機ロケールから±1日ズレることがある (DEBUG_REPORT
//   Critical-3)。`autoupdatingCurrent` は TimeZone / Locale 変更に追従する。
// - 比較対象の `WorkoutSession.startedAt` は内部単位 UTC `Date` (§-1.4)。
//   `startOfDay` は Calendar の TimeZone 基準で算出されるため、ユーザーの
//   現在ロケールでの「日付境界」と整合する。
// - 単体テストでは calendar を注入できるよう、すべての public API は
//   引数で Calendar / TimeZone を受け取れるようにしてある。

import Foundation

enum HistoryCutoff {
    /// 無料プランで参照できる履歴の窓 (直近 N 日)。CLAUDE.md §-1.14 で 30 日固定。
    static let freeWindowDays: Int = 30

    /// アプリ全体で使う Calendar。TimeZone / Locale 変更に追従させるため
    /// `autoupdatingCurrent` を採用 (§-1.4)。
    static var defaultCalendar: Calendar { .autoupdatingCurrent }

    /// 「いま」から `freeWindowDays` 前 0:00 (ユーザーロケール)。
    /// 境界はその日全体を含めるため日初に揃える。
    /// `Calendar.date(byAdding:)` が失敗するケースは現実的に存在しないが、
    /// 失敗時は `.distantPast` を返して「無料窓に入らない」=実質全件 Pro 扱いにする。
    static func freeWindowStart(now: Date = .now, calendar: Calendar = defaultCalendar) -> Date {
        guard let shifted = calendar.date(byAdding: .day, value: -freeWindowDays, to: now) else {
            return .distantPast
        }
        return calendar.startOfDay(for: shifted)
    }

    /// 指定日が無料窓内か。31日以前は false。
    static func isWithinFreeWindow(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = defaultCalendar
    ) -> Bool {
        date >= freeWindowStart(now: now, calendar: calendar)
    }

    // MARK: - Week / Month boundaries

    /// 指定日が含まれる週の始まり (Calendar.firstWeekday 基準)。
    /// Charts の週次集計と Calendar mode の週送りで共有する。
    static func weekStart(for date: Date, calendar: Calendar = defaultCalendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// 指定日が含まれる月の 1 日 0:00。
    static func monthStart(for date: Date, calendar: Calendar = defaultCalendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }
}

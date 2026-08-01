// MARK: - WorkoutWidgetProvider
// CLAUDE.md v1.0 §-1.19 / §3-4 / §5-4 準拠。
//
// TimelineProvider 実装。1 時間ごとにエントリを更新する(リアルタイム性不要)。
//
// データ取得:
//   - App Group 共有 UserDefaults(group.com.tomo.workoutkit)から
//     iPhone App が書き込んだ TodaySessionSummary JSON を読む。
//   - 値が無い / 昨日以前の値しか無い場合は WatchSummaryBridge が「今日 0 セット」を返す。
//
// なぜ SwiftData を直接読まないか:
//   - Domain/Models + Schema を Widget target に丸ごと持ち込むと依存が膨らみ、
//     Widget 起動コストが上がる(Smart Stack の数秒応答制約に影響)。
//   - サマリ値だけなら UserDefaults 1 件で十分(I/O 1 read)。

import Foundation
import WidgetKit

struct WorkoutWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> WorkoutWidgetEntry {
        WorkoutWidgetEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutWidgetEntry) -> Void) {
        completion(context.isPreview ? .sample : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // E4: 次の更新は「1 時間後」と「翌日 0 時」の早い方。1 時間固定だと、
        // 例えば 23:30 に見た「完了・N セット」が日付を跨いだ後も最大 1 時間
        // そのまま表示され続けてしまう(今日 0 セットになったはずなのに古い実績が
        // 残る)。日付が変わるタイミングでは早めに再評価させることでこれを防ぐ。
        let refresh = nextRefreshDate(after: entry.date)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    /// `date` を起点に「1 時間後」と「翌日の 0 時(ローカルタイム)」を比較し、
    /// 早い方を返す。`Calendar` の日付演算はどちらも失敗し得るため、失敗時は
    /// もう一方(最終的には `date` 自身)にフォールバックし、強制アンラップしない。
    private func nextRefreshDate(after date: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let oneHourLater = calendar.date(byAdding: .hour, value: 1, to: date) ?? date

        let startOfToday = calendar.startOfDay(for: date)
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return oneHourLater
        }

        return min(oneHourLater, nextMidnight)
    }

    // MARK: - Data fetch

    /// 今のエントリを構築する。App Group 共有 UserDefaults からサマリを読み、
    /// 今日でなければ「未実施」へフォールバックする(WatchSummaryBridge.read 内で処理済)。
    private func currentEntry() -> WorkoutWidgetEntry {
        let summary = WatchSummaryBridge.read()
        return WorkoutWidgetEntry(
            date: .now,
            isCompletedToday: summary.isCompletedToday,
            totalSetsToday: summary.totalSetsToday
        )
    }
}

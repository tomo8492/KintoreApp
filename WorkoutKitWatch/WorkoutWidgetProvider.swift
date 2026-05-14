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
        // 次の更新は 1 時間後。Smart Stack の更新コストはそれで十分。
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refresh)))
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

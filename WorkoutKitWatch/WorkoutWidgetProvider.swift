// MARK: - WorkoutWidgetProvider
// CLAUDE.md v0.5 §-1.19 準拠。
//
// TimelineProvider 実装。1 時間ごとにエントリを更新する(リアルタイム性不要)。
//
// データ取得:
//   - SwiftData を App Group 共有 URL で開き、本日完了の WorkoutSession 数 +
//     ExerciseSet 件数を数える。
//   - 失敗時は placeholder と同じ「未実施」表示にフォールバック。
//
// 注意:
//   - watchOS の Widget Extension は短命プロセスなので、ModelContainer 構築コストを
//     可能な限り抑える(`isStoredInMemoryOnly: false`、`url:` で共有ストアを指定)。
//   - 本実装は **スケルトン**: 共有 ModelContainer の構築は Phase 4 で実装し、
//     現状はカウントを 0 固定で返す(ビルド可能・配置可能な最小単位)。

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

    // MARK: - Data fetch (TODO: Phase 4 で SwiftData 共有ストア接続)

    /// 現時点では App Group 共有ストアの構築は未実装。Placeholder と同等の値を返す。
    /// Phase 4 で `SharedModelContainer.todaySummary()` 経由に切り替える。
    private func currentEntry() -> WorkoutWidgetEntry {
        WorkoutWidgetEntry(
            date: .now,
            isCompletedToday: false,
            totalSetsToday: 0
        )
    }
}

// MARK: - WorkoutWidgetEntry
// CLAUDE.md v0.5 §-1.19 準拠。
//
// Smart Stack ウィジェットの TimelineEntry。最小情報のみ:
//   - date: タイムライン上の有効時刻
//   - isCompletedToday: 今日完了したワークアウトがあるか
//   - totalSetsToday: 今日記録したセット数(分母無し)
//
// View 側は本 entry だけで描画完結する(SwiftData / Localizable へ
// 直接アクセスしない設計)。

import Foundation
import WidgetKit

struct WorkoutWidgetEntry: TimelineEntry {
    let date: Date
    let isCompletedToday: Bool
    let totalSetsToday: Int

    static let placeholder = WorkoutWidgetEntry(
        date: .now,
        isCompletedToday: false,
        totalSetsToday: 0
    )

    static let sample = WorkoutWidgetEntry(
        date: .now,
        isCompletedToday: true,
        totalSetsToday: 12
    )
}

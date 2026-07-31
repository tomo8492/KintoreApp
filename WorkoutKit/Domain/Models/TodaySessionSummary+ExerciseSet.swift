// MARK: - TodaySessionSummary + ExerciseSet
// Audit A2 準拠。
//
// `TodaySessionSummary` の集計ロジック(セット数 / 種目数のカウント)を、
// SessionStore+Actions.writeWatchSummary と WatchQuickLogIngestor(WorkoutKitApp.swift)
// の 2 箇所で重複させないための共有ヘルパー。
//
// `ExerciseSet`(SwiftData @Model)に依存するため、あえて `WorkoutKit/Shared/` ではなく
// Domain/Models 配下に置く。`WorkoutKit/Shared/` は watchOS 側 target にも個別 path 追加
// される cross-platform 契約置き場のため、Domain 依存を持ち込まないための区分け。

import Foundation

extension TodaySessionSummary {
    /// `sets` から Watch Widget 用サマリを組み立てる。
    /// - Parameters:
    ///   - sets: 集計対象の ExerciseSet 群。種目の重複カウントは `exercise.slug` で判定する。
    ///   - isCompletedToday: 「完了」扱いにするかどうか(呼び出し元の文脈依存)。
    ///   - updatedAt: サマリの更新時刻。既定は呼び出し時点。
    static func build(
        from sets: [ExerciseSet],
        isCompletedToday: Bool,
        updatedAt: Date = .now
    ) -> TodaySessionSummary {
        let exerciseCount = Set(sets.compactMap { $0.exercise?.slug }).count
        return TodaySessionSummary(
            updatedAt: updatedAt,
            isCompletedToday: isCompletedToday,
            totalSetsToday: sets.count,
            exerciseCountToday: exerciseCount
        )
    }
}

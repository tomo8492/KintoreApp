// MARK: - TodaySessionSummary
// CLAUDE.md v1.0 §-1.19 / §3-4 準拠。
//
// 「今日のワークアウト状況」を iPhone App から watchOS Widget へ受け渡すための
// 軽量 Codable 値型。
//
// 設計判断:
//   - watchOS Widget Extension が SwiftData @Model 群を直接読むには、Domain/Models
//     と Domain/Schema を Widget target にも全部 path-include する必要がある。
//     依存範囲が大きく(Exercise・Template・ExerciseSet・SchemaV1 + Enums 全部)、
//     Widget の起動コストが膨らむため、間に薄い「サマリだけ」の中間表現を挟む。
//   - App Group(`group.com.tomo.workoutkit`)の共有 UserDefaults に JSON 文字列で
//     保存し、Widget Provider はそれを読むだけ。
//   - 書き込みは SessionStore.finish / abort の直後に WatchSummaryBridge.write 経由。
//
// 互換性:
//   - 将来フィールドを増やす場合は Optional 追加で対応(本構造体は forward/backward
//     compatible にしたい)。

import Foundation

public struct TodaySessionSummary: Codable, Hashable, Sendable {
    /// 当該日(ローカルタイム基準で「今日」)の最終更新時刻。
    /// 日付の比較は Widget 側で `Calendar.isDateInToday(_:)` を使う。
    public var updatedAt: Date

    /// 今日完了したワークアウトがあるか(finish 済みセッションが 1 件以上)。
    public var isCompletedToday: Bool

    /// 今日の総セット数(完了 + 中断含む、order 連番ではなく実件数)。
    public var totalSetsToday: Int

    /// 今日実施した種目数(重複なし)。
    public var exerciseCountToday: Int

    public init(
        updatedAt: Date,
        isCompletedToday: Bool,
        totalSetsToday: Int,
        exerciseCountToday: Int
    ) {
        self.updatedAt = updatedAt
        self.isCompletedToday = isCompletedToday
        self.totalSetsToday = totalSetsToday
        self.exerciseCountToday = exerciseCountToday
    }

    /// Widget 側で値が無いとき / 取り出しに失敗したときに使うデフォルト。
    public static let empty = TodaySessionSummary(
        updatedAt: .distantPast,
        isCompletedToday: false,
        totalSetsToday: 0,
        exerciseCountToday: 0
    )
}

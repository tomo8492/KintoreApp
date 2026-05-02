// MARK: - SessionLiveActivityAttributes
// CLAUDE.md §1.1 F-03 / §-1.5 / §11 準拠。
//
// ActivityKit の ActivityAttributes 定義。
// 本ファイルはアプリ本体(WorkoutKit)と Widget Extension(WorkoutKitLiveActivity)の
// 双方からビルドされる。project.yml で WorkoutKit ターゲットの sources に
// 個別パスとして追加することで重複コンパイルを許容している。
//
// 設計メモ:
// - 残時間を Int で持って毎秒 update() するとバッテリー/サーバ予算を食うため、
//   `intervalEndsAt: Date?` を持たせて Widget 側は `Text(timerInterval:)` で
//   ローカルレンダリングする。これで休憩中は秒単位 push が不要。
// - 種目名は表示用に解決済み文字列を ContentState に詰める。Widget 側は
//   SwiftData にアクセスせず、状態だけで描画完結する(App Group 参照を最小化)。

import ActivityKit
import Foundation

/// セッション全体の不変属性。
struct SessionLiveActivityAttributes: ActivityAttributes {
    typealias ContentState = SessionLiveActivityState

    /// 紐づく WorkoutSession の id(将来 Deep Link 用)。
    let sessionId: UUID
    /// `Goal.rawValue`(`hypertrophy` / `strength` / `endurance` / `cardio`)。
    /// Widget 側で enum 依存を持たせないため raw 文字列で渡す。
    let goalRaw: String
}

/// セッション進行に応じて毎セット更新される動的状態。
///
/// - Codable / Hashable: ActivityKit が ContentState に要求するプロトコル要件。
struct SessionLiveActivityState: Codable, Hashable {

    /// 現在実施中の種目 slug(空文字なら表示対象なし)。
    var currentExerciseSlug: String

    /// 現在実施中の種目の表示名(日本語、解決済み)。
    /// Widget 側で多言語切替するならアプリ側でロケール解決して入れる。
    var currentExerciseDisplayName: String

    /// 完了セット数(進捗バッジの分子)。
    var progress: Int

    /// 計画上のセット総数(進捗バッジの分母)。
    var total: Int

    /// 休憩タイマーの終了時刻(休憩中でなければ nil)。
    /// `Text(timerInterval: .now...endsAt, countsDown: true)` でローカル描画する。
    var intervalEndsAt: Date?
}

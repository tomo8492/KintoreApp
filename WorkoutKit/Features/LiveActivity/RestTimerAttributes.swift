// MARK: - RestTimerAttributes
// CLAUDE.md v0.5 §-1.18 準拠。
//
// セット間レストタイマー用 ActivityKit ActivityAttributes。
// 既存 SessionLiveActivityAttributes(セッション全体の進捗)とは別の Activity として
// 同一 Widget Extension に併存させる(1 セッション中に最大 2 Activity が並走)。
//
// 設計メモ:
//   - 残時間を Int 秒で持って毎秒 activity.update を打つとバッテリーが死ぬので、
//     `endTime: Date` だけ保持して Widget 側で Text(timerInterval:countsDown:) を
//     使ってローカル描画する(iOS 18 の更新頻度制限 5〜15 秒問題の回避策)。
//   - 終了は RestTimerManager.stop() か、UIRefresh で endTime <= now が確認された時。
//
// 本ファイルは App 本体と Widget Extension の両方から参照されるため、
// project.yml の WorkoutKit / WorkoutKitLiveActivity 両方の sources に登録する。

import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {

    typealias ContentState = RestTimerState

    /// 紐づくワークアウト名(セッション開始時に確定、変わらない)。
    /// Builder 由来の場合は Goal の Localized 名、Template 由来ならテンプレート名。
    let workoutName: String

    /// セッション ID(WorkoutSession.id)。Deep Link / debug 用に保持。
    let sessionId: UUID
}

/// 動的状態。毎秒 update せず、endTime だけ持って端末側でカウントダウン描画する。
struct RestTimerState: Codable, Hashable, Sendable {

    /// このタイマーが終わる時刻(Date)。Widget 側の `Text(timerInterval:countsDown:)`
    /// にそのまま渡す。`now > endTime` で完了。
    let endTime: Date

    /// 現在カウント中の種目名(日本語表示済み、Widget 側でロケール解決しない)。
    let exerciseName: String

    /// 次のセット番号(1-indexed)。Widget の "Next set 3" 表示用。
    let nextSetNumber: Int

    /// 計画上の総セット数(現在実施中の種目)。"3 / 5" のような分母表示用。
    /// 0 のときは分母を非表示にする。
    let totalSetsForExercise: Int
}

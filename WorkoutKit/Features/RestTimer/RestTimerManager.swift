// MARK: - RestTimerManager
// CLAUDE.md v0.5 §-1.18 / §11.4 準拠。
//
// セット完了時にレストタイマー用 Live Activity を起動・終了する。
// 既存の SessionStore IntervalTimer はフォアグラウンドのカウントダウン UI 用で、
// 本 Manager は **バックグラウンド / ロック画面 / Dynamic Island** 用の差し込み口。
//
// 設計:
//   - @MainActor。Singleton 禁止のため AppDependency 経由で SessionStore に DI。
//   - 起動済み Activity は最大 1 個。多重起動防止のため start 前に endIfRunning する。
//   - 失敗(権限なし / OS エラー)時は Logger に書いて静かに無効化。
//     SessionStore の通常進行は止めない。
//   - LiveActivityClient(session-progress 用)と同一 Bundle で併存するため、
//     2 個目の ActivityConfiguration として Widget Bundle 側で宣言する。

import ActivityKit
import Foundation
import OSLog

@MainActor
final class RestTimerManager {

    // MARK: - State

    private var activity: Activity<RestTimerAttributes>?

    // MARK: - Init

    /// AppDependency.defaultValue から呼べるよう nonisolated init。
    /// 状態に触れないので MainActor 隔離なしで安全。
    nonisolated init() {}

    // MARK: - Capability

    /// Live Activity が OS / 集中モードで許可されているか。
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Lifecycle

    /// セット完了直後に呼ぶ。`seconds` 秒のレストを Live Activity で表示する。
    func start(
        seconds: Int,
        workoutName: String,
        exerciseName: String,
        sessionId: UUID,
        nextSetNumber: Int,
        totalSetsForExercise: Int
    ) {
        guard isAvailable else {
            Logger.session.info("RestTimer: Live Activities disabled, skipping")
            return
        }
        guard seconds > 0 else { return }

        // 既存の rest activity が居れば畳んでから新規起動する。
        if activity != nil {
            Task { await endInternal(reason: "restart") }
        }

        let endTime = Date().addingTimeInterval(TimeInterval(seconds))
        let attrs = RestTimerAttributes(workoutName: workoutName, sessionId: sessionId)
        let state = RestTimerState(
            endTime: endTime,
            exerciseName: exerciseName,
            nextSetNumber: nextSetNumber,
            totalSetsForExercise: totalSetsForExercise
        )

        do {
            let content = ActivityContent(state: state, staleDate: endTime.addingTimeInterval(30))
            activity = try Activity<RestTimerAttributes>.request(
                attributes: attrs,
                content: content,
                pushType: nil
            )
            Logger.session.info("RestTimer started: id=\(self.activity?.id ?? "?", privacy: .public), seconds=\(seconds, privacy: .public)")
        } catch {
            Logger.session.error("RestTimer Activity.request failed: \(error.localizedDescription, privacy: .public)")
            activity = nil
        }
    }

    /// レスト完了 / 手動キャンセル時に呼ぶ。
    func stop() async {
        await endInternal(reason: "stop")
    }

    private func endInternal(reason: String) async {
        guard let activity else { return }
        await activity.end(activity.content, dismissalPolicy: .immediate)
        Logger.session.info("RestTimer ended: id=\(activity.id, privacy: .public) reason=\(reason, privacy: .public)")
        self.activity = nil
    }

    /// 既存 Activity の残時間だけ更新したい場合(例: ユーザーが手動で +30 秒)。
    /// endTime を伸ばす場合は新しい state を渡して update する。
    func extend(by seconds: Int) async {
        guard let activity else { return }
        guard seconds != 0 else { return }
        let current = activity.content.state
        let newEnd = current.endTime.addingTimeInterval(TimeInterval(seconds))
        let newState = RestTimerState(
            endTime: newEnd,
            exerciseName: current.exerciseName,
            nextSetNumber: current.nextSetNumber,
            totalSetsForExercise: current.totalSetsForExercise
        )
        let content = ActivityContent(state: newState, staleDate: newEnd.addingTimeInterval(30))
        await activity.update(content)
    }
}

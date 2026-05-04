// MARK: - LiveActivityClient
// CLAUDE.md §1.1 F-03 / §-1.5 / §-1.6 / §11.4 準拠。
//
// ActivityKit の Activity<SessionLiveActivityAttributes> ラッパー。
// - Singleton(.shared) 禁止のため、AppDependency 経由で SessionStore に DI する。
// - print 禁止 → Logger.session を使う。
// - 例外は throws ではなく Logger に吐いて静かに無効化する(Live Activity 失敗で
//   セッションを止めるべきではないため)。
// - Activity.request は同期 throws なので start() は同期 API。
//   update / end は内部で `pendingTask` チェーンに直列化して予約する。
//   呼び出し側(SessionStore)は同期で発火し、完了を待たない。
//   - 直列化することで「セット完了 → 休憩開始」の連続更新で前の update が
//     キャンセルされ最新状態が反映されない事象 (DEBUG_REPORT Critical-2) を防ぐ。
//   - `nonisolated(unsafe)` を `activity` に付けるのは、ActivityKit の `Activity`
//     型自体が Sendable に適合していないため Swift 6 strict concurrency が
//     "sending 'activity' risks data races" を出すため。本クラスは @MainActor
//     なので実際には常に MainActor 上で読み書きされ、レースは発生しない。
//
// 通信経路:
//   App (LiveActivityClient.update)
//     -> ActivityKit IPC
//       -> WorkoutKitLiveActivity Widget (ActivityConfiguration content closure)
//
// 休憩タイマーの残秒数は ContentState.intervalEndsAt(Date)で表現し、Widget 側で
// `Text(timerInterval:)` を使ってローカル描画する。秒単位 update を打たない設計。

import ActivityKit
import Foundation
import OSLog

@MainActor
final class LiveActivityClient {

    // MARK: - State

    /// `Activity` 自体は Sendable ではないが、本クラスが @MainActor 上に閉じ込めている
    /// ため実質的にレースは起こらない。strict concurrency 警告を黙らせるために
    /// `nonisolated(unsafe)` を明示する。
    nonisolated(unsafe) private var activity: Activity<SessionLiveActivityAttributes>?

    /// 直前の update / end の完了を待つチェーン。並行起動した async 操作を直列化する。
    /// nil の場合は実行中の予約なし。
    private var pendingTask: Task<Void, Never>?

    // MARK: - Init

    /// SwiftUI Environment.defaultValue から呼べるよう nonisolated。
    nonisolated init() {}

    // MARK: - Capability

    /// Live Activity が OS 設定で許可されているか。
    /// 端末 / 集中モードによって false になり得る。
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Lifecycle

    /// セッション開始時に Live Activity を起動する。
    /// - 既存の Activity が残っていればローカルにキャプチャしてから `self.activity` を nil にし、
    ///   キャプチャ済みのインスタンスをバックグラウンド Task で end する。
    ///   `self.activity` を直接 await した先で参照するパターンだと、新規 request が先に
    ///   走った場合に await が「新 Activity の終了」を待ってしまい永久ブロックになる。
    /// - 失敗(権限なし、内部エラー等)時は静かにログだけ残し、SessionStore は通常通り続行する。
    func start(
        attributes: SessionLiveActivityAttributes,
        state: SessionLiveActivityState
    ) {
        guard isAvailable else {
            Logger.session.info("LiveActivity disabled by system; skipping start")
            return
        }

        // 既存 Activity が残っていれば、新規 request の前にチェーンへ end を予約する。
        // Task で投げて忘れる ── ではなく pendingTask に乗せて直列化する。
        if activity != nil {
            scheduleEnd(reason: "restart")
        }

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            Logger.session.info("LiveActivity started: id=\(self.activity?.id ?? "nil", privacy: .public)")
        } catch {
            Logger.session.error("Activity.request failed: \(error.localizedDescription, privacy: .public)")
            activity = nil
        }
    }

    /// セット完了時 / 休憩開始時に呼ぶ同期 API。
    /// 内部 chain に予約するだけで完了を待たない。連続呼び出し時は前の予約完了後に走る。
    /// 起動済み Activity が無い(start に失敗していた等)場合も chain 内部で no-op。
    func update(state: SessionLiveActivityState) {
        let content = ActivityContent(state: state, staleDate: nil)
        let prior = pendingTask
        pendingTask = Task { @MainActor [weak self] in
            await prior?.value
            guard let self else { return }
            await self.activity?.update(content)
        }
    }

    /// セッション終了 / 中断時に呼ぶ同期 API。chain に予約して即座に戻る。
    func end() {
        scheduleEnd(reason: "end")
    }

    // MARK: - Test / shutdown helper

    /// 予約済みの update / end をすべて待つ。Tests と App 終了時に使う。
    func waitForPendingOperations() async {
        await pendingTask?.value
    }

    // MARK: - Internal

    private func scheduleEnd(reason: String) {
        let prior = pendingTask
        pendingTask = Task { @MainActor [weak self] in
            await prior?.value
            guard let self, let activity = self.activity else { return }
            self.activity = nil
            await activity.end(activity.content, dismissalPolicy: .immediate)
            Logger.session.info("LiveActivity ended: id=\(activity.id, privacy: .public) reason=\(reason, privacy: .public)")
        }
    }
}

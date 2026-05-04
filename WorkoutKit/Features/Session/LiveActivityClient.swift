// MARK: - LiveActivityClient
// CLAUDE.md §1.1 F-03 / §-1.5 / §-1.6 / §11.4 準拠。
//
// ActivityKit の Activity<SessionLiveActivityAttributes> ラッパー。
// - Singleton(.shared) 禁止のため、AppDependency 経由で SessionStore に DI する。
// - print 禁止 → Logger.session を使う。
// - 例外は throws ではなく Logger に吐いて静かに無効化する(Live Activity 失敗で
//   セッションを止めるべきではないため)。
// - Activity.request は同期 throws なので start() は同期 API、update / end は async。
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

    private var activity: Activity<SessionLiveActivityAttributes>?

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

        if let previous = activity {
            // 旧 Activity を確定的にキャプチャして即時 self.activity をクリア。
            // 新 request が成功すると self.activity は新 Activity を保持するため、
            // バックグラウンド Task は previous(旧)だけを安全に終わらせられる。
            activity = nil
            Task {
                await previous.end(previous.content, dismissalPolicy: .immediate)
                Logger.session.info("LiveActivity ended (restart): id=\(previous.id, privacy: .public)")
            }
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

    /// セット完了時 / 休憩開始時に呼ぶ。
    /// 起動済み Activity が無い(start に失敗していた等)場合は no-op。
    func update(state: SessionLiveActivityState) async {
        guard let activity else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
    }

    /// セッション終了 / 中断時に呼ぶ。即時に Activity を消す。
    func end() async {
        await endInternal(reason: "end")
    }

    // MARK: - Internal

    private func endInternal(reason: String) async {
        guard let activity else { return }
        await activity.end(activity.content, dismissalPolicy: .immediate)
        Logger.session.info("LiveActivity ended: id=\(activity.id, privacy: .public) reason=\(reason, privacy: .public)")
        self.activity = nil
    }
}

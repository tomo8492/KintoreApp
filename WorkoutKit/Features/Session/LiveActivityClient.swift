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

// `Activity<X>` は ActivityKit が非 Sendable のままにしているため、
// `@MainActor` Task から `await activity.update/end` するとき receiver の sending
// 警告が出る。Apple SDK が Sendable 注釈を追加するまでの過渡期対応として、
// 本ファイル限定で `@preconcurrency import` で抑制する(本クラスは @MainActor で
// 閉じているので実用上のレースは無い ─ ファイル先頭の設計メモ参照)。
@preconcurrency import ActivityKit
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
    /// - B5-1: 既存の Activity が残っていれば **この関数の中で同期的に**
    ///   `self.activity` をローカル変数 `stale` へキャプチャしてから `self.activity`
    ///   を nil にし、`stale` だけを `scheduleEnd(of:reason:)` に値として渡して
    ///   終了予約する。以前の実装は `scheduleEnd()` の Task 本体の中で
    ///   `self.activity` を読み直していたため、`Task { }` はクロージャ生成時点では
    ///   実行されず呼び出し元の同期コードが完了してから走る性質上、この
    ///   `start()` が(restart の end 予約直後に)新しい Activity を request して
    ///   `self.activity` を書き換えると、Task 実行時にはそちらを end してしまう
    ///   バグがあった(restart したはずが新規セッションの Activity を即終了して
    ///   しまう)。値渡しにすることで、Task が実際に走る時点の `self.activity` の
    ///   状態に関わらず「本当に end すべきだったもの」だけを終了できる。
    /// - 失敗(権限なし、内部エラー等)時は静かにログだけ残し、SessionStore は通常通り続行する。
    func start(
        attributes: SessionLiveActivityAttributes,
        state: SessionLiveActivityState
    ) {
        guard isAvailable else {
            Logger.session.info("LiveActivity disabled by system; skipping start")
            return
        }

        // B5-2: プロセス再起動をまたいだ孤児 Activity を掃除する。前回プロセスが
        // force-quit された場合など、`self.activity` が nil でも OS 側には Live
        // Activity が残っていることがある(生き残れるのは force-quit サバイバー
        // だけなので、現在追跡中のもの以外は無条件に古いとみなしてよい)。
        let trackedId = activity?.id
        for orphan in Activity<SessionLiveActivityAttributes>.activities where orphan.id != trackedId {
            scheduleEnd(of: orphan, reason: "orphan")
        }

        // 既存 Activity が残っていれば、新規 request の前に同期的にローカル退避して
        // `self.activity` を nil 化する(上のドキュメントコメント参照)。
        if let stale = activity {
            self.activity = nil
            scheduleEnd(of: stale, reason: "restart")
        }

        do {
            // B5-3: staleDate を無制限(nil)にせず 4 時間の上限を持たせる。
            // 通常は明示的な update() / end() で常に新鮮な状態・終了に保たれるが、
            // 万一それらが呼ばれず終わった場合の孤児化バックストップとして機能する。
            let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(4 * 3600))
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
        // B5-1 と同じ理由で、同期的にローカル退避してから値渡しする。
        guard let stale = activity else { return }
        activity = nil
        scheduleEnd(of: stale, reason: "end")
    }

    // MARK: - Test / shutdown helper

    /// 予約済みの update / end をすべて待つ。Tests と App 終了時に使う。
    func waitForPendingOperations() async {
        await pendingTask?.value
    }

    // MARK: - Internal

    /// B5-1: `self.activity` を読み直さず、呼び出し元が同期的に退避した
    /// `staleActivity` だけを終了する。呼び出し元は必ず `self.activity = nil` を
    /// 済ませてから渡すこと(このメソッド自体は `self.activity` に触れない)。
    private func scheduleEnd(of staleActivity: Activity<SessionLiveActivityAttributes>, reason: String) {
        let prior = pendingTask
        pendingTask = Task { @MainActor in
            await prior?.value
            let id = staleActivity.id
            let content = staleActivity.content
            await staleActivity.end(content, dismissalPolicy: .immediate)
            Logger.session.info("LiveActivity ended: id=\(id, privacy: .public) reason=\(reason, privacy: .public)")
        }
    }
}

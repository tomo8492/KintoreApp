// MARK: - RestTimerManager
// CLAUDE.md v1.0 §5-3 準拠。
//
// セット完了時にレストタイマー用 Live Activity を起動・終了する。
// 既存の SessionStore IntervalTimer はフォアグラウンドのカウントダウン UI 用で、
// 本 Manager は **バックグラウンド / ロック画面 / Dynamic Island** 用の差し込み口。
//
// 設計(v1.0 §5-3 / §4-3 状態管理パターン準拠):
//   - @Observable @MainActor + `static let shared` パターン。
//     View からは `.environment(RestTimerManager.shared)` で注入する。
//   - 起動済み Activity は最大 1 個。多重起動防止のため start 前に endIfRunning する。
//   - 失敗(権限なし / OS エラー)時は Logger に書いて静かに無効化。
//     SessionStore の通常進行は止めない。
//   - LiveActivityClient(session-progress 用)と同一 Bundle で併存するため、
//     2 個目の ActivityConfiguration として Widget Bundle 側で宣言する。

// `Activity<X>` は ActivityKit が非 Sendable のままにしているため、
// `@MainActor` から `await activity.update/end` するとき receiver の sending 警告が
// 出る。Apple SDK が Sendable 注釈を追加するまでの過渡期対応として、本ファイル
// 限定で `@preconcurrency import` で抑制する(ActivityKit 自体は実用上 MainActor で
// 使う前提なので、現状の利用パターンに競合は無い)。
@preconcurrency import ActivityKit
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class RestTimerManager {

    // MARK: - Singleton (v1.0 §5-3)

    /// `.environment(RestTimerManager.shared)` で View 階層に注入する。
    /// PurchaseManager と同様、`@MainActor` class は Sendable 適合するので
    /// `nonisolated` のみで lazy init を nonisolated context からも安全に通せる。
    nonisolated static let shared = RestTimerManager()

    // MARK: - Observable state

    /// 現在 Live Activity が稼働中か。View からは表示判定に使う。
    var isRunning: Bool { activity != nil }

    // MARK: - Internal state

    private var activity: Activity<RestTimerAttributes>?

    /// B3-1: endTime を過ぎても Live Activity が残り続けないための自動終了タスク。
    /// start() で都度キャンセルして新しい endTime に合わせて張り直す。
    /// stop() / endInternal でもキャンセルする(手動終了と競合させないため)。
    private var expiryTask: Task<Void, Never>?

    // MARK: - Init

    /// `static let shared` の lazy init を MainActor 外から通すため nonisolated。
    /// Observable state には触らないので競合なし。
    /// 既存の DI 経由(AppDependency.defaultValue)もそのまま動く。
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

        // B3-2: プロセス再起動をまたいだ孤児 Activity を掃除する。前回プロセスが
        // force-quit された場合など、`activity` が nil でも OS 側には Live Activity が
        // 残っていることがある(生き残れるのは force-quit サバイバーだけなので、
        // 現在追跡中のもの以外は無条件に古いとみなしてよい)。
        let trackedId = activity?.id
        for orphan in Activity<RestTimerAttributes>.activities where orphan.id != trackedId {
            Task { @MainActor in
                await orphan.end(orphan.content, dismissalPolicy: .immediate)
                Logger.session.info("RestTimer ended orphan: id=\(orphan.id, privacy: .public)")
            }
        }

        // 新規起動するので、直前の自動終了タスクはいったん無効化する
        // (新しい endTime に合わせて末尾で張り直す)。
        expiryTask?.cancel()
        expiryTask = nil

        // 既存の rest activity が居れば畳んでから新規起動する。
        // 重要: fire-and-forget で endInternal(self) を回すと、後段で代入される
        // 新しい self.activity を Task 完了時に誤って end してしまう race があるため、
        // 古い参照をローカルに退避してから self.activity = nil。Task は
        // ローカル参照に対してのみ作用させる(self.activity に触らない)。
        if let oldActivity = activity {
            self.activity = nil
            Task { @MainActor in
                await oldActivity.end(oldActivity.content, dismissalPolicy: .immediate)
                Logger.session.info("RestTimer ended: id=\(oldActivity.id, privacy: .public) reason=restart")
            }
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
            // B3-1: endTime + 5秒後にまだ同じ Activity が生きていれば自動終了する保険。
            scheduleExpiry(for: activity, endTime: endTime)
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
        guard let activity = self.activity else { return }
        // B3-1: 自動終了タスクもここで畳む。手動 stop / 期限切れどちらの経路でも
        // end() が二重に走らないようにする。
        expiryTask?.cancel()
        expiryTask = nil
        // `await activity.end(...)` の前に id / content をローカルへ取り出し、
        // self.activity を nil 化して aliasing を解消する。`activity` を後段では使わない。
        let id = activity.id
        let content = activity.content
        self.activity = nil
        await activity.end(content, dismissalPolicy: .immediate)
        Logger.session.info("RestTimer ended: id=\(id, privacy: .public) reason=\(reason, privacy: .public)")
    }

    /// B3-1: endTime を過ぎても Live Activity が残り続けないための保険タスクを張る。
    /// `endTime + 5秒` まで待ち、その時点でもまだ `trackedActivity` と同じ Activity を
    /// 追跡していれば endInternal で終了する。途中で start() / stop() により
    /// 追跡対象が入れ替わっていれば(id が一致しなければ)何もしない。
    private func scheduleExpiry(for trackedActivity: Activity<RestTimerAttributes>?, endTime: Date) {
        guard let trackedActivity else { return }
        let expiryId = trackedActivity.id
        let delay = max(0, endTime.timeIntervalSinceNow) + 5
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard let self, self.activity?.id == expiryId else { return }
            await self.endInternal(reason: "expiry")
        }
    }

    /// 既存 Activity の残時間だけ更新したい場合(例: ユーザーが手動で +30 秒)。
    /// endTime を伸ばす場合は新しい state を渡して update する。
    func extend(by seconds: Int) async {
        guard let activity = self.activity else { return }
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
        // B3-3: 延長した分だけ自動終了タスクも新しい endTime に合わせて張り直す。
        scheduleExpiry(for: activity, endTime: newEnd)
    }
}

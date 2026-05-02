// MARK: - SessionStore + LiveActivity
// CLAUDE.md §1.1 F-03 / §-1.5 / §11.4 準拠。
//
// SessionStore から LiveActivityClient を呼び出すヘルパー。
// 1ファイル 300 行制約のため別ファイルに切り出す。
// SessionStore.liveActivity は本拡張からのみ参照(SessionStore 本体側は protected な
// 呼び出しヘルパー(startLiveActivityIfPossible / updateLiveActivity / endLiveActivity)
// だけを持つ)。

import Foundation

extension SessionStore {

    // MARK: - 呼び出しヘルパー(SessionStore 本体から呼ばれる)

    /// Init 完了直後に1回だけ呼ぶ。Live Activity が利用不可なら no-op。
    func startLiveActivityIfPossible() {
        guard let liveActivity else { return }
        let attributes = SessionLiveActivityAttributes(
            sessionId: sessionId,
            goalRaw: goal.rawValue
        )
        liveActivity.start(attributes: attributes, state: liveActivityState())
    }

    /// セット完了 / 種目進行 / 休憩開始時に呼ぶ。
    /// Activity.update は async だが、SessionStore 本体は同期 API なので Task で投げる。
    func updateLiveActivity() {
        guard let liveActivity else { return }
        let state = liveActivityState()
        Task { await liveActivity.update(state: state) }
    }

    /// セッション終了 / 中断時に呼ぶ。
    func endLiveActivity() {
        guard let liveActivity else { return }
        Task { await liveActivity.end() }
    }

    // MARK: - State 計算

    /// 現在の SessionStore 状態から Live Activity 用 ContentState を組み立てる。
    /// Widget 側は SwiftData にアクセスせず、本値だけで描画完結する設計。
    private func liveActivityState() -> SessionLiveActivityState {
        let total = plan.reduce(0) { $0 + $1.plannedSetCount }
        let progress = completedSets.count

        let displayName: String
        let slug: String
        if let item = currentItem {
            slug = item.slug
            // resolvedExercises に居れば日本語名を、無ければ slug をそのまま見せる。
            displayName = resolvedExercises[item.slug]?.nameJa ?? item.slug
        } else {
            slug = ""
            displayName = ""
        }

        let endsAt: Date?
        if let remaining = intervalSecondsRemaining, remaining > 0 {
            endsAt = Date().addingTimeInterval(TimeInterval(remaining))
        } else {
            endsAt = nil
        }

        return SessionLiveActivityState(
            currentExerciseSlug: slug,
            currentExerciseDisplayName: displayName,
            progress: progress,
            total: total,
            intervalEndsAt: endsAt
        )
    }
}

// MARK: - SessionStore + Actions
// CLAUDE.md §1.1 F-03 準拠。
// SessionStore からセット完了・スキップ・差替・abort/finish と
// カーソル前進ロジックを切り出す(主ファイル 300 行制約のため)。

import Foundation
import OSLog

extension SessionStore {

    // MARK: - Actions: 完了

    /// 現在セットを完了として確定し、次のカーソルに進める。
    /// reps=0 / weight=0 でも記録は通す(時間ベース種目や bodyweight 用)。
    func completeCurrentSet() {
        guard status == .running, let item = currentItem else { return }

        let exercise = resolvedExercises[item.slug]
        let order = completedSets.count
        let restSeconds = max(0, inputRestSeconds)
        let set = ExerciseSet(
            order: order,
            sectionRaw: item.section.rawValue,
            reps: max(0, inputReps),
            weightKg: max(0, inputWeightKg),
            rpe: inputRpe,
            restSeconds: restSeconds,
            completedAt: .now,
            exercise: exercise
        )
        if let session = fetchSession() {
            set.session = session
            modelContext.insert(set)
            persist()
            completedSets.append(set)
            onSetCompleted?(set)
        } else {
            Logger.session.error("completeCurrentSet: session not found id=\(self.sessionId, privacy: .public)")
        }

        advanceCursor()

        // セッション終了後はカウントダウンを起動しない(直前 advanceCursor で finish 済の場合)。
        if status == .running, restSeconds > 0 {
            startIntervalCountdown(seconds: restSeconds)
            // v1.0 §5-3: ロック画面 / Dynamic Island 向けのレストタイマー Live Activity も起動。
            // バックグラウンドでも残時間が見えるよう、フォアグラウンドのカウントダウン
            // (IntervalTimer)とは別系統で並行起動する。
            startRestTimerLiveActivity(seconds: restSeconds)
        }

        // C3: セット完了 / 種目進行に合わせて Live Activity を更新する。
        // finish() で end が呼ばれる場合は重複しないよう running 中のみ。
        if status == .running {
            updateLiveActivity()
        }
    }

    // MARK: - Rest Timer Live Activity (v1.0 §5-3)

    /// `completeCurrentSet` から呼ばれる。レスト残時間を Dynamic Island / ロック画面に表示する。
    /// 失敗(OS が Live Activity を許可していない、Activity.request 例外等)時は
    /// RestTimerManager 内でログを残して静かに無効化する。
    private func startRestTimerLiveActivity(seconds: Int) {
        // advanceCursor 済みなので currentItem は「次のセットの種目」を指している。
        guard let item = currentItem else { return }
        let exerciseName = resolvedExercises[item.slug]?.localizedName ?? item.slug
        // currentSetIndex は 0-indexed なので +1 して 1-indexed の「次のセット番号」に。
        let nextSet = currentSetIndex + 1
        let totalForExercise = item.plannedSetCount
        // ワークアウト名は Goal の Localized 名で代用(Template 由来は v1.1+)。
        let workoutName = String(localized: "session.live.workout.default",
                                 defaultValue: "ワークアウト")

        RestTimerManager.shared.start(
            seconds: seconds,
            workoutName: workoutName,
            exerciseName: exerciseName,
            sessionId: sessionId,
            nextSetNumber: nextSet,
            totalSetsForExercise: totalForExercise
        )
    }

    /// abort / finish 時に呼ぶ。レストタイマー Live Activity を能動的に終了する。
    /// IntervalTimer 側の stopIntervalCountdown と一緒に呼ぶことで、
    /// ロック画面に古い表示が残らないようにする。
    func stopRestTimerLiveActivity() async {
        await RestTimerManager.shared.stop()
    }

    /// 現在種目をスキップして次種目の最初のセットへ。残りセットは記録しない。
    func skipCurrentExercise() {
        guard status == .running, currentItem != nil else { return }
        Logger.session.info("skipCurrentExercise at index=\(self.currentItemIndex)")
        stopIntervalCountdown()
        // B4: スキップ時もレストタイマー Live Activity をロック画面から消す。
        // abort() / finish() と同じ経路(RestTimerManager.stop())を使う。
        Task { await stopRestTimerLiveActivity() }
        currentSetIndex = 0
        if currentItemIndex < plan.count - 1 {
            currentItemIndex += 1
            updateLiveActivity()
        } else {
            finish()
        }
    }

    /// 現在種目を別の Exercise に差し替える(B3 Choose / D1 Library 由来の選択肢を受ける)。
    /// セット数は元のまま。slug 解決辞書は更新する。
    func replaceCurrentExercise(with newExercise: Exercise) {
        guard plan.indices.contains(currentItemIndex) else { return }
        let oldSection = plan[currentItemIndex].section
        let oldCount = plan[currentItemIndex].plannedSetCount
        plan[currentItemIndex] = SessionPlanItem(
            slug: newExercise.slug,
            section: oldSection,
            plannedSetCount: oldCount
        )
        replaceExercise(slug: newExercise.slug, with: newExercise)
        currentSetIndex = 0
        Logger.session.info("replaceCurrentExercise: -> \(newExercise.slug, privacy: .public)")
        updateLiveActivity()
    }

    // MARK: - Actions: 終了

    /// 「やめる」。finishedAt を打って status を aborted に。完了済みセットは残す。
    func abort() {
        guard status == .running else { return }
        stopIntervalCountdown()
        if let session = fetchSession() {
            session.finishedAt = .now
            persist()
        }
        status = .aborted
        Logger.session.info("abort: id=\(self.sessionId, privacy: .public)")
        endLiveActivity()
        // v1.0 §5-3: レストタイマー Live Activity もロック画面から消す。
        Task { await stopRestTimerLiveActivity() }
        // v1.0 §-1.19: watchOS Widget 用に今日のサマリを更新(中断でもセット数は残す)。
        writeWatchSummary(isCompletedToday: false)
    }

    /// 全種目完了で呼ばれる。完了状態にして finishedAt を打つ。
    func finish() {
        guard status == .running else { return }
        stopIntervalCountdown()
        if let session = fetchSession() {
            session.finishedAt = .now
            persist()
        }
        status = .finished
        Logger.session.info("finish: id=\(self.sessionId, privacy: .public), completedSets=\(self.completedSets.count)")
        endLiveActivity()
        // v1.0 §5-3: レストタイマー Live Activity もロック画面から消す。
        Task { await stopRestTimerLiveActivity() }
        // v1.0 §-1.19: watchOS Widget 用に「完了」+今日のセット数を反映。
        writeWatchSummary(isCompletedToday: true)
        // v1.1 Watch quick-log(Phase 2-2): クイック記録の候補用に「最近使った種目」を配信。
        sendRecentExercisesToWatch()
    }

    // MARK: - Watch quick-log bridge (v1.1 Phase 2-2)

    /// このセッションで完了したセットから、種目重複なしで最大 8 件の
    /// `WatchRecentExercise` を作って Watch に送る。Watch 側はこれをクイック記録の
    /// 候補リスト・初期値(前回重量/回数)に使う。
    /// `watchSync` が nil(テスト / 未 DI)の場合は何もしない。
    private func sendRecentExercisesToWatch() {
        guard let watchSync else { return }
        var seenSlugs: Set<String> = []
        var recents: [WatchRecentExercise] = []
        // 新しく完了したセットを優先したいので逆順(直近優先)に走査する。
        for set in completedSets.reversed() {
            guard let exercise = set.exercise, seenSlugs.insert(exercise.slug).inserted else { continue }
            recents.append(
                WatchRecentExercise(
                    slug: exercise.slug,
                    nameJa: exercise.nameJa,
                    nameEn: exercise.nameEn,
                    lastWeightKg: set.weightKg > 0 ? set.weightKg : nil,
                    lastReps: set.reps > 0 ? set.reps : nil
                )
            )
            if recents.count >= 8 { break }
        }
        guard !recents.isEmpty else { return }
        watchSync.sendRecentExercises(recents)
    }

    // MARK: - Watch Widget bridge (v1.0 §-1.19)

    /// 今日のセッションサマリを App Group 共有 UserDefaults に書き出す。
    /// watchOS Widget(WorkoutKitWatch)はこの JSON を読んで Smart Stack に表示する。
    /// 失敗時は WatchSummaryBridge 内でログを残して握りつぶす。
    private func writeWatchSummary(isCompletedToday: Bool) {
        let summary = TodaySessionSummary.build(from: completedSets, isCompletedToday: isCompletedToday)
        WatchSummaryBridge.write(summary)
        // Audit A1: App Group はデバイスごとに独立しているため、Watch 側の Smart Stack
        // Widget にはこの WatchConnectivity 経由の配信でしか届かない。
        watchSync?.sendTodaySummary(summary)
    }

    // MARK: - Cursor advancement

    private func advanceCursor() {
        guard let item = currentItem else { return }
        if currentSetIndex < item.plannedSetCount - 1 {
            currentSetIndex += 1
            return
        }
        // 種目内の最終セット完了 → 次種目へ
        currentSetIndex = 0
        if currentItemIndex < plan.count - 1 {
            currentItemIndex += 1
        } else {
            finish()
        }
    }
}

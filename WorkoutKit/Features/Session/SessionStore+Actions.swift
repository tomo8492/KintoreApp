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
        }

        // C3: セット完了 / 種目進行に合わせて Live Activity を更新する。
        // finish() で end が呼ばれる場合は重複しないよう running 中のみ。
        if status == .running {
            updateLiveActivity()
        }
    }

    /// 現在種目をスキップして次種目の最初のセットへ。残りセットは記録しない。
    func skipCurrentExercise() {
        guard status == .running, currentItem != nil else { return }
        Logger.session.info("skipCurrentExercise at index=\(self.currentItemIndex)")
        stopIntervalCountdown()
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

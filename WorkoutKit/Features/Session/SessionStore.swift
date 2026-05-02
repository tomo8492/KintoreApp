// MARK: - SessionStore
// CLAUDE.md §1.1 F-03 / §-1.4 / §-1.6 / §11 準拠。
// セッション実行画面(F-03)の状態機械。
// - @Observable @MainActor。Singleton 禁止規約のため View が @State で所有する。
// - SwiftData の WorkoutSession / ExerciseSet を直接更新する(Repository 抽象は P2 で導入)。
// - 重量は内部単位 kg、表示変換は View 側で UnitsFormatter を通す。
// - C2 IntervalTimer / C3 Live Activity の差し込み口だけプロパティで開けておく。

import Foundation
import SwiftData
import SwiftUI
import OSLog

@Observable
@MainActor
final class SessionStore {

    // MARK: - Status

    enum Status: String, Sendable {
        case running
        case finished
        case aborted
    }

    // MARK: - Stored state

    private(set) var sessionId: UUID
    private(set) var goal: Goal
    private(set) var plan: [SessionPlanItem]
    private(set) var resolvedExercises: [String: Exercise] = [:]
    private(set) var completedSets: [ExerciseSet] = []
    private(set) var status: Status = .running

    var currentItemIndex: Int = 0
    var currentSetIndex: Int = 0

    // 入力フィールド(現在セット用、Bindable で View に渡す)。
    // 単位は内部 kg。lbs 表示は View で UnitsFormatter.toKilograms を通して書き戻す。
    var inputReps: Int = 8
    var inputWeightKg: Double = 0
    var inputRpe: Double? = nil
    var inputRestSeconds: Int = 60

    // MARK: - C2/C3 ホック
    //
    // 以下の interval* / intervalTimer / intervalTask は SessionStore+Interval.swift
    // からのみ書き込み、View は読むだけ。private にすると同モジュール別ファイル拡張から
    // 触れないため internal のままにしている(2026-05 現行 Swift の制約)。

    var intervalSecondsRemaining: Int? = nil
    var isIntervalRunning: Bool = false
    /// セット完了通知。C3 Live Activity / 外部購読者用。
    var onSetCompleted: ((ExerciseSet) -> Void)? = nil

    // MARK: - Dependencies

    private let modelContext: ModelContext
    let intervalTimer: IntervalTimer
    var intervalTask: Task<Void, Never>?

    // MARK: - Init (新規セッション)

    init(
        modelContext: ModelContext,
        goal: Goal,
        output: GeneratorOutput,
        includesWarmup: Bool,
        includesCooldown: Bool,
        intervalTimer: IntervalTimer = IntervalTimer()
    ) throws {
        self.modelContext = modelContext
        self.intervalTimer = intervalTimer
        self.goal = goal
        self.plan = .from(output: output)

        let session = WorkoutSession(
            goalRaw: goal.rawValue,
            includesWarmup: includesWarmup,
            includesCooldown: includesCooldown
        )
        modelContext.insert(session)
        try modelContext.save()
        self.sessionId = session.id

        try resolveExercises()
        Logger.session.info("SessionStore created: id=\(session.id, privacy: .public), planCount=\(self.plan.count)")
    }

    // MARK: - Init (復元)

    init(
        modelContext: ModelContext,
        snapshot: SessionRestoreSnapshot,
        intervalTimer: IntervalTimer = IntervalTimer()
    ) throws {
        self.modelContext = modelContext
        self.intervalTimer = intervalTimer
        self.sessionId = snapshot.sessionId
        self.plan = snapshot.plan
        self.currentItemIndex = snapshot.currentItemIndex
        self.currentSetIndex = snapshot.currentSetIndex

        // WorkoutSession 本体を引き直す。見つからない場合は復元失敗。
        let id = snapshot.sessionId
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        guard let session = try modelContext.fetch(descriptor).first else {
            throw AppError.dataCorruption("SessionRestore: WorkoutSession \(id) not found")
        }
        self.goal = session.goal
        self.completedSets = session.sets.sorted { $0.order < $1.order }

        try resolveExercises()
        Logger.session.info("SessionStore restored: id=\(id, privacy: .public), completed=\(self.completedSets.count)")
    }

    // MARK: - Derived

    var currentItem: SessionPlanItem? {
        guard plan.indices.contains(currentItemIndex) else { return nil }
        return plan[currentItemIndex]
    }

    var currentExercise: Exercise? {
        guard let slug = currentItem?.slug else { return nil }
        return resolvedExercises[slug]
    }

    var totalItemCount: Int { plan.count }

    var isFinished: Bool { status == .finished }
    var isAborted: Bool { status == .aborted }

    /// 復元用スナップショット。SceneStorage に書き出す。
    func snapshot() -> SessionRestoreSnapshot {
        SessionRestoreSnapshot(
            sessionId: sessionId,
            plan: plan,
            currentItemIndex: currentItemIndex,
            currentSetIndex: currentSetIndex
        )
    }

    /// 指定スラグの解決済み Exercise を返す。SessionView の一覧描画で使う。
    func exercise(for slug: String) -> Exercise? {
        resolvedExercises[slug]
    }

    /// 指定 plan item までに完了したセット数。SessionView の進捗バッジで使う。
    func completedSetCount(for item: SessionPlanItem) -> Int {
        completedSets.filter { $0.exercise?.slug == item.slug }.count
    }

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
    }

    /// 現在種目をスキップして次種目の最初のセットへ。残りセットは記録しない。
    func skipCurrentExercise() {
        guard status == .running, currentItem != nil else { return }
        Logger.session.info("skipCurrentExercise at index=\(self.currentItemIndex)")
        stopIntervalCountdown()
        currentSetIndex = 0
        if currentItemIndex < plan.count - 1 {
            currentItemIndex += 1
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
        resolvedExercises[newExercise.slug] = newExercise
        currentSetIndex = 0
        Logger.session.info("replaceCurrentExercise: -> \(newExercise.slug, privacy: .public)")
    }

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

    // MARK: - Persistence helpers

    private func resolveExercises() throws {
        let slugs = Set(plan.map(\.slug))
        guard !slugs.isEmpty else { return }
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { slugs.contains($0.slug) }
        )
        let fetched = try modelContext.fetch(descriptor)
        var map: [String: Exercise] = [:]
        for ex in fetched { map[ex.slug] = ex }
        self.resolvedExercises = map
        if fetched.count != slugs.count {
            let missing = slugs.subtracting(fetched.map(\.slug))
            Logger.session.warning("resolveExercises: missing=\(missing.joined(separator: ","), privacy: .public)")
        }
    }

    private func fetchSession() -> WorkoutSession? {
        let id = sessionId
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func persist() {
        do {
            try modelContext.save()
        } catch {
            Logger.session.error("modelContext.save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

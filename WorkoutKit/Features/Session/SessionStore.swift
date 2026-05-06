// MARK: - SessionStore
// CLAUDE.md §1.1 F-03 / §-1.4 / §-1.6 / §11 準拠。
// セッション実行画面(F-03)の状態機械。
// - @Observable @MainActor。Singleton 禁止規約のため View が @State で所有する。
// - SwiftData の WorkoutSession / ExerciseSet を直接更新する(Repository 抽象は P2 で導入)。
// - 重量は内部単位 kg、表示変換は View 側で UnitsFormatter を通す。
// - C2 IntervalTimer / C3 Live Activity の差し込み口だけプロパティで開けておく。
//
// ファイル分割(CLAUDE.md「1 ファイル 300 行超で分割」):
//   - 本ファイル: 宣言・state・両 init・derived・スナップショット・永続化ヘルパー
//   - SessionStore+Actions.swift: completeCurrentSet / skip / replace / abort / finish
//   - SessionStore+Interval.swift: IntervalTimer 連携
//   - SessionStore+LiveActivity.swift: Live Activity 連携

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
    var plan: [SessionPlanItem]
    private(set) var resolvedExercises: [String: Exercise] = [:]
    var completedSets: [ExerciseSet] = []
    var status: Status = .running

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

    let modelContext: ModelContext
    let intervalTimer: IntervalTimer
    /// C3: Live Activity への通知。nil ならテスト or 機能無効。
    let liveActivity: LiveActivityClient?
    var intervalTask: Task<Void, Never>?

    // MARK: - Init (新規セッション)

    init(
        modelContext: ModelContext,
        goal: Goal,
        output: GeneratorOutput,
        includesWarmup: Bool,
        includesCooldown: Bool,
        intervalTimer: IntervalTimer = IntervalTimer(),
        liveActivity: LiveActivityClient? = nil
    ) throws {
        self.modelContext = modelContext
        self.intervalTimer = intervalTimer
        self.liveActivity = liveActivity
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
        startLiveActivityIfPossible()
    }

    // MARK: - Init (復元)

    init(
        modelContext: ModelContext,
        snapshot: SessionRestoreSnapshot,
        intervalTimer: IntervalTimer = IntervalTimer(),
        liveActivity: LiveActivityClient? = nil
    ) throws {
        self.modelContext = modelContext
        self.intervalTimer = intervalTimer
        self.liveActivity = liveActivity
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
        startLiveActivityIfPossible()
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

    // MARK: - Persistence helpers
    // SessionStore+Actions.swift から呼ばれるため、内部公開(internal)に開けている。
    // ファイル外への公開はしないので extension の中にしか登場しない想定。

    func replaceExercise(slug: String, with exercise: Exercise) {
        resolvedExercises[slug] = exercise
    }

    func fetchSession() -> WorkoutSession? {
        let id = sessionId
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    func persist() {
        do {
            try modelContext.save()
        } catch {
            Logger.session.error("modelContext.save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

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
}

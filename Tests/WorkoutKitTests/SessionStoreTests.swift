// MARK: - SessionStoreTests
// CLAUDE.md §1.1 F-03 / §9.1 準拠。
// SessionStore のステート遷移を Swift Testing で凍結する。
// - in-memory ModelContainer で WorkoutSession / ExerciseSet / Exercise を扱う
// - liveActivity は nil 注入で副作用を排除
// - inputRestSeconds = 0 で IntervalTimer の非同期タスクを起動させない

import Foundation
import SwiftData
import Testing
@testable import WorkoutKit

@MainActor
@Suite("SessionStore")
struct SessionStoreTests {

    // MARK: - Helpers

    private static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private static func makeExercise(slug: String, primary: Muscle = .chest) -> Exercise {
        Exercise(
            slug: slug,
            slugJa: slug,
            nameJa: slug,
            nameEn: slug,
            typeRaw: ExerciseType.calisthenics.rawValue,
            mechanicsTypeRaw: MechanicsType.compound.rawValue,
            primaryMuscleRaw: primary.rawValue,
            secondaryMusclesRaw: "",
            equipmentRaw: Equipment.bodyweight.rawValue
        )
    }

    /// warmup 1 / main 2 / cooldown 1 の最小プラン。slug は test-* 固定。
    private static func defaultOutput() -> GeneratorOutput {
        GeneratorOutput(
            warmup: ["test-warmup"],
            main: ["test-main-1", "test-main-2"],
            cooldown: ["test-cooldown"]
        )
    }

    /// defaultOutput が参照する4種目を context に投入する。
    private static func seedExercisesForDefaultOutput(_ context: ModelContext) {
        for slug in ["test-warmup", "test-main-1", "test-main-2", "test-cooldown"] {
            context.insert(makeExercise(slug: slug))
        }
        try? context.save()
    }

    private static func makeStore(
        in context: ModelContext,
        goal: Goal = .hypertrophy,
        includesWarmup: Bool = true,
        includesCooldown: Bool = true
    ) throws -> SessionStore {
        try SessionStore(
            modelContext: context,
            goal: goal,
            output: defaultOutput(),
            includesWarmup: includesWarmup,
            includesCooldown: includesCooldown,
            liveActivity: nil
        )
    }

    /// 入力デフォルトを「休憩なし(=タイマー非起動)」に固定する。
    private static func suppressInterval(_ store: SessionStore) {
        store.inputRestSeconds = 0
    }

    // MARK: - Init

    @Test("init で plan は warmup → main → cooldown の順、合計 4 アイテム")
    func planIsBuiltInOrder() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)

        #expect(store.plan.count == 4)
        #expect(store.plan[0].section == .warmup)
        #expect(store.plan[1].section == .main)
        #expect(store.plan[2].section == .main)
        #expect(store.plan[3].section == .cooldown)
        #expect(store.plan.map(\.slug) == ["test-warmup", "test-main-1", "test-main-2", "test-cooldown"])
        #expect(store.status == .running)
        #expect(store.currentItemIndex == 0)
        #expect(store.currentSetIndex == 0)
    }

    @Test("init で WorkoutSession が ModelContext に保存され、resolvedExercises も埋まる")
    func initInsertsWorkoutSessionAndResolvesExercises() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)

        // 全 slug が解決されている
        #expect(store.resolvedExercises.count == 4)
        #expect(store.resolvedExercises["test-main-1"] != nil)

        // ModelContext にも WorkoutSession が居る
        let descriptor = FetchDescriptor<WorkoutSession>()
        let sessions = try context.fetch(descriptor)
        #expect(sessions.count == 1)
        #expect(sessions[0].id == store.sessionId)
        #expect(sessions[0].finishedAt == nil)
    }

    // MARK: - completeCurrentSet → cursor 前進

    @Test("completeCurrentSet で1セット記録され、currentSetIndex が増える")
    func completeAdvancesSetCursor() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)
        store.inputReps = 10
        store.inputWeightKg = 50

        // warmup の plannedSetCount = 1 → 完了で次種目へ進む(set index は 0 にリセット)
        store.completeCurrentSet()
        #expect(store.completedSets.count == 1)
        #expect(store.currentItemIndex == 1) // warmup → main-1
        #expect(store.currentSetIndex == 0)

        let recorded = store.completedSets[0]
        #expect(recorded.reps == 10)
        #expect(recorded.weightKg == 50)
        #expect(recorded.section == .warmup)
    }

    @Test("main 種目の plannedSetCount=3 を完走すると次種目に進む")
    func completeAdvancesItemAfterAllSets() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)

        // warmup を1セットで終わらせて main へ
        store.completeCurrentSet()
        #expect(store.currentItemIndex == 1)

        // main-1 は 3 セット
        store.completeCurrentSet()
        #expect(store.currentItemIndex == 1)
        #expect(store.currentSetIndex == 1)
        store.completeCurrentSet()
        #expect(store.currentSetIndex == 2)
        store.completeCurrentSet()
        // 3セット完了 → main-2 へ
        #expect(store.currentItemIndex == 2)
        #expect(store.currentSetIndex == 0)
    }

    @Test("全種目を完走すると status=.finished、finishedAt が打たれる")
    func completeAllSetsFinishesSession() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)

        // warmup(1) + main-1(3) + main-2(3) + cooldown(1) = 8 セット
        for _ in 0..<8 {
            store.completeCurrentSet()
        }

        #expect(store.status == .finished)
        #expect(store.isFinished == true)

        let descriptor = FetchDescriptor<WorkoutSession>()
        let session = try #require(try context.fetch(descriptor).first)
        #expect(session.finishedAt != nil)
    }

    // MARK: - skip

    @Test("skipCurrentExercise で残セットを記録せずに次種目へ進む")
    func skipAdvancesWithoutRecording() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)

        // warmup 完了で main-1 に居る状態を作る
        store.completeCurrentSet()
        #expect(store.currentItemIndex == 1)
        let countBefore = store.completedSets.count

        store.skipCurrentExercise()

        #expect(store.currentItemIndex == 2) // main-1 を飛ばして main-2
        #expect(store.currentSetIndex == 0)
        #expect(store.completedSets.count == countBefore) // 記録は増えない
    }

    @Test("最終種目で skip すると finish される")
    func skipOnLastExerciseFinishes() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)

        // 最終 cooldown まで進める
        store.currentItemIndex = store.plan.count - 1
        #expect(store.status == .running)

        store.skipCurrentExercise()
        #expect(store.status == .finished)
    }

    // MARK: - replaceCurrentExercise

    @Test("replaceCurrentExercise で現在 plan item の slug が新種目に差し替わる")
    func replaceCurrentExerciseUpdatesPlan() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let replacement = Self.makeExercise(slug: "swap-target")
        context.insert(replacement)
        try context.save()

        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)

        // warmup を完了して main-1 に居る状態
        store.completeCurrentSet()
        let originalSection = store.plan[store.currentItemIndex].section
        let originalCount = store.plan[store.currentItemIndex].plannedSetCount

        store.replaceCurrentExercise(with: replacement)

        #expect(store.plan[store.currentItemIndex].slug == "swap-target")
        #expect(store.plan[store.currentItemIndex].section == originalSection)
        #expect(store.plan[store.currentItemIndex].plannedSetCount == originalCount)
        #expect(store.currentSetIndex == 0)
        #expect(store.resolvedExercises["swap-target"] != nil)
    }

    // MARK: - abort

    @Test("abort で status=.aborted、finishedAt が打たれ completedSets は残る")
    func abortPreservesCompletedSets() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)

        store.completeCurrentSet()
        let recorded = store.completedSets.count

        store.abort()

        #expect(store.status == .aborted)
        #expect(store.isAborted == true)
        #expect(store.completedSets.count == recorded)

        let descriptor = FetchDescriptor<WorkoutSession>()
        let session = try #require(try context.fetch(descriptor).first)
        #expect(session.finishedAt != nil)
    }

    @Test("running でないときは abort / finish / completeCurrentSet が no-op")
    func actionsAreNoopWhenNotRunning() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)

        store.abort()
        let recordedAfterAbort = store.completedSets.count

        // abort 後にこれらを叩いても状態は変わらない
        store.completeCurrentSet()
        store.skipCurrentExercise()
        store.finish()

        #expect(store.status == .aborted)
        #expect(store.completedSets.count == recordedAfterAbort)
    }

    // MARK: - Snapshot / Restore

    @Test("snapshot → 新 SessionStore で復元すると plan / カーソル / completedSets が一致")
    func snapshotRoundtripPreservesState() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store1 = try Self.makeStore(in: context)
        Self.suppressInterval(store1)

        // warmup + main-1 1セット完了させてからスナップショット
        store1.completeCurrentSet()
        store1.inputReps = 5
        store1.inputWeightKg = 30
        store1.completeCurrentSet()

        let snapshot = store1.snapshot()
        #expect(snapshot.sessionId == store1.sessionId)
        #expect(snapshot.plan == store1.plan)
        #expect(snapshot.currentItemIndex == store1.currentItemIndex)

        let store2 = try SessionStore(
            modelContext: context,
            snapshot: snapshot,
            liveActivity: nil
        )

        #expect(store2.sessionId == store1.sessionId)
        #expect(store2.plan == store1.plan)
        #expect(store2.currentItemIndex == store1.currentItemIndex)
        #expect(store2.currentSetIndex == store1.currentSetIndex)
        #expect(store2.completedSets.count == store1.completedSets.count)
        #expect(store2.goal == store1.goal)
    }

    @Test("snapshot は JSON encode/decode を経由しても等価")
    func snapshotJSONRoundtrip() throws {
        let context = try Self.makeContext()
        Self.seedExercisesForDefaultOutput(context)
        let store = try Self.makeStore(in: context)
        Self.suppressInterval(store)
        store.completeCurrentSet()

        let original = store.snapshot()
        let encoded = try #require(original.encoded())
        let decoded = try #require(SessionRestoreSnapshot.decoded(from: encoded))

        #expect(decoded.sessionId == original.sessionId)
        #expect(decoded.plan == original.plan)
        #expect(decoded.currentItemIndex == original.currentItemIndex)
        #expect(decoded.currentSetIndex == original.currentSetIndex)
    }
}

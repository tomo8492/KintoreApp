// MARK: - BuilderStoreTests
// CLAUDE.md §1.1 F-01 / §9.1 準拠。
// Builder ウィザードの状態機械(BuilderStore)を Swift Testing で凍結する。
// 既存 WorkoutGeneratorTests と同じ in-memory ModelContainer パターンを踏襲。

import Foundation
import SwiftData
import Testing
@testable import WorkoutKit

@MainActor
@Suite("BuilderStore")
struct BuilderStoreTests {

    // MARK: - Helpers (WorkoutGeneratorTests と同形)

    private static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private static func makeExercise(
        slug: String,
        type: ExerciseType,
        mechanics: MechanicsType? = .compound,
        primary: Muscle,
        secondaries: [Muscle] = [],
        equipment: [Equipment] = [.bodyweight]
    ) -> Exercise {
        Exercise(
            slug: slug,
            slugJa: slug,
            nameJa: slug,
            nameEn: slug,
            typeRaw: type.rawValue,
            mechanicsTypeRaw: mechanics?.rawValue,
            primaryMuscleRaw: primary.rawValue,
            secondaryMusclesRaw: secondaries.map(\.rawValue).joined(separator: ","),
            equipmentRaw: equipment.map(\.rawValue).joined(separator: ",")
        )
    }

    /// confirm() を成功させるための最小 seed(胸 × 自重 で 4 compound + warmup/stretching 各 4)。
    private static func seedMinimal(_ context: ModelContext) {
        for i in 1...4 {
            context.insert(makeExercise(
                slug: "chest-c-\(i)",
                type: .calisthenics,
                mechanics: .compound,
                primary: .chest,
                equipment: [.bodyweight]
            ))
        }
        for i in 1...4 {
            context.insert(makeExercise(
                slug: "wu-\(i)",
                type: .warmup,
                mechanics: nil,
                primary: .fullBody,
                equipment: [.bodyweight]
            ))
            context.insert(makeExercise(
                slug: "st-\(i)",
                type: .stretching,
                mechanics: nil,
                primary: .chest,
                equipment: [.bodyweight]
            ))
        }
        try? context.save()
    }

    /// 胸 + 自重 + 45 分の典型入力。canAdvance を全ステップで true にできる。
    private static func defaultInputForChestBodyweight() -> GeneratorInput {
        GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 45,
            includeWarmup: true,
            includeCooldown: true
        )
    }

    // MARK: - Step transitions

    @Test("初期状態: currentStep=.goal、output=nil、isGenerating=false")
    func initialState() {
        let store = BuilderStore()
        #expect(store.currentStep == .goal)
        #expect(store.output == nil)
        #expect(store.isGenerating == false)
        #expect(store.mode == .shuffle)
        #expect(store.sessionStart == nil)
        #expect(store.canGoBack == false)
    }

    @Test("next() で goal → muscle → equipment → time へ遷移するが result までは行かない")
    func nextAdvancesUpToTimeButNotResult() {
        let store = BuilderStore(input: Self.defaultInputForChestBodyweight())

        store.next()
        #expect(store.currentStep == .muscle)
        store.next()
        #expect(store.currentStep == .equipment)
        store.next()
        #expect(store.currentStep == .time)
        // time から result への遷移は confirm() のみ。
        store.next()
        #expect(store.currentStep == .time)
    }

    @Test("back() で前ステップへ。result から戻ると output と generationError が破棄される")
    func backFromResultClearsOutput() throws {
        let context = try Self.makeContext()
        Self.seedMinimal(context)
        let store = BuilderStore(input: Self.defaultInputForChestBodyweight())
        store.currentStep = .time
        store.confirm(in: context)
        #expect(store.currentStep == .result)
        #expect(store.output != nil)

        store.back()
        #expect(store.currentStep == .time)
        #expect(store.output == nil)
        #expect(store.generationError == nil)
    }

    @Test("goal ステップで back しても範囲外には行かない(no-op)")
    func backFromGoalIsNoOp() {
        let store = BuilderStore()
        store.back()
        #expect(store.currentStep == .goal)
    }

    // MARK: - canAdvance

    @Test("canAdvance: goal は常に true、muscle は通常 1 つ以上必要、equipment 同様")
    func canAdvanceMatrix() {
        var input = Self.defaultInputForChestBodyweight()
        input.muscles = []
        input.equipment = []
        let store = BuilderStore(input: input)

        // goal ステップは常に true
        #expect(store.canAdvance == true)

        // muscle ステップで muscles 空 → false
        store.currentStep = .muscle
        #expect(store.canAdvance == false)
        store.input.muscles = [.chest]
        #expect(store.canAdvance == true)

        // equipment ステップで equipment 空 → false
        store.currentStep = .equipment
        store.input.equipment = []
        #expect(store.canAdvance == false)
        store.input.equipment = [.bodyweight]
        #expect(store.canAdvance == true)

        // time ステップは minutesAvailable > 0 が条件
        store.currentStep = .time
        store.input.minutesAvailable = 0
        #expect(store.canAdvance == false)
        store.input.minutesAvailable = 45
        #expect(store.canAdvance == true)

        // result ステップは「次がない」ので false
        store.currentStep = .result
        #expect(store.canAdvance == false)
    }

    @Test("flexibility / cardio 目的では muscle 未選択でも canAdvance=true")
    func flexibilityAndCardioBypassMuscleRequirement() {
        var input = Self.defaultInputForChestBodyweight()
        input.muscles = []
        let store = BuilderStore(input: input)
        store.currentStep = .muscle

        store.input.goal = .flexibility
        #expect(store.canAdvance == true)
        store.input.goal = .cardio
        #expect(store.canAdvance == true)
        store.input.goal = .hypertrophy
        #expect(store.canAdvance == false)
    }

    // MARK: - confirm() / regenerate()

    @Test("confirm() 成功で output が埋まり currentStep=.result に進む")
    func confirmSuccessAdvancesToResult() throws {
        let context = try Self.makeContext()
        Self.seedMinimal(context)
        let store = BuilderStore(input: Self.defaultInputForChestBodyweight())
        store.currentStep = .time

        store.confirm(in: context)

        #expect(store.currentStep == .result)
        #expect(store.output != nil)
        #expect(store.generationError == nil)
        #expect(store.isGenerating == false)
    }

    @Test("confirm() 失敗(空 DB)では currentStep は .time のまま、generationError がセットされる")
    func confirmFailureKeepsCurrentStep() throws {
        let context = try Self.makeContext()
        // seed 投入なし
        let store = BuilderStore(input: Self.defaultInputForChestBodyweight())
        store.currentStep = .time

        store.confirm(in: context)

        #expect(store.currentStep == .time)
        #expect(store.output == nil)
        #expect(store.generationError != nil)
        #expect(store.isGenerating == false)
    }

    @Test("regenerate() は currentStep を変えない(再シャッフル用フック)")
    func regenerateDoesNotAdvance() throws {
        let context = try Self.makeContext()
        Self.seedMinimal(context)
        let store = BuilderStore(input: Self.defaultInputForChestBodyweight())
        store.currentStep = .result

        store.regenerate(in: context)

        #expect(store.currentStep == .result)
        #expect(store.output != nil)
    }

    // MARK: - Locks (B3 Choose mode)

    @Test("toggleLock / clearLocks の状態遷移")
    func toggleAndClearLocks() {
        let store = BuilderStore(input: Self.defaultInputForChestBodyweight())
        #expect(store.lockedSlugs.isEmpty)

        store.toggleLock("squat")
        #expect(store.lockedSlugs == ["squat"])
        store.toggleLock("bench")
        #expect(store.lockedSlugs == ["squat", "bench"])
        store.toggleLock("squat")
        #expect(store.lockedSlugs == ["bench"])

        store.clearLocks()
        #expect(store.lockedSlugs.isEmpty)
    }

    // MARK: - Session start payload

    @Test("output が nil のときは startSession() は no-op で sessionStart も nil のまま")
    func startSessionWithoutOutputIsNoop() {
        let store = BuilderStore(input: Self.defaultInputForChestBodyweight())
        #expect(store.output == nil)

        store.startSession()
        #expect(store.sessionStart == nil)
    }

    @Test("startSession() は output / goal / includes flags を payload に詰める")
    func startSessionBuildsPayload() throws {
        let context = try Self.makeContext()
        Self.seedMinimal(context)
        var input = Self.defaultInputForChestBodyweight()
        input.includeWarmup = true
        input.includeCooldown = false
        let store = BuilderStore(input: input)
        store.currentStep = .time
        store.confirm(in: context)
        #expect(store.output != nil)

        store.startSession()

        let payload = try #require(store.sessionStart)
        #expect(payload.goal == .hypertrophy)
        #expect(payload.includesWarmup == true)
        #expect(payload.includesCooldown == false)
        #expect(payload.output == store.output)
    }
}

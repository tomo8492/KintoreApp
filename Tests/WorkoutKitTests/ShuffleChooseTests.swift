// MARK: - ShuffleChooseTests
// CLAUDE.md §1.1 F-01a / B3 受け入れ基準を凍結する Swift Testing スイート。
// - ロック済み種目が再生成後も保持されること
// - Choose モードで候補プールが正しくフィルタされること

import Foundation
import SwiftData
import Testing
@testable import WorkoutKit

@MainActor
@Suite("ShuffleChoose")
struct ShuffleChooseTests {

    // MARK: - Helpers (WorkoutGeneratorTests と同形)

    private static func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SchemaV1.self, configurations: config)
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

    /// 胸+自重 メイン 8 種目(compound 4 + isolation 4)+ 背中 4 種目 + 脚 4 種目。
    /// candidatePool フィルタ検証用に他部位/他器具も混ぜる。
    private static func seedMixed(_ context: ModelContext) {
        for i in 1...4 {
            context.insert(makeExercise(
                slug: "chest-compound-\(i)",
                type: .calisthenics,
                mechanics: .compound,
                primary: .chest,
                secondaries: [.triceps, .deltoids],
                equipment: [.bodyweight]
            ))
            context.insert(makeExercise(
                slug: "chest-isolation-\(i)",
                type: .calisthenics,
                mechanics: .isolation,
                primary: .chest,
                secondaries: [],
                equipment: [.bodyweight]
            ))
            // 背中(自重)
            context.insert(makeExercise(
                slug: "back-compound-\(i)",
                type: .calisthenics,
                mechanics: .compound,
                primary: .lats,
                equipment: [.bodyweight]
            ))
            // 脚(バーベル) — 自重では弾かれるはず
            context.insert(makeExercise(
                slug: "leg-barbell-\(i)",
                type: .strength,
                mechanics: .compound,
                primary: .quadriceps,
                equipment: [.barbell]
            ))
        }
        // 補助種目(候補プールには出ない)
        for i in 1...3 {
            context.insert(makeExercise(
                slug: "warmup-\(i)",
                type: .warmup,
                mechanics: nil,
                primary: .fullBody
            ))
            context.insert(makeExercise(
                slug: "stretch-\(i)",
                type: .stretching,
                mechanics: nil,
                primary: .fullBody
            ))
        }
    }

    // MARK: - Tests

    @Test("ロック済み種目は regenerate 後も main に残る(seed を変えても)")
    func lockedSlugsPersistAcrossRegenerate() throws {
        let ctx = try Self.makeContext()
        Self.seedMixed(ctx)

        let store = BuilderStore(input: GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 30,
            includeWarmup: false,
            includeCooldown: false,
            randomSeed: 1
        ))

        // 1回目の生成: confirm() で result へ。
        store.confirm(in: ctx)
        guard let firstOutput = store.output else {
            Issue.record("expected output after confirm()")
            return
        }
        let firstMain = firstOutput.main
        try #require(firstMain.count >= 2)

        // 先頭 2 つを Choose モードでロック。
        let lockA = firstMain[0]
        let lockB = firstMain[1]
        store.toggleLock(lockA)
        store.toggleLock(lockB)
        #expect(store.lockedSlugs == [lockA, lockB])

        // 別 seed で再生成 → 並びが変わっても lock は維持されているはず。
        store.input.randomSeed = 9999
        store.regenerate(in: ctx)

        guard let secondOutput = store.output else {
            Issue.record("expected output after regenerate()")
            return
        }
        #expect(secondOutput.main.contains(lockA))
        #expect(secondOutput.main.contains(lockB))
    }

    @Test("toggleLock は同じ slug で呼ぶとロックを外す")
    func toggleLockIsIdempotentInverse() throws {
        let store = BuilderStore()
        store.toggleLock("chest-compound-1")
        #expect(store.lockedSlugs.contains("chest-compound-1"))
        store.toggleLock("chest-compound-1")
        #expect(store.lockedSlugs.isEmpty)
    }

    @Test("clearLocks で全ロックが外れる")
    func clearLocksRemovesAll() throws {
        let store = BuilderStore()
        store.toggleLock("a")
        store.toggleLock("b")
        store.clearLocks()
        #expect(store.lockedSlugs.isEmpty)
    }

    @Test("candidatePool は muscle / equipment フィルタが効く")
    func candidatePoolFiltersByMuscleAndEquipment() throws {
        let ctx = try Self.makeContext()
        Self.seedMixed(ctx)

        let input = GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 30,
            includeWarmup: false,
            includeCooldown: false
        )
        let pool = try WorkoutGenerator.candidatePool(input, in: ctx)

        // warmup / stretching は除外される
        for ex in pool {
            #expect(ex.type != .warmup, "pool should not contain warmup: \(ex.slug)")
            #expect(ex.type != .stretching, "pool should not contain stretching: \(ex.slug)")
        }
        // すべて chest に primary か secondary でマッチ
        for ex in pool {
            let hits = ex.primaryMuscle == .chest || ex.secondaryMuscles.contains(.chest)
            #expect(hits, "pool member \(ex.slug) does not match chest")
        }
        // すべて bodyweight 可(barbell-only は弾かれている)
        for ex in pool {
            let allowsBodyweight = ex.equipment.isEmpty || ex.equipment.contains(.bodyweight)
            #expect(allowsBodyweight, "pool member \(ex.slug) requires non-bodyweight")
        }
        // 胸-自重 8 種目だけが残るはず(背中・脚バーベル・warmup・stretch は除外)
        #expect(pool.count == 8)
    }

    @Test("candidatePool は slug 昇順で返る(再現性)")
    func candidatePoolIsSortedBySlug() throws {
        let ctx = try Self.makeContext()
        Self.seedMixed(ctx)

        let input = GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest, .lats],
            equipment: [.bodyweight],
            minutesAvailable: 30,
            includeWarmup: false,
            includeCooldown: false
        )
        let pool = try WorkoutGenerator.candidatePool(input, in: ctx)
        let slugs = pool.map(\.slug)
        #expect(slugs == slugs.sorted())
    }

    @Test("BuilderStore.mode の初期値は .shuffle")
    func defaultModeIsShuffle() {
        let store = BuilderStore()
        #expect(store.mode == .shuffle)
    }
}

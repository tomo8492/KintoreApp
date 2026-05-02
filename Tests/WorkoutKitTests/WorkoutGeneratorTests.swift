// MARK: - WorkoutGeneratorTests
// CLAUDE.md §4.3 / §9.1 準拠。Swift Testing で WorkoutGenerator の主要パスを凍結。
// SwiftData は in-memory ModelContainer を使い、各テストで独立した文脈を組み立てる。

import Foundation
import SwiftData
import Testing
@testable import WorkoutKit

@MainActor
@Suite("WorkoutGenerator")
struct WorkoutGeneratorTests {

    // MARK: - Helpers

    /// in-memory な ModelContainer を SchemaV1 で作る。各テストで独立。
    private static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// 任意のメイン種目を作るユーティリティ。
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

    /// 胸+自重 で 8 種目、加えて WARMUP 5 / STRETCHING 5 を投入する標準セット。
    private static func seedStandard(_ context: ModelContext) {
        // メイン: 胸 × 自重(compound 4 + isolation 4)
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
        }
        // WARMUP 5
        for i in 1...5 {
            context.insert(makeExercise(
                slug: "warmup-\(i)",
                type: .warmup,
                mechanics: nil,
                primary: .fullBody,
                equipment: [.bodyweight]
            ))
        }
        // STRETCHING 5(うち2つは胸ストレッチ)
        for i in 1...3 {
            context.insert(makeExercise(
                slug: "stretch-general-\(i)",
                type: .stretching,
                mechanics: nil,
                primary: .fullBody,
                equipment: [.bodyweight]
            ))
        }
        for i in 1...2 {
            context.insert(makeExercise(
                slug: "stretch-chest-\(i)",
                type: .stretching,
                mechanics: nil,
                primary: .chest,
                equipment: [.bodyweight]
            ))
        }
    }

    // MARK: - Tests

    @Test("胸+自重+45分(warmup/cooldown 含む)で main 5種目以上が返る")
    func mainHasFiveOrMoreForChestBodyweight45min() throws {
        let ctx = try Self.makeContext()
        Self.seedStandard(ctx)

        let input = GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 45,
            includeWarmup: true,
            includeCooldown: true,
            randomSeed: 42
        )
        let out = try WorkoutGenerator.generate(input, in: ctx)
        // 45 - 5(warmup) - 5(cooldown) = 35 → 35 / 5 = 7 種目目標。
        // プールが 8 種目なので 7 取れる。下限保証として 5 を確認。
        #expect(out.main.count >= 5)
        #expect(!out.warmup.isEmpty)
        #expect(!out.cooldown.isEmpty)
    }

    @Test("flexibility 目的 → main は空、cooldown のみ返る")
    func flexibilityProducesOnlyCooldown() throws {
        let ctx = try Self.makeContext()
        Self.seedStandard(ctx)

        let input = GeneratorInput(
            goal: .flexibility,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 30,
            includeWarmup: false,
            includeCooldown: true,
            randomSeed: 1
        )
        let out = try WorkoutGenerator.generate(input, in: ctx)
        #expect(out.main.isEmpty)
        #expect(out.warmup.isEmpty)
        #expect(!out.cooldown.isEmpty)
    }

    @Test("lockedExerciseSlugs が必ず main に含まれる")
    func lockedExercisesAlwaysIncluded() throws {
        let ctx = try Self.makeContext()
        Self.seedStandard(ctx)

        let locked: Set<String> = ["chest-compound-1", "chest-isolation-2"]
        let input = GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 30,
            includeWarmup: false,
            includeCooldown: false,
            lockedExerciseSlugs: locked,
            randomSeed: 7
        )
        let out = try WorkoutGenerator.generate(input, in: ctx)
        for slug in locked {
            #expect(out.main.contains(slug), "locked slug \(slug) must be in main")
        }
    }

    @Test("同じ seed なら同じ出力(再現性)")
    func sameSeedProducesSameOutput() throws {
        let ctx = try Self.makeContext()
        Self.seedStandard(ctx)

        let input = GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 45,
            includeWarmup: true,
            includeCooldown: true,
            randomSeed: 12345
        )
        let a = try WorkoutGenerator.generate(input, in: ctx)
        let b = try WorkoutGenerator.generate(input, in: ctx)
        #expect(a == b)
    }

    @Test("空の DB に対しては AppError.generatorEmpty を投げる")
    func emptyDatabaseThrowsGeneratorEmpty() throws {
        let ctx = try Self.makeContext()
        // 何も投入しない

        let input = GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 45,
            includeWarmup: true,
            includeCooldown: true
        )

        var thrown: AppError?
        do {
            _ = try WorkoutGenerator.generate(input, in: ctx)
        } catch let err as AppError {
            thrown = err
        }
        guard case .generatorEmpty = thrown else {
            Issue.record("expected AppError.generatorEmpty, got \(String(describing: thrown))")
            return
        }
    }

    @Test("条件にマッチする種目が無くても warmup/cooldown があれば throw しない")
    func auxOnlyDoesNotThrow() throws {
        let ctx = try Self.makeContext()
        // WARMUP / STRETCHING のみ投入(メイン候補ゼロ)
        for i in 1...5 {
            ctx.insert(Self.makeExercise(
                slug: "w\(i)", type: .warmup, mechanics: nil, primary: .fullBody
            ))
            ctx.insert(Self.makeExercise(
                slug: "s\(i)", type: .stretching, mechanics: nil, primary: .fullBody
            ))
        }
        let input = GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest],
            equipment: [.bodyweight],
            minutesAvailable: 30,
            includeWarmup: true,
            includeCooldown: true,
            randomSeed: 9
        )
        let out = try WorkoutGenerator.generate(input, in: ctx)
        #expect(out.main.isEmpty)
        #expect(!out.warmup.isEmpty)
        #expect(!out.cooldown.isEmpty)
    }
}

// MARK: - WorkoutGenerator
// CLAUDE.md §4.3 準拠の自動生成ロジック(Phase P1 本実装)。
//
// 規約:
// - non-isolated(MainActor 外、Repository/Importer と同じ)
// - 例外は throws、UI 側で AppError に正規化
// - 種目0件の場合は AppError.generatorEmpty を投げる
// - randomSeed があれば SeededGenerator(SplitMix64)を使い、無ければ SystemRandomNumberGenerator
//
// データ量(同梱150種目)が小さいため、SwiftData 側では typeRaw による単純な
// #Predicate でラフに絞り込み、equipment / muscle のような CSV 文字列カラムは
// in-memory で正確に判定する。Predicate 上の文字列 contains は誤マッチを起こすため。
//
// 入出力 DTO は WorkoutGeneratorTypes.swift、ヘルパは WorkoutGeneratorHelpers.swift に分割。

import Foundation
import SwiftData
import OSLog

enum WorkoutGenerator {

    /// 1メイン種目あたりの所要時間(分)。3セット × ワーク+休憩 ≈ 5 分の目安。
    static let minutesPerMainExercise = 5
    /// warmup / cooldown それぞれに割り当てる時間(分)。
    static let warmupCooldownBudgetMinutes = 5
    /// warmup / cooldown 種目数の下限・上限(CLAUDE.md §4.3 「3〜5 種目」)。
    static let auxCountRange: ClosedRange<Int> = 3...5

    /// 入力条件に対して warmup / main / cooldown 各パートの種目並びを返す。
    static func generate(_ input: GeneratorInput, in context: ModelContext) throws -> GeneratorOutput {
        Logger.generator.debug(
            "generate: goal=\(input.goal.rawValue, privacy: .public), muscles=\(input.muscles.count), equipment=\(input.equipment.count), minutes=\(input.minutesAvailable), seed=\(input.randomSeed ?? 0)"
        )

        if let seed = input.randomSeed {
            var rng = SeededGenerator(seed: seed)
            return try run(input: input, context: context, rng: &rng)
        } else {
            var rng = SystemRandomNumberGenerator()
            return try run(input: input, context: context, rng: &rng)
        }
    }

    // MARK: - Core pipeline

    private static func run<R: RandomNumberGenerator>(
        input: GeneratorInput,
        context: ModelContext,
        rng: inout R
    ) throws -> GeneratorOutput {

        // 1. 時間配分
        let warmupMin = input.includeWarmup ? warmupCooldownBudgetMinutes : 0
        let cooldownMin = input.includeCooldown ? warmupCooldownBudgetMinutes : 0
        let mainMin = max(0, input.minutesAvailable - warmupMin - cooldownMin)
        let targetMainCount = mainMin / minutesPerMainExercise

        // 2. メイン種目(flexibility は持たない)
        var mainExercises: [Exercise] = []
        if input.goal != .flexibility, targetMainCount > 0 {
            mainExercises = try generateMain(
                input: input,
                target: targetMainCount,
                context: context,
                rng: &rng
            )
        }
        let mainSlugs = mainExercises.map(\.slug)
        let mainMuscles = Set(mainExercises.map(\.primaryMuscle))

        // 3. ウォームアップ
        var warmupSlugs: [String] = []
        if input.includeWarmup {
            warmupSlugs = try generateWarmup(context: context, rng: &rng).map(\.slug)
        }

        // 4. クールダウン(メインで使った筋群と入力筋群を優先対象に)
        var cooldownSlugs: [String] = []
        if input.includeCooldown {
            let coolMuscles = mainMuscles.union(input.muscles)
            cooldownSlugs = try generateCooldown(
                forMuscles: coolMuscles,
                context: context,
                rng: &rng
            ).map(\.slug)
        }

        // 5. 全パート空 → 種目データ自体が無いか条件が厳しすぎる
        if mainSlugs.isEmpty, warmupSlugs.isEmpty, cooldownSlugs.isEmpty {
            Logger.generator.warning("generator produced empty output for input")
            throw AppError.generatorEmpty(input.summary)
        }

        return GeneratorOutput(warmup: warmupSlugs, main: mainSlugs, cooldown: cooldownSlugs)
    }

    // MARK: - Main

    private static func generateMain<R: RandomNumberGenerator>(
        input: GeneratorInput,
        target: Int,
        context: ModelContext,
        rng: inout R
    ) throws -> [Exercise] {

        // 種目タイプの絞り込み(cardio 目的のみ CARDIO)
        let allowedTypes: Set<String> = (input.goal == .cardio)
            ? [ExerciseType.cardio.rawValue]
            : [
                ExerciseType.strength.rawValue,
                ExerciseType.calisthenics.rawValue,
                ExerciseType.plyometrics.rawValue,
            ]

        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { allowedTypes.contains($0.typeRaw) }
        )
        let pool = try context.fetch(descriptor)

        // equipment + muscle で in-memory フィルタ
        let filtered = pool.filter {
            matchesEquipment($0, allowed: input.equipment) &&
            matchesMuscles($0, target: input.muscles)
        }

        // ロック種目を最優先で確定(slug でソートして再現性確保)
        let lockedSet = input.lockedExerciseSlugs
        let locked = filtered
            .filter { lockedSet.contains($0.slug) }
            .sorted { $0.slug < $1.slug }
        let nonLocked = filtered.filter { !lockedSet.contains($0.slug) }

        // compound / isolation を比率で配分
        let remaining = max(0, target - locked.count)
        let compoundCount = Int((Double(remaining) * input.goal.compoundRatio).rounded())
        let isolationCount = remaining - compoundCount

        var compoundPool = nonLocked
            .filter { $0.mechanicsType == .compound }
            .sorted { $0.slug < $1.slug }
            .shuffled(using: &rng)
        var isolationPool = nonLocked
            .filter { $0.mechanicsType != .compound }
            .sorted { $0.slug < $1.slug }
            .shuffled(using: &rng)

        let takeC = min(compoundCount, compoundPool.count)
        let takeI = min(isolationCount, isolationPool.count)

        var picked: [Exercise] = locked
        picked.append(contentsOf: compoundPool.prefix(takeC))
        picked.append(contentsOf: isolationPool.prefix(takeI))
        compoundPool.removeFirst(takeC)
        isolationPool.removeFirst(takeI)

        // 一方が枯渇した場合は他方から補充
        let deficit = remaining - takeC - takeI
        if deficit > 0 {
            let extras = (compoundPool + isolationPool).prefix(deficit)
            picked.append(contentsOf: extras)
        }

        // 同部位連続を避ける(ロック分は前置のまま、その後ろを並べ替え)
        let lockedHead = Array(picked.prefix(locked.count))
        let tail = Array(picked.suffix(from: locked.count))
        let tailInterleaved = interleaveByMuscle(tail, startingAfter: lockedHead.last?.primaryMuscle)
        return lockedHead + tailInterleaved
    }

    // MARK: - Warmup

    private static func generateWarmup<R: RandomNumberGenerator>(
        context: ModelContext,
        rng: inout R
    ) throws -> [Exercise] {
        let warmupRaw = ExerciseType.warmup.rawValue
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.typeRaw == warmupRaw }
        )
        let pool = try context.fetch(descriptor).sorted { $0.slug < $1.slug }
        guard !pool.isEmpty else { return [] }

        let count = randomCount(in: auxCountRange, available: pool.count, rng: &rng)
        return Array(pool.shuffled(using: &rng).prefix(count))
    }

    // MARK: - Cooldown

    private static func generateCooldown<R: RandomNumberGenerator>(
        forMuscles muscles: Set<Muscle>,
        context: ModelContext,
        rng: inout R
    ) throws -> [Exercise] {
        let stretchingRaw = ExerciseType.stretching.rawValue
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.typeRaw == stretchingRaw }
        )
        let pool = try context.fetch(descriptor)
        guard !pool.isEmpty else { return [] }

        // メインで使った筋群を含むものを優先
        let matched = pool
            .filter { matchesMuscles($0, target: muscles) }
            .sorted { $0.slug < $1.slug }
            .shuffled(using: &rng)
        let unmatched = pool
            .filter { !matchesMuscles($0, target: muscles) }
            .sorted { $0.slug < $1.slug }
            .shuffled(using: &rng)
        let prioritized = matched + unmatched

        let count = randomCount(in: auxCountRange, available: prioritized.count, rng: &rng)
        return Array(prioritized.prefix(count))
    }
}

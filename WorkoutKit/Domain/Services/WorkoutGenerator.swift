// MARK: - WorkoutGenerator
// CLAUDE.md §4.3 準拠の自動生成ロジック。
// Phase P1 で本実装する。本ファイルは API 形と擬似コード方針を確定するスケルトン。
//
// 規約:
// - non-isolated(MainActor 外、Repository/Importer と同じ)
// - 例外は throws、UI 側で AppError に正規化
// - 種目0件の場合は AppError.generatorEmpty を投げる

import Foundation
import SwiftData
import OSLog

// MARK: - Input / Output

struct GeneratorInput: Sendable, Equatable {
    var goal: Goal
    var muscles: Set<Muscle>
    var equipment: Set<Equipment>
    var minutesAvailable: Int        // 30 / 45 / 60 / 90
    var includeWarmup: Bool
    var includeCooldown: Bool
    /// Choose モード(F-01a)で固定する種目の slug。
    var lockedExerciseSlugs: Set<String> = []
    /// Shuffle 結果を再現可能にしたい場合の seed(テスト/デバッグ用)。
    var randomSeed: UInt64? = nil
}

extension GeneratorInput {
    /// AppError.generatorEmpty に詰める表示用サマリ。
    var summary: GeneratorInputSummary {
        GeneratorInputSummary(
            goalRaw: goal.rawValue,
            muscleCount: muscles.count,
            equipmentCount: equipment.count,
            minutesAvailable: minutesAvailable
        )
    }
}

struct GeneratorOutput: Sendable, Equatable {
    var warmup: [String]    // Exercise.slug の並び
    var main: [String]
    var cooldown: [String]
}

// MARK: - Generator

enum WorkoutGenerator {
    /// 入力条件に対して warmup / main / cooldown 各パートの種目並びを返す。
    /// 実装は Phase P1。今は API シグネチャのみ確定。
    ///
    /// 擬似コード(CLAUDE.md §4.3 を再掲):
    /// 1. lockedExerciseSlugs を最優先で main に確定
    /// 2. equipment / primaryMuscle / secondaryMuscle で SwiftData Predicate フィルタ
    /// 3. main: muscle ごとに 1〜2 種目を均等配分、compound/isolation 比率は goal.compoundRatio
    /// 4. minutesAvailable から warmup 5 / cooldown 5 を引いた残りで main の本数を決定
    /// 5. 同じ部位連続を避ける(臀部→脚→胸 のように分散)
    /// 6. includeWarmup なら TYPE=WARMUP から 3〜5 種目
    /// 7. includeCooldown なら TYPE=STRETCHING からメインで使った筋群対応で 3〜5 種目
    static func generate(_ input: GeneratorInput, in context: ModelContext) throws -> GeneratorOutput {
        Logger.generator.debug("generate called: goal=\(input.goal.rawValue, privacy: .public), muscles=\(input.muscles.count), equipment=\(input.equipment.count), minutes=\(input.minutesAvailable)")
        // TODO(P1): 本実装。
        throw AppError.generatorEmpty(input.summary)
    }
}

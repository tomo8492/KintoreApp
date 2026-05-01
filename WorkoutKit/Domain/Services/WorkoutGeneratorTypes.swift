// MARK: - WorkoutGenerator I/O 型
// CLAUDE.md §4.3 準拠。WorkoutGenerator の入出力 DTO を本ファイルに分離。

import Foundation

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

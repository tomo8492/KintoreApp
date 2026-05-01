// MARK: - OneRepMaxCalculator
// 1RM 推定(F-04 履歴・進捗)。CLAUDE.md §1.1 / §9.1 規約。
// Epley 公式: 1RM = w × (1 + r/30)
// 1レップ実施(reps == 1)の場合は w をそのまま返す(公式が破綻しないよう)。

import Foundation

enum OneRepMaxCalculator {
    /// Epley 公式で推定 1RM(kg)を返す。
    /// reps が 0 や負数のときは 0、1 のときは weightKg をそのまま返す。
    static func estimate(weightKg: Double, reps: Int) -> Double {
        guard reps > 0, weightKg > 0 else { return 0 }
        if reps == 1 { return weightKg }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }
}

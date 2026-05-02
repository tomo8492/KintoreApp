// MARK: - SeededGenerator
// 再現性のある乱数生成器(SplitMix64 アルゴリズム)。
// CLAUDE.md §11.4 規約: WorkoutGenerator は randomSeed が指定された場合に
// SystemRandomNumberGenerator の代わりにこれを使う。テストの安定実行に必須。

import Foundation

/// SplitMix64 ベースの決定的疑似乱数生成器。
/// Seed が同じなら next() の系列も同じ。テストでのみ使う前提。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // seed 0 だと SplitMix64 の初回出力が偏るので、適当な定数で置換。
        self.state = (seed == 0) ? 0xDEADBEEFCAFEBABE : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - OneRepMaxCalculatorTests
// CLAUDE.md §9.1 準拠。Swift Testing で Epley 公式の境界値を凍結する。
// 1RM = w × (1 + r/30)

import Testing
@testable import WorkoutKit

@Suite("OneRepMaxCalculator")
struct OneRepMaxCalculatorTests {

    @Test("reps=1 のときは weight をそのまま返す(公式の境界)")
    func returnsWeightWhenReps1() {
        let actual = OneRepMaxCalculator.estimate(weightKg: 100, reps: 1)
        #expect(actual == 100)
    }

    @Test("reps=10 で Epley 公式どおりに計算される")
    func epleyAtReps10() {
        // 100 × (1 + 10/30) = 100 × 1.333... = 133.33...
        let actual = OneRepMaxCalculator.estimate(weightKg: 100, reps: 10)
        #expect(abs(actual - 133.3333333) < 0.001)
    }

    @Test("reps=5 で Epley 公式どおりに計算される")
    func epleyAtReps5() {
        // 80 × (1 + 5/30) = 80 × 1.16666... = 93.33...
        let actual = OneRepMaxCalculator.estimate(weightKg: 80, reps: 5)
        #expect(abs(actual - 93.3333333) < 0.001)
    }

    @Test("reps が 0 や負数なら 0 を返す")
    func zeroOnInvalidReps() {
        #expect(OneRepMaxCalculator.estimate(weightKg: 100, reps: 0) == 0)
        #expect(OneRepMaxCalculator.estimate(weightKg: 100, reps: -3) == 0)
    }

    @Test("weight が 0 や負数なら 0 を返す")
    func zeroOnInvalidWeight() {
        #expect(OneRepMaxCalculator.estimate(weightKg: 0, reps: 5) == 0)
        #expect(OneRepMaxCalculator.estimate(weightKg: -10, reps: 5) == 0)
    }

    @Test("浮動小数の精度: reps=12 で算出値が安定する")
    func stableAtReps12() {
        // 60 × (1 + 12/30) = 60 × 1.4 = 84.0
        let actual = OneRepMaxCalculator.estimate(weightKg: 60, reps: 12)
        #expect(abs(actual - 84.0) < 0.001)
    }
}

// MARK: - ExerciseStepsMistakesTests
// CLAUDE.md §1.1 F-02 / §11.4 準拠。
// Exercise モデルに新設した commonMistakesJa/En の改行分割と、
// stepTextJaRaw/EnRaw の JSON 配列復号が、ExerciseDetailView から
// 期待通りに動作することを Swift Testing で凍結する。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("Exercise steps + common mistakes")
struct ExerciseStepsMistakesTests {

    private static func makeExercise(
        stepsJaRaw: String = "[]",
        stepsEnRaw: String = "[]",
        mistakesJa: String = "",
        mistakesEn: String = ""
    ) -> Exercise {
        Exercise(
            slug: "demo-slug",
            slugJa: "デモ",
            nameJa: "デモ種目",
            nameEn: "Demo Exercise",
            typeRaw: "STRENGTH",
            primaryMuscleRaw: "chest",
            stepTextJaRaw: stepsJaRaw,
            stepTextEnRaw: stepsEnRaw,
            commonMistakesJa: mistakesJa,
            commonMistakesEn: mistakesEn
        )
    }

    @Test("stepsJa は stepTextJaRaw を JSON 配列として復号する")
    func stepsJaDecode() {
        let ex = Self.makeExercise(
            stepsJaRaw: #"["立つ","下げる","上げる"]"#
        )
        #expect(ex.stepsJa == ["立つ", "下げる", "上げる"])
    }

    @Test("stepsEn は壊れた JSON でも空配列にフォールバックする")
    func stepsEnFallback() {
        let ex = Self.makeExercise(stepsEnRaw: "not-json")
        #expect(ex.stepsEn.isEmpty)
    }

    @Test("commonMistakesJaList は改行で分割され、空行は除外される")
    func mistakesJaSplit() {
        let ex = Self.makeExercise(mistakesJa: "膝が内側に入る\n\n踵が浮く\n  背中が丸まる  ")
        #expect(ex.commonMistakesJaList == ["膝が内側に入る", "踵が浮く", "背中が丸まる"])
    }

    @Test("commonMistakesJa が空文字なら空配列を返す")
    func mistakesJaEmpty() {
        let ex = Self.makeExercise(mistakesJa: "")
        #expect(ex.commonMistakesJaList.isEmpty)
    }

    @Test("commonMistakesEn も同様に分割される")
    func mistakesEnSplit() {
        let ex = Self.makeExercise(mistakesEn: "Knees cave\nHeels lift\nBack rounds")
        #expect(ex.commonMistakesEnList == ["Knees cave", "Heels lift", "Back rounds"])
    }
}

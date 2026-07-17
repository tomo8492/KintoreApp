// MARK: - WorkoutInsightGeneratorTests
// CLAUDE.md v0.5 §-1.17 準拠。
// WorkoutInsightGenerator まわりの「LLM を呼ばずに検証できる」部分だけを凍結する。
//
// `WorkoutInsightGenerator.generate(_:)` は iOS 26 + Foundation Models が利用可能な
// 環境では実際にオンデバイス LLM(LanguageModelSession)を呼び出す実装になっており、
// CI(macos-26 ランナー / iOS 26.4 シミュレータ、.github/workflows/test.yml 参照)は
// `#available(iOS 26, *)` が真になる環境のため、この関数を呼ぶと
// シミュレータ上で Apple Intelligence の可用性が不定(モデル未ダウンロード等で
// ハング/クラッシュし得る)。そのため本ファイルでは `generate(_:)` 自体は
// 呼び出さず、LLM 呼び出しを経由しない純粋なデータ構造(WorkoutInsightInput /
// ExerciseLine / WorkoutInsightSnapshot.fallback)のみをテストする。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("WorkoutInsightGenerator")
struct WorkoutInsightGeneratorTests {

    // MARK: - ExerciseLine memberwise init(slug 有無)

    @Test("ExerciseLine は slug を省略した memberwise init が可能(既定値は空文字)")
    func exerciseLineDefaultSlug() {
        let line = WorkoutInsightInput.ExerciseLine(
            name: "ベンチプレス",
            setCount: 3,
            totalVolumeKg: 240
        )
        #expect(line.name == "ベンチプレス")
        #expect(line.slug == "")
        #expect(line.setCount == 3)
        #expect(line.totalVolumeKg == 240)
    }

    @Test("ExerciseLine は slug を明示指定できる")
    func exerciseLineExplicitSlug() {
        let line = WorkoutInsightInput.ExerciseLine(
            name: "ベンチプレス",
            slug: "barbell-bench-press",
            setCount: 3,
            totalVolumeKg: 240
        )
        #expect(line.name == "ベンチプレス")
        #expect(line.slug == "barbell-bench-press")
        #expect(line.setCount == 3)
        #expect(line.totalVolumeKg == 240)
    }

    @Test("ExerciseLine は Equatable: 同じ値なら等しい、slug が違えば異なる")
    func exerciseLineEquality() {
        let a = WorkoutInsightInput.ExerciseLine(name: "スクワット", slug: "barbell-back-squat", setCount: 5, totalVolumeKg: 500)
        let b = WorkoutInsightInput.ExerciseLine(name: "スクワット", slug: "barbell-back-squat", setCount: 5, totalVolumeKg: 500)
        let c = WorkoutInsightInput.ExerciseLine(name: "スクワット", setCount: 5, totalVolumeKg: 500) // slug 既定値 ""
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - WorkoutInsightInput 構築(WorkoutSession/SwiftData 非依存)

    @Test("WorkoutInsightInput は素の memberwise init で構築できる")
    func inputMemberwiseInit() {
        let lines = [
            WorkoutInsightInput.ExerciseLine(name: "ベンチプレス", slug: "barbell-bench-press", setCount: 3, totalVolumeKg: 240),
            WorkoutInsightInput.ExerciseLine(name: "スクワット", slug: "barbell-back-squat", setCount: 4, totalVolumeKg: 480)
        ]
        let input = WorkoutInsightInput(
            todayExercises: lines,
            volumeDeltaKgVsLastTime: 12.5,
            goalRaw: "hypertrophy"
        )
        #expect(input.todayExercises.count == 2)
        #expect(input.todayExercises.map(\.name) == ["ベンチプレス", "スクワット"])
        #expect(input.volumeDeltaKgVsLastTime == 12.5)
        #expect(input.goalRaw == "hypertrophy")
    }

    @Test("WorkoutInsightInput は volumeDeltaKgVsLastTime を nil のまま保持できる(前回データなし)")
    func inputWithoutPreviousVolume() {
        let input = WorkoutInsightInput(
            todayExercises: [],
            volumeDeltaKgVsLastTime: nil,
            goalRaw: "strength"
        )
        #expect(input.todayExercises.isEmpty)
        #expect(input.volumeDeltaKgVsLastTime == nil)
    }

    // MARK: - WorkoutInsightSnapshot.fallback (LLM 非経由の静的フォールバック値)

    @Test("WorkoutInsightSnapshot.fallback は 3 フィールドとも空文字にならない")
    func fallbackSnapshotIsWellFormed() {
        let fallback = WorkoutInsightSnapshot.fallback
        #expect(fallback.summary.isEmpty == false)
        #expect(fallback.highlight.isEmpty == false)
        #expect(fallback.advice.isEmpty == false)
    }
}

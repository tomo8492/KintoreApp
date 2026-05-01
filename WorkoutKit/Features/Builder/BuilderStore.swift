// MARK: - BuilderStore
// CLAUDE.md §1.1 F-01 / §11 準拠。Builder ウィザードの状態機械。
// - @Observable @MainActor。ViewModel ではなく Store(View が直接保持)。
// - Singleton 禁止規約に抵触しないよう、View 側で @State として所有する。
// - Generator 実行時のみ ModelContext を View から受け取る(Store は ctx を保持しない)。

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class BuilderStore {

    // MARK: - Step

    /// ウィザードの 5 ステップ。順序を変えると遷移ロジックが壊れるので
    /// CaseIterable の順序は変更不可。
    enum Step: Int, CaseIterable, Identifiable {
        case goal
        case muscle
        case equipment
        case time
        case result

        var id: Int { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .goal:      return "builder.step.goal.title"
            case .muscle:    return "builder.step.muscle.title"
            case .equipment: return "builder.step.equipment.title"
            case .time:      return "builder.step.time.title"
            case .result:    return "builder.step.result.title"
            }
        }
    }

    // MARK: - State

    var currentStep: Step = .goal
    var input: GeneratorInput
    var output: GeneratorOutput?
    /// Generator 失敗時の表示用。AppError の中身は LocalizedError 経由で文字列化。
    var generationError: String?
    /// Generator 実行中スピナー用。
    private(set) var isGenerating: Bool = false

    // MARK: - Init

    init(input: GeneratorInput = .defaultInput) {
        self.input = input
    }

    // MARK: - Navigation

    /// 現在ステップから次に進めるかどうか。
    /// View はこの値で「次へ」ボタンの disabled を制御する。
    var canAdvance: Bool {
        switch currentStep {
        case .goal:
            return true
        case .muscle:
            // flexibility / cardio は muscle 任意(全身扱い)。それ以外は1つ以上。
            if input.goal == .flexibility || input.goal == .cardio { return true }
            return !input.muscles.isEmpty
        case .equipment:
            return !input.equipment.isEmpty
        case .time:
            return input.minutesAvailable > 0
        case .result:
            return false
        }
    }

    /// 「戻る」ボタンを表示すべきか。
    var canGoBack: Bool {
        currentStep != .goal
    }

    /// 次のステップへ進む。Generator 実行は伴わない(time → result の遷移のみ
    /// `confirm(in:)` が担う)。
    func next() {
        guard canAdvance else { return }
        if currentStep == .time { return }   // result への遷移は confirm() のみ
        guard let nextStep = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextStep
    }

    /// 前のステップへ戻る。result から戻るときは output を破棄して再選択可能に。
    func back() {
        guard let prevStep = Step(rawValue: currentStep.rawValue - 1) else { return }
        if currentStep == .result {
            output = nil
            generationError = nil
        }
        currentStep = prevStep
    }

    // MARK: - Generation

    /// time → result 遷移時に呼ぶ。Generator を回して output を埋め、result へ進む。
    /// 失敗時は currentStep は変えず、generationError をセットする。
    func confirm(in context: ModelContext) {
        runGenerate(in: context, advanceOnSuccess: true)
    }

    /// result ステップで再生成するためのフック(B3 Shuffle/Choose で使う)。
    /// 入力は変えずに再シャッフルする想定。
    func regenerate(in context: ModelContext) {
        runGenerate(in: context, advanceOnSuccess: false)
    }

    private func runGenerate(in context: ModelContext, advanceOnSuccess: Bool) {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let result = try WorkoutGenerator.generate(input, in: context)
            output = result
            generationError = nil
            if advanceOnSuccess {
                currentStep = .result
            }
        } catch let error as LocalizedError {
            output = nil
            generationError = error.errorDescription ?? String(describing: error)
        } catch {
            output = nil
            generationError = error.localizedDescription
        }
    }
}

// MARK: - Defaults

extension GeneratorInput {
    /// Builder 起動時の初期値。CLAUDE.md §1.1 F-01 の既定:
    /// - 目的: 増量(最も多いユースケース)
    /// - 部位: 未選択(ユーザーに必ず選ばせる)
    /// - 器具: 未選択
    /// - 時間: 45 分(中庸)
    /// - warmup/cooldown: ON
    static var defaultInput: GeneratorInput {
        GeneratorInput(
            goal: .hypertrophy,
            muscles: [],
            equipment: [],
            minutesAvailable: 45,
            includeWarmup: true,
            includeCooldown: true
        )
    }
}

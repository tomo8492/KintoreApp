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

    // MARK: - Mode (B3)

    /// 結果ステップの表示モード。Shuffle = 自動再生成、Choose = ロック付き候補選択。
    /// CLAUDE.md §1.1 F-01a / workout-cool Issue #93 相当。
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case shuffle
        case choose

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .shuffle: return "builder.result.mode.shuffle"
            case .choose:  return "builder.result.mode.choose"
            }
        }
    }

    // MARK: - Session start payload

    /// Result ステップで「このメニューで始める」を押したときに、
    /// BuilderView 側の fullScreenCover/navigationDestination が観測する値。
    /// nil → 未開始 / 非 nil → SessionView を提示。
    /// fullScreenCover(item:) は Identifiable を要求する。
    struct SessionStartPayload: Identifiable, Equatable {
        let id: UUID = UUID()
        let output: GeneratorOutput
        let goal: Goal
        let includesWarmup: Bool
        let includesCooldown: Bool
    }

    // MARK: - State

    var currentStep: Step = .goal
    var input: GeneratorInput
    var output: GeneratorOutput?
    /// 結果ステップの表示モード。デフォルトは Shuffle。
    var mode: Mode = .shuffle
    /// Generator 失敗時の表示用。AppError の中身は LocalizedError 経由で文字列化。
    var generationError: String?
    /// Generator 実行中スピナー用。
    private(set) var isGenerating: Bool = false
    /// Result ステップから SessionView へ橋渡しするためのペイロード。
    /// BuilderView の fullScreenCover(item:) がこの値の遷移を見て SessionView を出す。
    var sessionStart: SessionStartPayload?

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
    /// 入力は変えずに再シャッフルする想定。lockedExerciseSlugs はそのまま尊重される。
    func regenerate(in context: ModelContext) {
        runGenerate(in: context, advanceOnSuccess: false)
    }

    // MARK: - Lock (B3 Choose mode)

    /// Choose モードで選択中のロック種目 slug。
    /// Generator 入力に直接保持される(GeneratorInput.lockedExerciseSlugs)。
    var lockedSlugs: Set<String> { input.lockedExerciseSlugs }

    /// 指定 slug のロック状態を反転する。Choose モードの行タップで呼ばれる。
    func toggleLock(_ slug: String) {
        if input.lockedExerciseSlugs.contains(slug) {
            input.lockedExerciseSlugs.remove(slug)
        } else {
            input.lockedExerciseSlugs.insert(slug)
        }
    }

    /// ロックを全解除する。result ステップから戻る/再開時に使用。
    func clearLocks() {
        input.lockedExerciseSlugs.removeAll()
    }

    // MARK: - Session start

    /// 「このメニューで始める」が押されたら、BuilderView 側の fullScreenCover を
    /// 起動するためのペイロードを組み立てる。output が無いときは no-op(本来は
    /// Result ステップ到達時点で必ず非 nil なので例外)。
    func startSession() {
        guard let output else { return }
        sessionStart = SessionStartPayload(
            output: output,
            goal: input.goal,
            includesWarmup: input.includeWarmup,
            includesCooldown: input.includeCooldown
        )
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

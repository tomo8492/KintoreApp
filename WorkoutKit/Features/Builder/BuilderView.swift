// MARK: - BuilderView
// CLAUDE.md §1.1 F-01 / §-1.15 / §11 準拠。
// Builder ウィザードのコンテナ。
// - iPhone(compact): NavigationStack(全画面遷移)
// - iPad(regular):   NavigationSplitView(サイドバーにステップ、Detail に各 Step)
// - View には @State で BuilderStore を直接保持(ViewModel 禁止規約)
// - Generator 実行時のみ ModelContext を Store の confirm() に渡す

import SwiftUI
import SwiftData
import OSLog

struct BuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var store = BuilderStore()
    @State private var sessionPayload: SessionStartPayload?

    var body: some View {
        if sizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        NavigationStack {
            stepContent
                .navigationTitle(store.currentStep.titleKey)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarItems }
                .safeAreaInset(edge: .bottom) {
                    if store.currentStep != .result {
                        bottomBar
                    }
                }
                .alert(
                    "builder.error.generation.title",
                    isPresented: errorPresented,
                    actions: { Button("common.ok", role: .cancel) {} },
                    message: { Text(store.generationError ?? "") }
                )
                .navigationDestination(item: $sessionPayload) { payload in
                    SessionView(
                        initialOutput: payload.output,
                        goal: payload.goal,
                        includesWarmup: payload.includesWarmup,
                        includesCooldown: payload.includesCooldown
                    )
                }
        }
    }

    // MARK: - iPad

    private var iPadLayout: some View {
        NavigationSplitView {
            // サイドバー: ステップ一覧。タップでジャンプはせず、進捗表示のみ。
            List(BuilderStore.Step.allCases) { step in
                StepIndicatorRow(
                    step: step,
                    currentStep: store.currentStep
                )
            }
            .navigationTitle("builder.title")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                stepContent
                    .navigationTitle(store.currentStep.titleKey)
                    .toolbar { toolbarItems }
                    .safeAreaInset(edge: .bottom) {
                        if store.currentStep != .result {
                            bottomBar
                        }
                    }
                    .alert(
                        "builder.error.generation.title",
                        isPresented: errorPresented,
                        actions: { Button("common.ok", role: .cancel) {} },
                        message: { Text(store.generationError ?? "") }
                    )
                    .navigationDestination(item: $sessionPayload) { payload in
                        SessionView(
                            initialOutput: payload.output,
                            goal: payload.goal,
                            includesWarmup: payload.includesWarmup,
                            includesCooldown: payload.includesCooldown
                        )
                    }
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch store.currentStep {
        case .goal:      GoalStepView(store: store)
        case .muscle:    MuscleStepView(store: store)
        case .equipment: EquipmentStepView(store: store)
        case .time:      TimeStepView(store: store)
        case .result:
            if let output = store.output {
                ResultStepView(
                    output: output,
                    isGenerating: store.isGenerating,
                    onRegenerate: { store.regenerate(in: modelContext) },
                    onStartSession: { startSession() }
                )
            } else {
                // 通常 confirm() 成功時のみ result に到達するので来ない想定だが、
                // データ破損や戻る/進む競合の保険として placeholder を出す。
                ContentUnavailableView(
                    "builder.error.no-output.title",
                    systemImage: "exclamationmark.triangle",
                    description: Text("builder.error.no-output.description")
                )
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if store.canGoBack {
            ToolbarItem(placement: .topBarLeading) {
                Button("common.back") { store.back() }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("common.cancel") { dismiss() }
        }
    }

    // MARK: - Bottom bar (next/generate)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: handlePrimaryAction) {
                HStack {
                    if store.isGenerating {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text(primaryButtonTitleKey)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(store.canAdvance ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!store.canAdvance || store.isGenerating)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    private var primaryButtonTitleKey: LocalizedStringKey {
        store.currentStep == .time ? "builder.action.generate" : "builder.action.next"
    }

    private func handlePrimaryAction() {
        if store.currentStep == .time {
            store.confirm(in: modelContext)
        } else {
            store.next()
        }
    }

    // MARK: - Error binding

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { store.generationError != nil },
            set: { newValue in
                if !newValue { store.generationError = nil }
            }
        )
    }

    // MARK: - Session start

    private func startSession() {
        // SessionView へ navigationDestination で push する(C1)。
        guard let output = store.output else {
            Logger.app.error("BuilderView.startSession: store.output is nil")
            return
        }
        Logger.app.info("BuilderView.startSession: warmup=\(output.warmup.count), main=\(output.main.count), cooldown=\(output.cooldown.count)")
        sessionPayload = SessionStartPayload(
            output: output,
            goal: store.input.goal,
            includesWarmup: store.input.includeWarmup,
            includesCooldown: store.input.includeCooldown
        )
    }
}

// MARK: - Session start payload
// BuilderView から SessionView に渡す navigationDestination(item:) 用の値型。
// GeneratorOutput は Hashable ではないので、Hashable は id 一意性で代用する。
struct SessionStartPayload: Hashable, Identifiable {
    let id: UUID = UUID()
    let output: GeneratorOutput
    let goal: Goal
    let includesWarmup: Bool
    let includesCooldown: Bool

    static func == (lhs: SessionStartPayload, rhs: SessionStartPayload) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Step indicator (iPad sidebar)

private struct StepIndicatorRow: View {
    let step: BuilderStore.Step
    let currentStep: BuilderStore.Step

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(color)
            Text(step.titleKey)
                .foregroundStyle(currentStep == step ? Color.primary : Color.secondary)
            Spacer()
        }
    }

    private var isCompleted: Bool {
        step.rawValue < currentStep.rawValue
    }

    private var iconName: String {
        if isCompleted { return "checkmark.circle.fill" }
        if step == currentStep { return "circle.fill" }
        return "circle"
    }

    private var color: Color {
        if isCompleted { return .accentColor }
        if step == currentStep { return .accentColor }
        return .secondary
    }
}

#Preview {
    BuilderView()
        .modelContainer(for: Exercise.self, inMemory: true)
}

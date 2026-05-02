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
            if store.output != nil {
                ResultStepView(store: store, onStartSession: { startSession() })
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
            .accessibilityLabel(Text(primaryButtonTitleKey))
            .accessibilityHint(Text(primaryButtonHintKey))
            .accessibilityAddTraits(.isButton)
        }
    }

    /// F3: VoiceOver で「次へ」「ワークアウトを生成」ボタンが何をするか説明する。
    private var primaryButtonHintKey: LocalizedStringKey {
        store.currentStep == .time
            ? "a11y.builder.generate.hint"
            : "a11y.builder.next.hint"
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
        // TODO(B4): SessionView へ遷移する。現状は Logger に出すだけのスタブ。
        // SessionView の API が決まったら NavigationDestination で push、
        // または fullScreenCover で起動する形に置き換える。
        Logger.app.info("BuilderView.startSession tapped: warmup=\(store.output?.warmup.count ?? 0), main=\(store.output?.main.count ?? 0), cooldown=\(store.output?.cooldown.count ?? 0)")
        dismiss()
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
                .accessibilityHidden(true)
            Text(step.titleKey)
                .foregroundStyle(currentStep == step ? Color.primary : Color.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(step.titleKey))
        .accessibilityValue(Text(stepStateKey))
    }

    /// F3: VoiceOver に「完了済み / 進行中 / 未着手」を伝える。
    private var stepStateKey: LocalizedStringKey {
        if isCompleted { return "a11y.builder.step.completed" }
        if step == currentStep { return "a11y.builder.step.current" }
        return "a11y.builder.step.upcoming"
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

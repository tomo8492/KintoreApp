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
#if canImport(UIKit)
import UIKit
#endif

struct BuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var store = BuilderStore()

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        // Result ステップで「このメニューで始める」が押されたら SessionView を
        // 全画面で被せる(C1 配線)。SessionView 終了時は onDismiss で BuilderView
        // ごと閉じて Today タブに戻す。
        .fullScreenCover(item: $store.sessionStart, onDismiss: handleSessionDismiss) { payload in
            NavigationStack {
                SessionView(
                    initialOutput: payload.output,
                    goal: payload.goal,
                    includesWarmup: payload.includesWarmup,
                    includesCooldown: payload.includesCooldown
                )
            }
        }
    }

    private func handleSessionDismiss() {
        // SessionView を閉じたら Builder も閉じて Today に戻す。
        // ユーザー視点では「ワークアウトをやり切った/中断した → 元の画面」が直感的。
        Logger.app.info("BuilderView: session dismissed, closing builder")
        dismiss()
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 2026 wizard UX: iPhone でも現在のステップが何/全何段中なのかを
                // 視覚化する。iPad のサイドバーと等価な情報を細い 1 段に圧縮。
                // Result ステップは「完了」フェーズなのでインジケータを出さない。
                if store.currentStep != .result {
                    BuilderStepProgressBar(currentStep: store.currentStep)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
                stepContent
            }
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
                Button("common.back") {
                    #if canImport(UIKit)
                    UISelectionFeedbackGenerator().selectionChanged()
                    #endif
                    store.back()
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("common.cancel") { dismiss() }
        }
    }

    // MARK: - Bottom bar (next/generate)
    //
    // 2026 wizard UX 改善:
    //   - 最終ステップ(Time → Generate)はボタン高さを増やし sparkles アイコン
    //     を付けて「完成・実行」感を強調(完了フェーズへの達成感)。
    //   - 「次へ」「戻る」「Generate」遷移で軽い触覚フィードバックを発火。
    //     ジムでもステップ移動が確実に伝わる。
    //   - 無効時は単純な gray ではなく opacity を下げて「タップ可能領域はある
    //     が条件未達」を視覚的に明示。

    private var bottomBar: some View {
        let isFinal = store.currentStep == .time
        return VStack(spacing: 0) {
            Divider()
            Button(action: handlePrimaryAction) {
                HStack(spacing: 8) {
                    if store.isGenerating {
                        ProgressView().controlSize(.small).tint(.white)
                    } else if isFinal {
                        Image(systemName: "sparkles")
                            .font(.headline)
                            .accessibilityHidden(true)
                    }
                    Text(primaryButtonTitleKey)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !isFinal && !store.isGenerating {
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: isFinal ? 28 : 24)
                .padding(.vertical, isFinal ? 16 : 14)
                .background(Color.accentColor.opacity(store.canAdvance ? 1.0 : 0.35))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!store.canAdvance || store.isGenerating)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .accessibilityIdentifier("builder.primary-action")
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
            // Generate は最終アクション。中程度の haptic で「実行された」感を与える。
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            store.confirm(in: modelContext)
        } else {
            #if canImport(UIKit)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
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

    /// Result ステップ「このメニューで始める」のハンドラ。
    /// store.startSession() が sessionStart payload をセット → 上の fullScreenCover が反応する。
    private func startSession() {
        let warmup = store.output?.warmup.count ?? 0
        let main = store.output?.main.count ?? 0
        let cooldown = store.output?.cooldown.count ?? 0
        Logger.app.info("BuilderView.startSession tapped: warmup=\(warmup), main=\(main), cooldown=\(cooldown)")
        store.startSession()
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

// MARK: - Step progress bar (iPhone)

/// iPhone 用のシンプルなステップ進捗バー。
/// Result を除く 4 ステップ(Goal / Muscle / Equipment / Time)を 4 セグメントで描画。
/// - 完了済み: accent 色で塗りつぶし
/// - 現在: accent 色 + 少し太く
/// - 未着手: secondary opacity .25
/// - アニメーション: `.spring` で次への遷移を柔らかく
/// CLAUDE.md §-1.6 / Reduce Motion 中は値補間アニメを抑制する。
private struct BuilderStepProgressBar: View {
    let currentStep: BuilderStore.Step

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Result を除いた進行可能ステップの順序。
    private static let progressSteps: [BuilderStore.Step] = [.goal, .muscle, .equipment, .time]

    var body: some View {
        let total = Self.progressSteps.count
        let currentIndex = Self.progressSteps.firstIndex(of: currentStep) ?? total
        return HStack(spacing: 6) {
            ForEach(Array(Self.progressSteps.enumerated()), id: \.offset) { idx, _ in
                Capsule()
                    .fill(fillStyle(forIndex: idx, currentIndex: currentIndex))
                    .frame(height: idx == currentIndex ? 6 : 4)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("a11y.builder.progress"))
        .accessibilityValue(Text("\(min(currentIndex + 1, total))/\(total)"))
    }

    private func fillStyle(forIndex idx: Int, currentIndex: Int) -> AnyShapeStyle {
        if idx < currentIndex {
            return AnyShapeStyle(Color.accentColor)
        }
        if idx == currentIndex {
            return AnyShapeStyle(Color.accentColor)
        }
        return AnyShapeStyle(Color.secondary.opacity(0.25))
    }
}

#Preview {
    BuilderView()
        .modelContainer(for: Exercise.self, inMemory: true)
}

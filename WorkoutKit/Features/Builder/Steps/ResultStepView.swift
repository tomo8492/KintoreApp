// MARK: - ResultStepView
// Builder Step 5: 生成結果。CLAUDE.md §1.1 F-01 / §1.1 F-01a。
//
// 設計メモ:
// - 右上に Shuffle / Choose のモード切替ピッカーを置く(B3)。
// - Shuffle モード: 出力プレビュー + ShuffleMode(再生成ボタン)。
// - Choose モード: ChooseMode(候補プールにロックを付ける)を表示。
// - 種目名は @Query で全 Exercise を引き、slug → 表示名のマップで解決(B3)。
//   同梱150種目想定なので全件 fetch でも軽量。

import SwiftUI
import SwiftData

struct ResultStepView: View {
    @Bindable var store: BuilderStore
    let onStartSession: () -> Void

    /// slug → Exercise 解決用。同梱規模(150種目)では全件取得が最も簡潔。
    @Query(sort: \Exercise.slug) private var allExercises: [Exercise]

    /// `allExercises` から派生する slug→Exercise マップ。
    /// computed property で書くと body 評価ごとに 150 件の Dictionary を作り直すため、
    /// `@State` にキャッシュして `.task(id: allExercises.count)` で更新する。
    @State private var nameMap: [String: Exercise] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modePicker

                summaryHeader

                switch store.mode {
                case .shuffle: shuffleContent
                case .choose:  chooseContent
                }

                actionButtons
            }
            .padding(.vertical)
            .padding(.horizontal)
        }
        .task(id: allExercises.count) {
            nameMap = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.slug, $0) })
        }
    }

    // MARK: - Mode picker (右上トグル)

    private var modePicker: some View {
        HStack {
            Spacer()
            Picker("builder.result.mode.label", selection: $store.mode) {
                ForEach(BuilderStore.Mode.allCases) { mode in
                    Text(mode.titleKey).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
    }

    // MARK: - Header

    private var output: GeneratorOutput {
        store.output ?? GeneratorOutput(warmup: [], main: [], cooldown: [])
    }

    private var totalCount: Int {
        output.warmup.count + output.main.count + output.cooldown.count
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("builder.step.result.heading")
                .font(.title2.bold())
            Text("builder.step.result.subheading \(totalCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Shuffle content

    @ViewBuilder
    private var shuffleContent: some View {
        if !output.warmup.isEmpty {
            section(titleKey: "builder.step.result.section.warmup", slugs: output.warmup)
        }
        section(titleKey: "builder.step.result.section.main", slugs: output.main)
        if !output.cooldown.isEmpty {
            section(titleKey: "builder.step.result.section.cooldown", slugs: output.cooldown)
        }
        ShuffleMode(store: store)
    }

    // MARK: - Choose content

    @ViewBuilder
    private var chooseContent: some View {
        // メインの確定中種目だけ簡略表示(warmup/cooldown は影響しない)
        if !output.main.isEmpty {
            section(titleKey: "builder.step.result.section.main", slugs: output.main)
        }
        ChooseMode(store: store)
    }

    // MARK: - Section

    private func section(titleKey: LocalizedStringKey, slugs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(slugs.enumerated()), id: \.offset) { index, slug in
                    let isLocked = store.lockedSlugs.contains(slug)
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(displayName(for: slug))
                            .font(.body)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("a11y.builder.result.row \(index + 1) \(displayName(for: slug))"))
                    .accessibilityValue(Text(isLocked ? "a11y.builder.result.locked" : "a11y.builder.result.unlocked"))

                    if index < slugs.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.08))
            )
        }
    }

    /// slug を Exercise.localizedName(nameJa / nameEn)に解決する。
    /// DB に未登録の slug は slug 自体を返す(seed 未投入時の保険)。
    private func displayName(for slug: String) -> String {
        nameMap[slug]?.localizedName ?? slug
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button(action: onStartSession) {
                Text("builder.step.result.action.start")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(store.isGenerating)
            .accessibilityLabel(Text("builder.step.result.action.start"))
            .accessibilityHint(Text("a11y.builder.result.start.hint"))
            .accessibilityAddTraits(.isButton)
        }
        .padding(.top, 8)
    }
}

#Preview {
    let previewStore = BuilderStore()
    previewStore.output = GeneratorOutput(
        warmup: ["jumping-jacks", "arm-circles", "leg-swings"],
        main: ["barbell-back-squat", "bench-press", "barbell-row"],
        cooldown: ["chest-stretch", "hamstring-stretch"]
    )
    return ResultStepView(store: previewStore, onStartSession: {})
        .modelContainer(for: Exercise.self, inMemory: true)
}

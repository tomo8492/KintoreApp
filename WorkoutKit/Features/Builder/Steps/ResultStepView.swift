// MARK: - ResultStepView
// Builder Step 5: 生成結果。CLAUDE.md §1.1 F-01。
//
// このビューは B3(Shuffle/Choose)で再生成 UI を上に増築する想定でシンプルに保つ。
// - Shuffle ボタンは onRegenerate フックを呼ぶだけ(Choose モードは B3 で追加)。
// - セッション開始は onStartSession フックを呼ぶ(SessionView 未実装、B4 で配線)。

import SwiftUI

struct ResultStepView: View {
    let output: GeneratorOutput
    let isGenerating: Bool
    let onRegenerate: () -> Void
    let onStartSession: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryHeader

                if !output.warmup.isEmpty {
                    section(titleKey: "builder.step.result.section.warmup", slugs: output.warmup)
                }

                section(titleKey: "builder.step.result.section.main", slugs: output.main)

                if !output.cooldown.isEmpty {
                    section(titleKey: "builder.step.result.section.cooldown", slugs: output.cooldown)
                }

                actionButtons
            }
            .padding(.vertical)
            .padding(.horizontal)
        }
    }

    // MARK: - Subviews

    private var totalCount: Int {
        output.warmup.count + output.main.count + output.cooldown.count
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("builder.step.result.heading")
                .font(.title2.bold())
            // SwiftUI が \(Int) を %lld の format 引数に正しく変換する。
            // xcstrings 側では "builder.step.result.subheading" キーで定義する。
            Text("builder.step.result.subheading \(totalCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func section(titleKey: LocalizedStringKey, slugs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(slugs.enumerated()), id: \.offset) { index, slug in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        // TODO(B3): Exercise を SwiftData から引いて nameJa/En を表示する。
                        // 現状は slug をそのまま表示しておく。
                        Text(slug)
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

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

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button(action: onStartSession) {
                Text("builder.step.result.action.start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)

            Button(action: onRegenerate) {
                HStack {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "shuffle")
                    }
                    Text("builder.step.result.action.shuffle")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.gray.opacity(0.12))
                .foregroundStyle(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)
        }
        .padding(.top, 8)
    }
}

#Preview {
    ResultStepView(
        output: GeneratorOutput(
            warmup: ["jumping-jacks", "arm-circles", "leg-swings"],
            main: ["barbell-back-squat", "bench-press", "barbell-row"],
            cooldown: ["chest-stretch", "hamstring-stretch"]
        ),
        isGenerating: false,
        onRegenerate: {},
        onStartSession: {}
    )
}

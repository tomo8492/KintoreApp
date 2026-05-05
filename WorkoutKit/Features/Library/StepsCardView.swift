// MARK: - StepsCardView
// CLAUDE.md §1.1 F-02。ExerciseDetailView の「手順」セクションを
// 番号付きカードのリストとして描画する表示専用 View。
//
// 設計指針(CLAUDE.md §-1.6 / NG リスト):
//   - 1 ステップ = 1 カード(番号バッジ + 短文)
//   - 文字列は seed json の Ja/En フィールドから直接渡す(xcstrings 経由不要、
//     ローカライズは ExerciseDetailView 側で言語選択済み)
//   - View には @State / @Observable のみ。本 View は完全 stateless

import SwiftUI

struct StepsCardView: View {
    /// 各ステップの本文(短文を想定、3〜5 個程度)。
    let steps: [String]

    var body: some View {
        if steps.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("library.detail.steps")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, line in
                        StepCard(number: index + 1, text: line)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("a11y.library.detail.steps.label"))
        }
    }
}

// MARK: - Single step card

private struct StepCard: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            stepBadge

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var stepBadge: some View {
        Text("\(number)")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color.accentColor, in: .circle)
    }
}

// MARK: - Preview

#Preview("Steps - squat") {
    ScrollView {
        StepsCardView(steps: [
            "立位で足を肩幅に開く",
            "腰を引きつつ膝と股関節を曲げて下げる",
            "太ももが床と平行になるまで沈む",
            "踵で床を押し返して立ち上がる"
        ])
        .padding()
    }
}

#Preview("Steps - empty") {
    StepsCardView(steps: [])
        .padding()
}

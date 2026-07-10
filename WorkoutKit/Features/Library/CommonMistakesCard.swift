// MARK: - CommonMistakesCard
// CLAUDE.md §1.1 F-02。ExerciseDetailView の「よくある間違い」セクション。
// cautions(注意点)カードと並列のデザインだが、より強い警告色(赤系)を使う。
//
// 設計指針(CLAUDE.md §-1.6 / NG リスト):
//   - ❌ アイコン + 「よくある間違い」見出し + 箇条書き
//   - 文字列は seed json の commonMistakesJa/En から直接渡す
//   - View には @State / @Observable のみ。本 View は完全 stateless

import SwiftUI

struct CommonMistakesCard: View {
    /// 1 行 1 ミステイクの短文配列(3 個程度)。
    let mistakes: [String]

    var body: some View {
        if mistakes.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("library.detail.common-mistakes")
                } icon: {
                    Image(systemName: "xmark.octagon.fill")
                }
                .font(.headline)
                .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(mistakes.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.red)
                                .frame(width: 16, alignment: .center)
                                .padding(.top, 4)

                            Text(line)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .fill(Color.red.opacity(0.10))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("a11y.library.detail.common-mistakes.label"))
        }
    }
}

// MARK: - Preview

#Preview("Common mistakes - squat") {
    ScrollView {
        CommonMistakesCard(mistakes: [
            "膝が内側に入る",
            "踵が浮く",
            "背中が丸まる"
        ])
        .padding()
    }
}

#Preview("Common mistakes - empty") {
    CommonMistakesCard(mistakes: [])
        .padding()
}

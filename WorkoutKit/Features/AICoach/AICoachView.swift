// MARK: - AICoachView
// CLAUDE.md v0.5 §-1.17 / §11 準拠。
//
// セッション完了画面の下部に「AI コーチのコメント」セクションを差し込む。
//
// 表示条件:
//   1. `#available(iOS 26, *)`(Foundation Models が利用可能)
//   2. もしくは debug プレビュー(`#if DEBUG` で fallback を見せる)
//
// iOS 25 以下では本 View は最終的に空ビューに畳まれるよう、呼び出し側で
// `if AICoachView.isSupported { AICoachView(...) }` のように事前判定する。
//
// 状態:
//   - 推論中: ProgressView
//   - 成功:   3 行のフィードバック
//   - 失敗:   WorkoutInsightSnapshot.fallback で常時表示(エラー文言は出さない)

import SwiftUI
import OSLog

@MainActor
struct AICoachView: View {

    let input: WorkoutInsightInput

    @State private var insight: WorkoutInsightSnapshot?
    @State private var isGenerating: Bool = false

    /// iOS 26 以降だけ true。AICoachView 自体を出すかどうかの判定。
    static var isSupported: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .task(id: input) {
            await regenerate()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("ai-coach.title")
                .font(.headline)
            Spacer()
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Text("ai-coach.generating"))
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let insight {
            VStack(alignment: .leading, spacing: 6) {
                Text(insight.summary)
                    .font(.body)
                Text(insight.highlight)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(insight.advice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if isGenerating {
            Text("ai-coach.generating")
                .font(.body)
                .foregroundStyle(.secondary)
        } else {
            // 念のためのフォールバック(通常 .task で必ず insight が埋まる)。
            Text("ai-coach.fallback.summary")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Generation

    private func regenerate() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        Logger.app.info("AICoachView.regenerate started")
        let result = await WorkoutInsightGenerator.generate(input)
        insight = result
    }
}

// MARK: - Preview

#if DEBUG
#Preview("AICoach / fallback") {
    AICoachView(
        input: .init(
            todayExercises: [
                .init(name: "ベンチプレス", setCount: 4, totalVolumeKg: 320),
                .init(name: "インクラインダンベルプレス", setCount: 3, totalVolumeKg: 180),
            ],
            volumeDeltaKgVsLastTime: 25,
            goalRaw: "hypertrophy"
        )
    )
    .padding()
}
#endif

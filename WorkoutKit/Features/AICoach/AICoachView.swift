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
        VStack(alignment: .leading, spacing: 14) {
            header
            content
        }
        .padding(16)
        .background(aiBackground)
        .task(id: input) {
            await regenerate()
        }
        .accessibilityElement(children: .contain)
    }

    /// 「AI が生成した内容」をユーザーに伝える微妙なグラデーション背景。
    /// Apple Intelligence の視覚言語(藤紫〜ピンク〜オレンジのグロー)に
    /// 倣いつつ、本アプリの accentColor を中心に置く。トーンは控えめにして
    /// 通常 UI の邪魔をしない。
    private var aiBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.10),
                        Color.purple.opacity(0.06),
                        Color.pink.opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
            )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // 生成中は sparkles を pulse させて「考えている」を視覚化。
            // 静止時は通常表示 → iOS 17+ の symbolEffect で表現する。
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating, isActive: isGenerating)
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
    //
    // 3 行の役割を視覚的に区別するため、各行にアイコンを付与:
    //   - summary  → text.alignleft        (全体要約)
    //   - highlight→ star.fill              (今日のハイライト種目)
    //   - advice   → arrow.forward.circle  (明日のアドバイス)
    // 役割が明確になり、AI の出力が「何の話か」を瞬時に把握できる。

    @ViewBuilder
    private var content: some View {
        if let insight {
            VStack(alignment: .leading, spacing: 10) {
                insightRow(icon: "text.alignleft", iconColor: .accentColor, text: insight.summary, font: .body.weight(.medium), textColor: .primary)
                insightRow(icon: "star.fill", iconColor: .yellow, text: insight.highlight, font: .subheadline, textColor: .secondary)
                insightRow(icon: "arrow.forward.circle.fill", iconColor: .accentColor, text: insight.advice, font: .subheadline, textColor: .secondary)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if isGenerating {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
                    .accessibilityHidden(true)
                Text("ai-coach.generating")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } else {
            // 念のためのフォールバック(通常 .task で必ず insight が埋まる)。
            Text("ai-coach.fallback.summary")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func insightRow(
        icon: String,
        iconColor: Color,
        text: String,
        font: Font,
        textColor: Color
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 14)
                .accessibilityHidden(true)
            Text(text)
                .font(font)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
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

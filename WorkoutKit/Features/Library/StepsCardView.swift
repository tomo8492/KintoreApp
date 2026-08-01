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
#if canImport(UIKit)
import UIKit
#endif

struct StepsCardView: View {
    /// 各ステップの本文(短文を想定、3〜5 個程度)。
    let steps: [String]

    /// フォームイラスト解決用(任意)。Phase 2-1 時点では呼び出し側
    /// (ExerciseDetailView)がまだ渡してこないため常に nil で、見た目は
    /// 従来と完全に同一になる。将来呼び出し側が exercise を渡すよう更新
    /// すれば、Assets.xcassets にアセットを追加するだけで画像が出る
    /// ("コンテンツを後から差し込むだけ" にするのが本タスクのゴール)。
    var exercise: Exercise? = nil

    // アセットカタログ照会(UIImage(named:))は軽くはないため、View の
    // 表示中は一度だけ実行してキャッシュする(再描画のたびに叩かない)。
    @State private var resolvedStepImages: [Int: String] = [:]
    @State private var hasResolvedStepImages = false

    var body: some View {
        if steps.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("library.detail.steps")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, line in
                        StepCard(
                            number: index + 1,
                            text: line,
                            imageName: resolvedStepImages[index + 1]
                        )
                    }
                }
            }
            // D5 修正: .accessibilityLabel を付けると .combine で連結された
            // 見出し+各ステップの本文が上書きされ、VoiceOver が
            // "a11y.library.detail.steps.label" だけを読み上げてしまう
            // (中身が読めなくなる)。ラベル指定を外し、.combine の自然な
            // 連結読み上げに任せる。
            .accessibilityElement(children: .combine)
            .onAppear(perform: resolveStepImagesIfNeeded)
        }
    }

    // MARK: - Image resolution
    //
    // 優先順位:
    //   1. exercise.stepImagesRaw(JSON 配列)で明示指定されたファイル名
    //   2. `<slug>-step-<n>` 命名規約(seed 未更新でもアセット追加だけで有効化)
    // どちらもアセットカタログに実体が無ければ UIImage(named:) が nil を返す
    // ため、未投入の種目(現状 345 種目すべて)では常に nil のまま = 表示は不変。

    private func resolveStepImagesIfNeeded() {
        guard !hasResolvedStepImages, let exercise, !steps.isEmpty else { return }
        hasResolvedStepImages = true

        let declared = LibraryDisplay.stepImageNames(for: exercise)
        var result: [Int: String] = [:]

        for number in 1...steps.count {
            if let name = Self.verifiedImageName(declared: declared, stepIndex: number - 1, slug: exercise.slug) {
                result[number] = name
            }
        }
        resolvedStepImages = result
    }

    private static func verifiedImageName(declared: [String], stepIndex: Int, slug: String) -> String? {
        if declared.indices.contains(stepIndex) {
            let candidate = stripKnownImageExtension(declared[stepIndex])
            if !candidate.isEmpty, assetExists(candidate) {
                return candidate
            }
        }

        let conventionCandidate = "\(slug)-step-\(stepIndex + 1)"
        return assetExists(conventionCandidate) ? conventionCandidate : nil
    }

    /// 例: "chest-press-1.png" → "chest-press-1"(imageset 名は拡張子を含まない)。
    private static func stripKnownImageExtension(_ raw: String) -> String {
        for ext in [".png", ".jpg", ".jpeg", ".heic"] where raw.hasSuffix(ext) {
            return String(raw.dropLast(ext.count))
        }
        return raw
    }

    private static func assetExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}

// MARK: - Single step card

private struct StepCard: View {
    let number: Int
    let text: String
    var imageName: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 180)
                    .background(AppColor.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    .accessibilityLabel(Text("a11y.library.detail.step-image \(number)"))
            }

            HStack(alignment: .top, spacing: 12) {
                stepBadge

                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var stepBadge: some View {
        Text("\(number)")
            .font(.system(.callout, design: .rounded).weight(.bold))
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

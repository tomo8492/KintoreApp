// MARK: - CompactBodyDiagramView
// ExerciseDetailView (F-02) で「この種目はこの筋肉を鍛える」を視覚的に示すための
// 表示専用・小型 人体図。Builder の `BodyDiagramView` (v2 解剖学版) と同じ
// SVG アセット (workout-cool 由来 / MIT) を流用しつつ、以下の点で差別化:
//
//   - タップ判定なし(VoiceOver からも単一の image として読まれる)
//   - 全身選択ボタンや Clear ボタンなし
//   - primary muscle  → opacity 1.0(オレンジ強)
//   - secondary muscle → opacity 0.5(オレンジ弱)
//
// CLAUDE.md NG リスト:
//   - 文字列は Localizable.xcstrings 経由(LocalizedStringKey)
//   - print/force unwrap/.shared なし
//   - View には @State / @Observable のみ(本 View は完全 stateless)

import SwiftUI

struct CompactBodyDiagramView: View {
    let primaryMuscles: Set<Muscle>
    let secondaryMuscles: Set<Muscle>

    private static let viewBoxAspect: CGFloat =
        BodyHitZones.viewBox.width / BodyHitZones.viewBox.height

    var body: some View {
        diagram
            .aspectRatio(Self.viewBoxAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isImage)
    }

    // MARK: - Diagram stack

    private var diagram: some View {
        ZStack {
            // 背景: 灰色シルエット(Builder と同じトーン)
            Image("Body/body-base")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(silhouetteColor)
                .scaledToFit()

            // 協働筋 → 先に薄く敷く(z-order 下)
            ForEach(orderedSecondary, id: \.self) { muscle in
                if let asset = highlightAssetName(for: muscle) {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.5)
                }
            }

            // 主動筋 → 上に重ねて強くハイライト(z-order 上)。
            // SVG に色が焼き込まれておりランタイムでは tint できないため、
            // premium グロー(shadow)はレイヤー全体に適用する。
            ForEach(orderedPrimary, id: \.self) { muscle in
                if let asset = highlightAssetName(for: muscle) {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .opacity(1.0)
                        .premiumMuscleGlow()
                }
            }
        }
    }

    // MARK: - Highlight selection

    /// 主動筋。fullBody なら全部の筋肉を高強度で表示する。
    private var orderedPrimary: [Muscle] {
        if primaryMuscles.contains(.fullBody) {
            return BodyHitZones.zones.keys.sorted(by: muscleOrder)
        }
        return primaryMuscles.sorted(by: muscleOrder)
    }

    /// 協働筋。主動筋に含まれる部位は重複描画しない(視覚的にチカチカするため)。
    private var orderedSecondary: [Muscle] {
        secondaryMuscles
            .subtracting(primaryMuscles)
            .filter { $0 != .fullBody }
            .sorted(by: muscleOrder)
    }

    private func muscleOrder(_ a: Muscle, _ b: Muscle) -> Bool {
        a.rawValue < b.rawValue
    }

    private func highlightAssetName(for muscle: Muscle) -> String? {
        guard muscle != .fullBody else { return nil }
        return "Body/body-\(muscle.rawValue)"
    }

    // MARK: - Style

    private var silhouetteColor: Color {
        Color.gray.opacity(0.45)
    }

    // MARK: - Accessibility

    /// VoiceOver 用に「主動筋: 胸/協働筋: 上腕三頭筋, 三角筋」のような
    /// 一文をローカライズ済み文字列で組み立てる。muscle 名は Builder の
    /// MuscleLocalization と同じキーを使う(英訳 + 日訳が既にある)。
    ///
    /// primaryMuscles が空(理論上は起きないはずだが安全のため)の場合のみ、
    /// 旧来の静的ラベルにフォールバックする。
    private var accessibilityLabel: Text {
        let primaryList = primaryMuscles.sorted(by: muscleOrder)
        guard !primaryList.isEmpty else {
            return Text("a11y.library.detail.target-muscles.label")
        }

        let primaryNames = primaryList.map(muscleDisplayName).joined(separator: "、")
        let primaryLabel = String(localized: "library.detail.primary-muscle")
        var composed = "\(primaryLabel): \(primaryNames)"

        if !orderedSecondary.isEmpty {
            let secondaryNames = orderedSecondary.map(muscleDisplayName).joined(separator: "、")
            let secondaryLabel = String(localized: "library.detail.secondary-muscles")
            composed += "。\(secondaryLabel): \(secondaryNames)"
        }

        return Text(composed)
    }

    /// muscle.<rawValue> は LibraryDisplay.muscleName が使っているキーと同じ
    /// (例: muscle.chest, muscle.lowerBack)。accessibilityLabel の組み立てには
    /// LocalizedStringKey ではなく String が必要なため、SessionView と同じ
    /// String.LocalizationValue 経由のランタイムキー解決を使う。
    private func muscleDisplayName(_ muscle: Muscle) -> String {
        String(localized: String.LocalizationValue("muscle.\(muscle.rawValue)"))
    }
}

#Preview("CompactBodyDiagram - push-up") {
    CompactBodyDiagramView(
        primaryMuscles: [.chest],
        secondaryMuscles: [.triceps, .deltoids, .abs]
    )
    .padding()
}

#Preview("CompactBodyDiagram - air-squat") {
    CompactBodyDiagramView(
        primaryMuscles: [.quadriceps],
        secondaryMuscles: [.glutes, .hamstrings]
    )
    .padding()
}

#Preview("CompactBodyDiagram - pull-up") {
    CompactBodyDiagramView(
        primaryMuscles: [.lats],
        secondaryMuscles: [.biceps, .traps]
    )
    .padding()
}

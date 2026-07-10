// MARK: - AnnotatedBodyDiagramView
// CLAUDE.md §1.1 F-02 強化版・2 行レイアウト。
//
// 仕様:
//   - 1 行目: 「前面」セクション(タイトル + 半身図 + 番号付きキューリスト)
//   - 2 行目: 「後面」セクション(同上)
//   - 各 section は BodySectionView に委譲する。本 View はキューを
//     position.x で振り分けるロジックだけを持つ。
//
// データの取り扱い:
//   - position.x < 0.5  → 前面セクション
//   - position.x >= 0.5 → 後面セクション
//   - 既存 BodyAnnotations/<slug>.json の `view` フィールドは参照しない
//     (template によっては中央付近を使うケースがあり、x で判定するほうが堅牢)
//
// CLAUDE.md NG リスト:
//   - 文字列は Localizable.xcstrings 経由(LocalizedStringKey)
//   - print/force unwrap/.shared なし
//   - View には @State / @Observable のみ(本 View は完全 stateless)

import SwiftUI

struct AnnotatedBodyDiagramView: View {
    let primaryMuscles: Set<Muscle>
    let secondaryMuscles: Set<Muscle>
    let annotation: ExerciseAnnotation?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BodySectionView(
                side: .front,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                cues: frontCues
            )
            BodySectionView(
                side: .back,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                cues: backCues
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Cue partitioning

    /// `side` フィールドが指定されていればそれを優先する。
    /// 旧フォーマット(side 無し)は position.x で推定(0.5 未満で front)。
    /// この二段ロジックがあれば、後付けで side を追加した既存 JSON も
    /// 古いダウンロード版と矛盾しない。
    private var frontCues: [AnnotationLabel] {
        annotation?.annotations.filter { isFront($0) } ?? []
    }

    private var backCues: [AnnotationLabel] {
        annotation?.annotations.filter { !isFront($0) } ?? []
    }

    private func isFront(_ cue: AnnotationLabel) -> Bool {
        if let side = cue.side {
            return side == .front
        }
        return cue.position.x < 0.5
    }

    // MARK: - Accessibility

    private var accessibilityLabel: Text {
        if annotation == nil {
            return Text("a11y.library.detail.target-muscles.label")
        }
        return Text("a11y.library.detail.annotated-diagram.label")
    }
}

// MARK: - Color resolution

extension AnnotationColor {
    /// セマンティック色 → SwiftUI Color。Light/Dark 両対応のため標準色を中心に。
    var fillColor: Color {
        switch self {
        case .primary:  return .accentColor
        case .info:     return .blue
        case .warning:  return .orange
        case .success:  return .green
        }
    }

    /// 引き出し線の色。テキストカードの輪郭にも使う。
    var strokeColor: Color {
        fillColor
    }
}

// MARK: - Previews

#Preview("Annotated - squat") {
    let knee = AnnotationLabel(
        id: "knee",
        position: AnnotationPoint(x: 0.20, y: 0.66),
        labelAnchor: AnnotationPoint(x: 0.04, y: 0.65),
        labelKey: "form.barbell-back-squat.annotation.knee",
        color: .info
    )
    let back = AnnotationLabel(
        id: "back",
        position: AnnotationPoint(x: 0.22, y: 0.21),
        labelAnchor: AnnotationPoint(x: 0.98, y: 0.10),
        labelKey: "form.barbell-back-squat.annotation.back",
        color: .success
    )
    let glute = AnnotationLabel(
        id: "squeeze",
        position: AnnotationPoint(x: 0.78, y: 0.46),
        labelAnchor: AnnotationPoint(x: 0.98, y: 0.45),
        labelKey: "form.barbell-back-squat.annotation.hip",
        color: .primary
    )
    let annotation = ExerciseAnnotation(
        slug: "barbell-back-squat",
        view: .front,
        arrows: [],
        annotations: [knee, back, glute]
    )
    return ScrollView {
        AnnotatedBodyDiagramView(
            primaryMuscles: [.quadriceps],
            secondaryMuscles: [.glutes, .hamstrings, .lowerBack],
            annotation: annotation
        )
        .padding()
    }
}

#Preview("Annotated - pull-up (back-only)") {
    let scap = AnnotationLabel(
        id: "scap",
        position: AnnotationPoint(x: 0.74, y: 0.13),
        labelAnchor: AnnotationPoint(x: 0.98, y: 0.10),
        labelKey: "form.pull-up.annotation.scap",
        color: .info
    )
    let lats = AnnotationLabel(
        id: "lats",
        position: AnnotationPoint(x: 0.79, y: 0.27),
        labelAnchor: AnnotationPoint(x: 0.04, y: 0.35),
        labelKey: "form.pull-up.annotation.lats",
        color: .primary
    )
    let annotation = ExerciseAnnotation(
        slug: "pull-up",
        view: .back,
        arrows: [],
        annotations: [scap, lats]
    )
    return ScrollView {
        AnnotatedBodyDiagramView(
            primaryMuscles: [.lats],
            secondaryMuscles: [.biceps, .traps],
            annotation: annotation
        )
        .padding()
    }
}

#Preview("Annotated - fallback (no annotation)") {
    AnnotatedBodyDiagramView(
        primaryMuscles: [.lats],
        secondaryMuscles: [.biceps, .traps],
        annotation: nil
    )
    .padding()
}

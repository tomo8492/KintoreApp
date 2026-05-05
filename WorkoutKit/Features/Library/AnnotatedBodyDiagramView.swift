// MARK: - AnnotatedBodyDiagramView
// CLAUDE.md §1.1 F-02 強化版。CompactBodyDiagramView の上に
// 「動作矢印 + 引き出し線付きアノテーション」をオーバーレイする
// 表示専用 View。SD 写真が用意されない種目でも、本 View 1 つで
// 動きと注意点が一目で分かるようにする。
//
// 入力:
//   - exercise: SwiftData の Exercise モデル(主筋/協働筋を取得)
//   - annotation: ExerciseAnnotation? (= nil なら筋肉ハイライトのみ)
//
// 描画レイヤ(背→前):
//   1. CompactBodyDiagramView(従来の人体図 + 筋肉ハイライト)
//   2. AnnotationArrowOverlay (Path)
//   3. AnnotationLabelOverlay (引き出し線 + テキストカード)
//
// CLAUDE.md NG リスト:
//   - print/force unwrap/.shared なし
//   - 文字列は Localizable.xcstrings 経由(LocalizedStringKey)
//   - View には @State / @Observable のみ(本 View は完全 stateless)

import SwiftUI

struct AnnotatedBodyDiagramView: View {
    let primaryMuscles: Set<Muscle>
    let secondaryMuscles: Set<Muscle>
    let annotation: ExerciseAnnotation?

    private static let viewBoxAspect: CGFloat =
        BodyHitZones.viewBox.width / BodyHitZones.viewBox.height

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CompactBodyDiagramView(
                    primaryMuscles: primaryMuscles,
                    secondaryMuscles: secondaryMuscles
                )

                if let annotation {
                    AnnotationArrowOverlay(
                        arrows: annotation.arrows,
                        canvasSize: proxy.size
                    )
                    AnnotationLabelOverlay(
                        labels: annotation.annotations,
                        canvasSize: proxy.size
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(Self.viewBoxAspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

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

// MARK: - Preview

#Preview("Annotated - squat") {
    let arrow = AnnotationArrow(
        id: "hip-down",
        from: AnnotationPoint(x: 0.21, y: 0.42),
        to: AnnotationPoint(x: 0.21, y: 0.58),
        curve: .straight,
        color: .primary
    )
    let knee = AnnotationLabel(
        id: "knee",
        position: AnnotationPoint(x: 0.18, y: 0.62),
        labelAnchor: AnnotationPoint(x: 0.02, y: 0.66),
        labelKey: "form.barbell-back-squat.annotation.knee",
        color: .info
    )
    let back = AnnotationLabel(
        id: "back",
        position: AnnotationPoint(x: 0.21, y: 0.30),
        labelAnchor: AnnotationPoint(x: 0.55, y: 0.20),
        labelKey: "form.barbell-back-squat.annotation.back",
        color: .success
    )
    let annotation = ExerciseAnnotation(
        slug: "barbell-back-squat",
        view: .front,
        arrows: [arrow],
        annotations: [knee, back]
    )

    return AnnotatedBodyDiagramView(
        primaryMuscles: [.quadriceps],
        secondaryMuscles: [.glutes, .hamstrings, .lowerBack],
        annotation: annotation
    )
    .padding()
}

#Preview("Annotated - plank (no arrows)") {
    let neck = AnnotationLabel(
        id: "neck",
        position: AnnotationPoint(x: 0.21, y: 0.13),
        labelAnchor: AnnotationPoint(x: 0.02, y: 0.05),
        labelKey: "form.plank.annotation.neck",
        color: .info
    )
    let core = AnnotationLabel(
        id: "core",
        position: AnnotationPoint(x: 0.21, y: 0.32),
        labelAnchor: AnnotationPoint(x: 0.55, y: 0.40),
        labelKey: "form.plank.annotation.core",
        color: .primary
    )
    let annotation = ExerciseAnnotation(
        slug: "plank",
        view: .front,
        arrows: [],
        annotations: [neck, core]
    )

    return AnnotatedBodyDiagramView(
        primaryMuscles: [.abs],
        secondaryMuscles: [.obliques, .lowerBack, .deltoids],
        annotation: annotation
    )
    .padding()
}

#Preview("Annotated - push-up") {
    let down = AnnotationArrow(
        id: "chest-down",
        from: AnnotationPoint(x: 0.18, y: 0.20),
        to: AnnotationPoint(x: 0.18, y: 0.30),
        curve: .straight,
        color: .primary
    )
    let body = AnnotationLabel(
        id: "body",
        position: AnnotationPoint(x: 0.21, y: 0.50),
        labelAnchor: AnnotationPoint(x: 0.55, y: 0.55),
        labelKey: "form.push-up.annotation.body",
        color: .success
    )
    let annotation = ExerciseAnnotation(
        slug: "push-up",
        view: .front,
        arrows: [down],
        annotations: [body]
    )

    return AnnotatedBodyDiagramView(
        primaryMuscles: [.chest],
        secondaryMuscles: [.triceps, .deltoids, .abs],
        annotation: annotation
    )
    .padding()
}

#Preview("Annotated - fallback (no annotation)") {
    AnnotatedBodyDiagramView(
        primaryMuscles: [.lats],
        secondaryMuscles: [.biceps, .traps],
        annotation: nil
    )
    .padding()
}

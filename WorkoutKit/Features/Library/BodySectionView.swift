// MARK: - BodySectionView
// AnnotatedBodyDiagramView の 1 セクション(前面 / 後面のいずれか)。
// タイトル → 大きい人体図(対象筋肉ハイライト + 番号付きドット)→
// 番号付きキューリストの 縦並び。
//
// 仕様:
//   - 内部レイアウトは VStack(body 上 → comments 下)。HStack 横並びで
//     人体図が小さくなる旧仕様を解消する。
//   - 人体図は CompactBodyDiagramView を full width で表示。
//     アスペクト比 535:462 を保つので iPhone なら ~300pt 高さ。
//   - cues は呼び出し側で「この side に属するもの」を順序保ったまま渡す。
//     position.x < 0.5 を front、>= 0.5 を back に振り分けるのは
//     AnnotatedBodyDiagramView の責務。
//   - 番号は各 section 内で 1 から始まる。
//   - 注釈ドットは cue.position の正規化座標(0..1)を body 表示サイズで
//     スケーリングして配置する。前面 cue の x は 0.04..0.46(左半分)、
//     後面 cue の x は 0.54..0.96(右半分)に乗る。
//
// CLAUDE.md NG リスト:
//   - 文字列は Localizable.xcstrings 経由
//   - print/force unwrap/.shared なし
//   - View には @State / @Observable のみ(本 View は完全 stateless)

import SwiftUI

enum BodySide {
    case front
    case back
}

struct BodySectionView: View {
    let side: BodySide
    let primaryMuscles: Set<Muscle>
    let secondaryMuscles: Set<Muscle>
    let cues: [AnnotationLabel]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle
            bodyDiagram
            cuesList
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Title

    private var sectionTitle: some View {
        Text(titleKey)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var titleKey: LocalizedStringKey {
        switch side {
        case .front: return "library.detail.body.front"
        case .back:  return "library.detail.body.back"
        }
    }

    // MARK: - Body diagram (full width)

    /// 人体図を full container width で描画し、その上に番号付きドットを乗せる。
    /// CompactBodyDiagramView 内部の `.aspectRatio(.fit)` が高さを決める。
    private var bodyDiagram: some View {
        CompactBodyDiagramView(
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles
        )
        .overlay {
            GeometryReader { proxy in
                let dot = dotDiameter(for: proxy.size)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cues.enumerated()), id: \.element.id) { idx, cue in
                        NumberedDot(number: idx + 1, color: cue.color, diameter: dot)
                            .position(
                                x: cue.position.x * proxy.size.width,
                                y: cue.position.y * proxy.size.height
                            )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height,
                       alignment: .topLeading)
            }
        }
        .accessibilityHidden(true)
    }

    private func dotDiameter(for size: CGSize) -> CGFloat {
        let base = min(size.width, size.height)
        return max(20, min(28, base * 0.075))
    }

    // MARK: - Cues list

    private var cuesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cues.isEmpty {
                Text("library.detail.body.no-cues")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } else {
                ForEach(Array(cues.enumerated()), id: \.element.id) { idx, cue in
                    NumberedCueRow(
                        number: idx + 1,
                        key: LocalizedStringKey(cue.labelKey),
                        color: cue.color
                    )
                }
            }
        }
    }
}

// MARK: - Numbered dot (on body)

private struct NumberedDot: View {
    let number: Int
    let color: AnnotationColor
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(color.fillColor)
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
            Text(String(number))
                .font(.system(size: diameter * 0.55, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
    }
}

// MARK: - Numbered cue row (in list)

private struct NumberedCueRow: View {
    let number: Int
    let key: LocalizedStringKey
    let color: AnnotationColor

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(color.fillColor)
                Text(String(number))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 22, height: 22)
            .padding(.top, 1)

            Text(key)
                .font(.callout)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Previews

#Preview("BodySection - front (squat)") {
    let knee = AnnotationLabel(
        id: "knee", position: AnnotationPoint(x: 0.20, y: 0.66),
        labelAnchor: AnnotationPoint(x: 0.04, y: 0.65),
        labelKey: "form.barbell-back-squat.annotation.knee", color: .info
    )
    let torso = AnnotationLabel(
        id: "torso", position: AnnotationPoint(x: 0.22, y: 0.21),
        labelAnchor: AnnotationPoint(x: 0.98, y: 0.10),
        labelKey: "form.barbell-back-squat.annotation.back", color: .success
    )
    let hip = AnnotationLabel(
        id: "hip", position: AnnotationPoint(x: 0.21, y: 0.45),
        labelAnchor: AnnotationPoint(x: 0.04, y: 0.35),
        labelKey: "form.barbell-back-squat.annotation.hip", color: .info
    )
    return ScrollView {
        BodySectionView(
            side: .front,
            primaryMuscles: [.quadriceps],
            secondaryMuscles: [.glutes, .hamstrings],
            cues: [knee, torso, hip]
        )
        .padding()
    }
}

#Preview("BodySection - back (pull-up)") {
    let scap = AnnotationLabel(
        id: "scap", position: AnnotationPoint(x: 0.74, y: 0.13),
        labelAnchor: AnnotationPoint(x: 0.98, y: 0.10),
        labelKey: "form.pull-up.annotation.scap", color: .info
    )
    let lats = AnnotationLabel(
        id: "lats", position: AnnotationPoint(x: 0.79, y: 0.27),
        labelAnchor: AnnotationPoint(x: 0.04, y: 0.35),
        labelKey: "form.pull-up.annotation.lats", color: .primary
    )
    return ScrollView {
        BodySectionView(
            side: .back,
            primaryMuscles: [.lats],
            secondaryMuscles: [.biceps, .traps],
            cues: [scap, lats]
        )
        .padding()
    }
}

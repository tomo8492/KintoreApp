// MARK: - BodySectionView
// AnnotatedBodyDiagramView の 1 行ぶん。タイトル(「前面」/「後面」)+
// 半身の人体図(対象筋肉ハイライト + 番号付きドット)+ 番号付きキューリスト。
//
// 仕様:
//   - 左に半身図、右に番号付きテキスト一覧。HStack(top alignment)。
//   - cues は呼び出し側で「この side に属するもの」を順序保ったまま渡す。
//     position.x < 0.5 を front、>= 0.5 を back に振り分けるのは
//     AnnotatedBodyDiagramView の責務。
//   - 番号は各 section 内で 1 から始まる。section 見出しがあるので
//     通し番号にしないほうが視覚的に分かりやすい(指示書の推奨)。
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
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle
            HStack(alignment: .top, spacing: 12) {
                halfBody
                cuesList
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

    // MARK: - Half body

    /// 半身図のアスペクト比 (267.5 : 462)。
    private static let halfAspect: CGFloat =
        (BodyHitZones.viewBox.width / 2) / BodyHitZones.viewBox.height

    private var halfBody: some View {
        GeometryReader { proxy in
            let halfW = proxy.size.width
            let height = proxy.size.height
            let fullW = halfW * 2

            ZStack(alignment: .topLeading) {
                CompactBodyDiagramView(
                    primaryMuscles: primaryMuscles,
                    secondaryMuscles: secondaryMuscles
                )
                .frame(width: fullW, height: height)
                .offset(x: side == .front ? 0 : -halfW)

                ForEach(Array(cues.enumerated()), id: \.element.id) { idx, cue in
                    NumberedDot(number: idx + 1,
                                color: cue.color,
                                diameter: dotDiameter(for: height))
                        .position(
                            x: cue.position.x * fullW - (side == .back ? halfW : 0),
                            y: cue.position.y * height
                        )
                }
            }
            .frame(width: halfW, height: height, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(Self.halfAspect, contentMode: .fit)
        .frame(maxWidth: 150)
        .accessibilityHidden(true) // accessibility は親 View でまとめる
    }

    private func dotDiameter(for height: CGFloat) -> CGFloat {
        max(16, min(22, height * 0.08))
    }

    // MARK: - Cues list

    private var cuesList: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle().fill(color.fillColor)
                Text(String(number))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            .padding(.top, 1)

            Text(key)
                .font(.footnote)
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
    BodySectionView(
        side: .front,
        primaryMuscles: [.quadriceps],
        secondaryMuscles: [.glutes, .hamstrings],
        cues: [knee, torso]
    )
    .padding()
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
    BodySectionView(
        side: .back,
        primaryMuscles: [.lats],
        secondaryMuscles: [.biceps, .traps],
        cues: [scap, lats]
    )
    .padding()
}

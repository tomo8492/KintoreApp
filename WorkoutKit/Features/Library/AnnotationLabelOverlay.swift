// MARK: - AnnotationLabelOverlay
// AnnotatedBodyDiagramView 上に「人体上のドット → 引き出し線 → テキストカード」
// を描く表示専用 View。
//
// 設計指針(CLAUDE.md §-1.6 / NG リスト):
//   - position は人体図上の解剖学的なターゲット位置(関節など)
//   - labelAnchor はテキストカードの中心点
//   - position から labelAnchor へ細いラインを引き、ドット + カードで挟む
//   - View には @State / @Observable のみ。本 View は完全 stateless
//   - labelKey は Localizable.xcstrings のキー(LocalizedStringKey で解決)

import SwiftUI

struct AnnotationLabelOverlay: View {
    let labels: [AnnotationLabel]
    let canvasSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(labels, id: \.id) { label in
                AnnotationLabelMark(
                    label: label,
                    canvasSize: canvasSize,
                    dotRadius: dotRadius,
                    fontSize: fontSize
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height,
               alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var dotRadius: CGFloat {
        let base = min(canvasSize.width, canvasSize.height)
        return max(3.0, min(6.0, base * 0.018))
    }

    private var fontSize: CGFloat {
        let base = min(canvasSize.width, canvasSize.height)
        return max(9.0, min(12.0, base * 0.035))
    }
}

// MARK: - Single label mark

private struct AnnotationLabelMark: View {
    let label: AnnotationLabel
    let canvasSize: CGSize
    let dotRadius: CGFloat
    let fontSize: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LeaderLine(
                from: position,
                to: anchor
            )
            .stroke(label.color.strokeColor, style: StrokeStyle(
                lineWidth: 1.0,
                lineCap: .round,
                dash: [3, 2]
            ))

            Circle()
                .fill(label.color.fillColor)
                .frame(width: dotRadius * 2, height: dotRadius * 2)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.0)
                )
                .position(position)

            // anchor.x が canvas 中央より左なら leading 端を anchor に、
            // 右なら trailing 端を anchor に揃える(端でテキストがクリップされない
            // ようにするため)。HStack + Spacer で中央 .position の代わりに
            // 端揃えを実現する。
            cardContainer
        }
        .frame(width: canvasSize.width, height: canvasSize.height,
               alignment: .topLeading)
    }

    @ViewBuilder
    private var cardContainer: some View {
        let card = LabelCard(
            key: LocalizedStringKey(label.labelKey),
            color: label.color,
            fontSize: fontSize,
            canvasWidth: canvasSize.width
        )
        if anchorIsLeftSide {
            HStack(spacing: 0) {
                card
                Spacer(minLength: 0)
            }
            .frame(width: max(0, canvasSize.width - anchor.x))
            .offset(x: anchor.x, y: anchor.y - fontSize * 0.9)
        } else {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                card
            }
            .frame(width: max(0, anchor.x))
            .offset(x: 0, y: anchor.y - fontSize * 0.9)
        }
    }

    private var anchorIsLeftSide: Bool {
        label.labelAnchor.x < 0.5
    }

    private var position: CGPoint {
        CGPoint(x: label.position.x * canvasSize.width,
                y: label.position.y * canvasSize.height)
    }

    private var anchor: CGPoint {
        CGPoint(x: label.labelAnchor.x * canvasSize.width,
                y: label.labelAnchor.y * canvasSize.height)
    }
}

// MARK: - Leader line

private struct LeaderLine: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}

// MARK: - Label card

/// 半透明の白(ライト) / 黒(ダーク) 背景に枠線で囲んだ短文ラベル。
/// テキスト幅は Localizable.xcstrings のキー解決後に SwiftUI が決める。
/// canvasWidth に対して 45% を上限に折り返す。
private struct LabelCard: View {
    let key: LocalizedStringKey
    let color: AnnotationColor
    let fontSize: CGFloat
    let canvasWidth: CGFloat

    var body: some View {
        Text(key)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: canvasWidth * 0.45, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.strokeColor, lineWidth: 1.0)
            )
    }
}

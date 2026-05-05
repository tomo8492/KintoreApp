// MARK: - AnnotationLabelOverlay
// AnnotatedBodyDiagramView 上に「人体上のドット → 引き出し線 → テキストカード」
// を描く表示専用 View。実際の配置は AnnotationLabelLayout.resolve(...) が
// 計算する(衝突回避済みの矩形を返す)。本 View はそれを描画するだけ。
//
// 設計指針(CLAUDE.md §-1.6 / NG リスト):
//   - View には @State / @Observable のみ。本 View は完全 stateless
//   - labelKey は Localizable.xcstrings のキー(LocalizedStringKey で解決)
//   - 1 ファイル 300 行以内に収める

import SwiftUI

struct AnnotationLabelOverlay: View {
    let labels: [AnnotationLabel]
    let canvasSize: CGSize

    var body: some View {
        let placements = AnnotationLabelLayout.resolve(
            labels: labels,
            canvasSize: canvasSize,
            fontSize: fontSize
        )

        ZStack(alignment: .topLeading) {
            ForEach(placements, id: \.labelId) { placement in
                LeaderLine(from: placement.dotPosition, to: placement.leaderEnd)
                    .stroke(placement.color.strokeColor, style: StrokeStyle(
                        lineWidth: 1.0,
                        lineCap: .round,
                        dash: [3, 2]
                    ))

                Circle()
                    .fill(placement.color.fillColor)
                    .frame(width: dotRadius * 2, height: dotRadius * 2)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 1.0)
                    )
                    .position(placement.dotPosition)

                LabelCard(
                    key: LocalizedStringKey(placement.labelKey),
                    color: placement.color,
                    fontSize: fontSize
                )
                .frame(width: placement.cardRect.width,
                       height: placement.cardRect.height,
                       alignment: .topLeading)
                .position(x: placement.cardRect.midX,
                          y: placement.cardRect.midY)
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
/// 親が `.frame(width:height:)` で寸法を確定させるため、本 View は
/// その寸法いっぱいに収まるよう Text を leading 揃えで描画する。
private struct LabelCard: View {
    let key: LocalizedStringKey
    let color: AnnotationColor
    let fontSize: CGFloat

    var body: some View {
        Text(key)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

// MARK: - AnnotationArrowOverlay
// AnnotatedBodyDiagramView 上に動作矢印(curved / straight)を描画する。
// 純粋な SwiftUI Path + Triangle だけで実装し、外部アセットに依存しない。
//
// 設計指針(CLAUDE.md §-1.6 / NG リスト):
//   - 1 矢印 = 1 Path + 1 Triangle Path(矢頭)
//   - 太さは canvasSize に応じて 1.5 〜 3.5pt
//   - 色は AnnotationColor → Color にマッピング(本ファイル外で定義)
//   - View には @State / @Observable のみ。本 View は完全 stateless

import SwiftUI

struct AnnotationArrowOverlay: View {
    let arrows: [AnnotationArrow]
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            ForEach(arrows, id: \.id) { arrow in
                ArrowShape(
                    from: point(arrow.from),
                    to: point(arrow.to),
                    curve: arrow.curve
                )
                .stroke(
                    arrow.color.strokeColor,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                ArrowHead(
                    from: point(arrow.from),
                    to: point(arrow.to),
                    curve: arrow.curve,
                    size: headSize
                )
                .fill(arrow.color.fillColor)
            }
        }
        .allowsHitTesting(false)
    }

    private func point(_ p: AnnotationPoint) -> CGPoint {
        CGPoint(x: p.x * canvasSize.width, y: p.y * canvasSize.height)
    }

    private var strokeWidth: CGFloat {
        // 表示サイズに合わせて 1.5 〜 3.5pt の範囲で線幅を決める。
        // body-base SVG の viewBox (535×462) を基準に係数を取る。
        let base = min(canvasSize.width, canvasSize.height)
        return max(1.5, min(3.5, base * 0.012))
    }

    private var headSize: CGFloat {
        let base = min(canvasSize.width, canvasSize.height)
        return max(8, min(18, base * 0.05))
    }
}

// MARK: - Arrow body

/// 直線 or 曲線(2次ベジエ)で from→to を結ぶ。
private struct ArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint
    let curve: AnnotationCurve

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch curve {
        case .straight:
            path.move(to: from)
            path.addLine(to: to)
        case .curved:
            // from→to の中点から法線方向に少しオフセットさせて
            // 軽くアーチを描く。オフセット量は線分長の 18%。
            let dx = to.x - from.x
            let dy = to.y - from.y
            let length = max(1, hypot(dx, dy))
            let nx = -dy / length
            let ny = dx / length
            let offset = length * 0.18
            let mid = CGPoint(x: (from.x + to.x) * 0.5 + nx * offset,
                              y: (from.y + to.y) * 0.5 + ny * offset)
            path.move(to: from)
            path.addQuadCurve(to: to, control: mid)
        }
        return path
    }
}

// MARK: - Arrow head

/// to の地点に三角形の矢頭を描く。to 周辺の進行方向に向ける。
private struct ArrowHead: Shape {
    let from: CGPoint
    let to: CGPoint
    let curve: AnnotationCurve
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        // 進行方向ベクトル。
        // 直線の場合は from→to のまま。
        // 曲線の場合は ArrowShape と同じ control 点から to への接線を使う。
        let direction = computedDirection()

        // 単位ベクトル
        let length = max(1, hypot(direction.x, direction.y))
        let ux = direction.x / length
        let uy = direction.y / length
        // 法線(右手)
        let nx = -uy
        let ny = ux

        // 矢頭の三角形:
        //   先端 = to
        //   後端中央 = to - u * size
        //   左右 = 後端中央 ± n * (size * 0.6)
        let backCenter = CGPoint(x: to.x - ux * size, y: to.y - uy * size)
        let left = CGPoint(x: backCenter.x + nx * size * 0.6,
                           y: backCenter.y + ny * size * 0.6)
        let right = CGPoint(x: backCenter.x - nx * size * 0.6,
                            y: backCenter.y - ny * size * 0.6)

        var path = Path()
        path.move(to: to)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    private func computedDirection() -> CGPoint {
        switch curve {
        case .straight:
            return CGPoint(x: to.x - from.x, y: to.y - from.y)
        case .curved:
            // ArrowShape と同じ control 点。control→to を矢頭の接線として扱う。
            let dx = to.x - from.x
            let dy = to.y - from.y
            let length = max(1, hypot(dx, dy))
            let nx = -dy / length
            let ny = dx / length
            let offset = length * 0.18
            let mid = CGPoint(x: (from.x + to.x) * 0.5 + nx * offset,
                              y: (from.y + to.y) * 0.5 + ny * offset)
            return CGPoint(x: to.x - mid.x, y: to.y - mid.y)
        }
    }
}

// MARK: - StickFigure
// プロトタイプ実装: 5種目分のエクササイズアニメーションで共有する
// 棒人間描画プリミティブ。
//
// 設計方針:
//   - 各 *Animation は `pose(phase:) -> Pose` を返す純関数。
//   - Pose は正規化座標 (0...1) の関節点と骨接続のリストを持つ。
//   - Canvas は与えられた CGSize にスケールして描画する。
//   - 動画ファイルは §-1 Lock により同梱不可。Lottie 等の依存も入れない。
//     SwiftUI 標準の Canvas + TimelineView だけで完結させる。

import SwiftUI

// 正規化座標系: 原点は左上、x → 右、y → 下。
// 値域は 0...1。Canvas で size に乗じて実座標に変換する。
struct StickFigurePose {
    /// 関節点(キーは参照用ラベル)。
    var joints: [Joint: CGPoint]
    /// 骨接続(線分)。
    var bones: [Bone]
    /// 頭部の中心と半径(正規化、半径は短辺基準)。
    var head: Head?

    enum Joint: Hashable {
        case neck
        case pelvis
        case shoulderL, shoulderR
        case elbowL, elbowR
        case wristL, wristR
        case hipL, hipR
        case kneeL, kneeR
        case ankleL, ankleR
        case generic(String)
    }

    struct Bone {
        let from: Joint
        let to: Joint
    }

    struct Head {
        var center: CGPoint
        /// 短辺(min(w,h))に対する比率。
        var radiusRatio: CGFloat
    }
}

enum StickFigure {

    // MARK: - 描画

    /// 正規化座標の Pose を実座標にスケールして描画する。
    static func draw(
        _ pose: StickFigurePose,
        in context: inout GraphicsContext,
        size: CGSize,
        color: Color,
        lineWidth: CGFloat = 6,
        groundY: CGFloat? = 0.95
    ) {
        // 床ライン(任意)。
        if let groundY {
            let y = groundY * size.height
            var groundPath = Path()
            groundPath.move(to: CGPoint(x: 0, y: y))
            groundPath.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(
                groundPath,
                with: .color(color.opacity(0.25)),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
            )
        }

        // 骨。
        for bone in pose.bones {
            guard let a = pose.joints[bone.from],
                  let b = pose.joints[bone.to] else { continue }
            var path = Path()
            path.move(to: scale(a, in: size))
            path.addLine(to: scale(b, in: size))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }

        // 頭。
        if let head = pose.head {
            let center = scale(head.center, in: size)
            let radius = head.radiusRatio * min(size.width, size.height)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }

    // MARK: - 補間ユーティリティ

    /// 2点を t (0...1) で線形補間。
    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// スカラー線形補間。
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    /// 0...1 の phase を 0→1→0 の往復(ease-in-out)に変換する。
    /// - phase=0/1 で 0、phase=0.5 で 1。
    static func bounce(_ phase: CGFloat) -> CGFloat {
        // (1 - cos(2π * phase)) / 2 は 0→1→0 の滑らか往復。
        (1 - cos(2 * .pi * phase)) / 2
    }

    /// 連続キーフレームを与えて phase で位置を返すヘルパ。
    /// keyframes は (phase, point) を昇順で渡す。両端に 0/1 を含めること。
    static func keyframe(_ keyframes: [(CGFloat, CGPoint)], at phase: CGFloat) -> CGPoint {
        precondition(keyframes.count >= 2)
        let p = max(0, min(1, phase))
        for i in 0..<(keyframes.count - 1) {
            let (p0, v0) = keyframes[i]
            let (p1, v1) = keyframes[i + 1]
            if p >= p0 && p <= p1 {
                let t = p1 == p0 ? 0 : (p - p0) / (p1 - p0)
                return lerp(v0, v1, t)
            }
        }
        return keyframes.last?.1 ?? .zero
    }

    // MARK: - 内部

    private static func scale(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

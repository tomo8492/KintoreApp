// MARK: - LungeAnimation
// リバースランジ(reverse-lunge)。横向き図で前足は固定、
// 後ろ足が後方に下がって膝を曲げる。

import SwiftUI

enum LungeAnimation {
    static let cycleDuration: TimeInterval = 2.4

    static func pose(phase: CGFloat) -> StickFigurePose {
        let depth = StickFigure.bounce(phase)

        // 横向き(顔は右)。前足(L側=画面左にも見えるが解剖学的Lで固定)を
        // 体幹の真下に置き、後ろ足だけが後方へ。
        // 簡略化のため右側を「前足(支持脚)」、左側を「後ろ足」とする。

        // 前足(支持脚): 直立時も lunge 時も同じ位置。
        let frontAnkle = CGPoint(x: 0.55, y: 0.95)
        let frontKnee  = CGPoint(x: 0.55, y: 0.78)

        // 後ろ足。立位:前足の隣。lunge:後方へ大きくステップ、膝が曲がる。
        let backAnkleStand = CGPoint(x: 0.50, y: 0.95)
        let backAnkleLunge = CGPoint(x: 0.20, y: 0.95)
        let backKneeStand  = CGPoint(x: 0.50, y: 0.78)
        let backKneeLunge  = CGPoint(x: 0.30, y: 0.86)

        // 腰: lunge では少し前に出て下がる。
        let hipStand = CGPoint(x: 0.55, y: 0.55)
        let hipLunge = CGPoint(x: 0.55, y: 0.62)

        // 上体・頭: 腰と一緒に少し下がるが、姿勢は直立を保つ。
        let shoulderStand = CGPoint(x: 0.55, y: 0.30)
        let shoulderLunge = CGPoint(x: 0.55, y: 0.37)
        let headStand = CGPoint(x: 0.55, y: 0.20)
        let headLunge = CGPoint(x: 0.55, y: 0.27)

        // 腕: 軽く前に振る。
        let wristStand = CGPoint(x: 0.55, y: 0.55)
        let wristLunge = CGPoint(x: 0.65, y: 0.55)
        let elbowStand = CGPoint(x: 0.55, y: 0.42)
        let elbowLunge = CGPoint(x: 0.60, y: 0.45)

        let backAnkle = StickFigure.lerp(backAnkleStand, backAnkleLunge, depth)
        let backKnee  = StickFigure.lerp(backKneeStand,  backKneeLunge,  depth)
        let hip       = StickFigure.lerp(hipStand,       hipLunge,       depth)
        let shoulder  = StickFigure.lerp(shoulderStand,  shoulderLunge,  depth)
        let head      = StickFigure.lerp(headStand,      headLunge,      depth)
        let elbow     = StickFigure.lerp(elbowStand,     elbowLunge,     depth)
        let wrist     = StickFigure.lerp(wristStand,     wristLunge,     depth)

        let joints: [StickFigurePose.Joint: CGPoint] = [
            // 前足(R)
            .ankleR: frontAnkle,
            .kneeR: frontKnee,
            // 後ろ足(L)
            .ankleL: backAnkle,
            .kneeL: backKnee,
            // 腰・上半身
            .hipR: hip,
            .neck: shoulder,
            .shoulderR: shoulder,
            .elbowR: elbow,
            .wristR: wrist,
        ]

        let bones: [StickFigurePose.Bone] = [
            .init(from: .ankleR, to: .kneeR),
            .init(from: .kneeR,  to: .hipR),
            .init(from: .ankleL, to: .kneeL),
            .init(from: .kneeL,  to: .hipR),
            .init(from: .hipR,   to: .shoulderR),
            .init(from: .shoulderR, to: .elbowR),
            .init(from: .elbowR,    to: .wristR),
        ]

        return StickFigurePose(
            joints: joints,
            bones: bones,
            head: .init(center: head, radiusRatio: 0.05)
        )
    }
}

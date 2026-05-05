// MARK: - PushupAnimation
// 横向きの棒人間がプッシュアップを上下する。phase 0→1 で
// 上→下→上 の 1 サイクル(`StickFigure.bounce` を使用)。

import SwiftUI

enum PushupAnimation {
    static let cycleDuration: TimeInterval = 2.0

    static func pose(phase: CGFloat) -> StickFigurePose {
        // 0→1→0 の上下動。0 = 腕伸展(上)、1 = 腕屈曲(下)。
        let depth = StickFigure.bounce(phase)

        // 横向き(顔は右)の側面図。
        // 接地: つま先・手のひら(固定)。
        // 上では肩・腰が高く、下では肩・腰が床に近づく。
        let toes      = CGPoint(x: 0.13, y: 0.95)
        let kneeUp    = CGPoint(x: 0.30, y: 0.80)
        let kneeDown  = CGPoint(x: 0.30, y: 0.86)
        let hipUp     = CGPoint(x: 0.46, y: 0.65)
        let hipDown   = CGPoint(x: 0.46, y: 0.80)
        let shoulderUp   = CGPoint(x: 0.70, y: 0.55)
        let shoulderDown = CGPoint(x: 0.70, y: 0.78)
        let headUp    = CGPoint(x: 0.80, y: 0.50)
        let headDown  = CGPoint(x: 0.80, y: 0.74)
        // 手は床に固定。
        let wrist     = CGPoint(x: 0.78, y: 0.94)
        // 肘: 上では伸展(肩-手の中間付近)、下では後ろに曲げる。
        let elbowUp   = CGPoint(x: 0.76, y: 0.75)
        let elbowDown = CGPoint(x: 0.62, y: 0.86)

        let knee     = StickFigure.lerp(kneeUp, kneeDown, depth)
        let hip      = StickFigure.lerp(hipUp, hipDown, depth)
        let shoulder = StickFigure.lerp(shoulderUp, shoulderDown, depth)
        let head     = StickFigure.lerp(headUp, headDown, depth)
        let elbow    = StickFigure.lerp(elbowUp, elbowDown, depth)

        let joints: [StickFigurePose.Joint: CGPoint] = [
            .ankleR: toes,
            .kneeR: knee,
            .hipR: hip,
            .shoulderR: shoulder,
            .neck: shoulder,
            .elbowR: elbow,
            .wristR: wrist,
        ]

        let bones: [StickFigurePose.Bone] = [
            .init(from: .ankleR, to: .kneeR),
            .init(from: .kneeR, to: .hipR),
            .init(from: .hipR, to: .shoulderR),
            .init(from: .shoulderR, to: .elbowR),
            .init(from: .elbowR, to: .wristR),
        ]

        return StickFigurePose(
            joints: joints,
            bones: bones,
            head: .init(center: head, radiusRatio: 0.05)
        )
    }
}

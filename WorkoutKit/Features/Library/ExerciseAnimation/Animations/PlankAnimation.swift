// MARK: - PlankAnimation
// プランクは静止種目だが、完全に静止していると壊れている印象になる。
// 呼吸に合わせた微細な上下(±0.005)で「生きている」感を出す。

import SwiftUI

enum PlankAnimation {
    static let cycleDuration: TimeInterval = 3.6

    static func pose(phase: CGFloat) -> StickFigurePose {
        let breath = StickFigure.bounce(phase) * 0.01  // ごく僅かな上下動

        // 横向き、前腕プランク。手は床、肘 = 肩の真下。
        let toes      = CGPoint(x: 0.13, y: 0.95)
        let knee      = CGPoint(x: 0.32, y: 0.85)
        let hip       = CGPoint(x: 0.50, y: 0.74 + breath)
        let shoulder  = CGPoint(x: 0.74, y: 0.72 + breath)
        let head      = CGPoint(x: 0.83, y: 0.69 + breath)
        // 前腕プランク: 肘は床近く、手も床。
        let elbow     = CGPoint(x: 0.74, y: 0.94)
        let wrist     = CGPoint(x: 0.86, y: 0.94)

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
            .init(from: .kneeR,  to: .hipR),
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

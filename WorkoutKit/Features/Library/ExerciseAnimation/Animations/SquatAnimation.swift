// MARK: - SquatAnimation
// 正面向きスクワット。両足肩幅、両膝が外に開きながら腰が落ちる。

import SwiftUI

enum SquatAnimation {
    static let cycleDuration: TimeInterval = 2.4

    static func pose(phase: CGFloat) -> StickFigurePose {
        let depth = StickFigure.bounce(phase)

        // 正面図(viewer 視点)。図形中央 x = 0.5。
        // 立位 → 深いスクワット(膝関節 ~90°、太ももが床と平行)。
        let ankleL = CGPoint(x: 0.36, y: 0.95)
        let ankleR = CGPoint(x: 0.64, y: 0.95)

        // 立位: 膝はほぼ伸展、足首の真上付近。
        let kneeStandL = CGPoint(x: 0.37, y: 0.74)
        let kneeStandR = CGPoint(x: 0.63, y: 0.74)
        // しゃがみ: 膝は外に開きながら高さも上がる(腰が落ちる)。
        let kneeSquatL = CGPoint(x: 0.30, y: 0.78)
        let kneeSquatR = CGPoint(x: 0.70, y: 0.78)

        let hipStandL = CGPoint(x: 0.42, y: 0.55)
        let hipStandR = CGPoint(x: 0.58, y: 0.55)
        let hipSquatL = CGPoint(x: 0.40, y: 0.74)
        let hipSquatR = CGPoint(x: 0.60, y: 0.74)

        // 肩は腰と同じ z 量だけ下がる。
        let shoulderStandL = CGPoint(x: 0.39, y: 0.36)
        let shoulderStandR = CGPoint(x: 0.61, y: 0.36)
        let shoulderSquatL = CGPoint(x: 0.37, y: 0.52)
        let shoulderSquatR = CGPoint(x: 0.63, y: 0.52)

        // 腕は前方に伸ばすカウンター(stand: 体側、squat: 前方水平)。
        // 正面図なので「前方」= 視点に向かう=画面中央寄り(描画上 y 同じ)。
        let elbowStandL = CGPoint(x: 0.36, y: 0.50)
        let elbowStandR = CGPoint(x: 0.64, y: 0.50)
        let elbowSquatL = CGPoint(x: 0.42, y: 0.55)
        let elbowSquatR = CGPoint(x: 0.58, y: 0.55)

        let wristStandL = CGPoint(x: 0.34, y: 0.62)
        let wristStandR = CGPoint(x: 0.66, y: 0.62)
        let wristSquatL = CGPoint(x: 0.46, y: 0.55)
        let wristSquatR = CGPoint(x: 0.54, y: 0.55)

        let neckStand = CGPoint(x: 0.50, y: 0.32)
        let neckSquat = CGPoint(x: 0.50, y: 0.48)
        let headStand = CGPoint(x: 0.50, y: 0.22)
        let headSquat = CGPoint(x: 0.50, y: 0.40)

        let kneeL = StickFigure.lerp(kneeStandL, kneeSquatL, depth)
        let kneeR = StickFigure.lerp(kneeStandR, kneeSquatR, depth)
        let hipL  = StickFigure.lerp(hipStandL,  hipSquatL,  depth)
        let hipR  = StickFigure.lerp(hipStandR,  hipSquatR,  depth)
        let shoulderL = StickFigure.lerp(shoulderStandL, shoulderSquatL, depth)
        let shoulderR = StickFigure.lerp(shoulderStandR, shoulderSquatR, depth)
        let elbowL = StickFigure.lerp(elbowStandL, elbowSquatL, depth)
        let elbowR = StickFigure.lerp(elbowStandR, elbowSquatR, depth)
        let wristL = StickFigure.lerp(wristStandL, wristSquatL, depth)
        let wristR = StickFigure.lerp(wristStandR, wristSquatR, depth)
        let neck   = StickFigure.lerp(neckStand, neckSquat, depth)
        let head   = StickFigure.lerp(headStand, headSquat, depth)

        let joints: [StickFigurePose.Joint: CGPoint] = [
            .ankleL: ankleL, .ankleR: ankleR,
            .kneeL: kneeL,   .kneeR: kneeR,
            .hipL: hipL,     .hipR: hipR,
            .shoulderL: shoulderL, .shoulderR: shoulderR,
            .elbowL: elbowL, .elbowR: elbowR,
            .wristL: wristL, .wristR: wristR,
            .neck: neck,
        ]

        let bones: [StickFigurePose.Bone] = [
            .init(from: .ankleL, to: .kneeL),
            .init(from: .ankleR, to: .kneeR),
            .init(from: .kneeL,  to: .hipL),
            .init(from: .kneeR,  to: .hipR),
            .init(from: .hipL,   to: .hipR),
            .init(from: .hipL,   to: .shoulderL),
            .init(from: .hipR,   to: .shoulderR),
            .init(from: .shoulderL, to: .shoulderR),
            .init(from: .shoulderL, to: .elbowL),
            .init(from: .elbowL,    to: .wristL),
            .init(from: .shoulderR, to: .elbowR),
            .init(from: .elbowR,    to: .wristR),
            .init(from: .neck,   to: .shoulderL),
            .init(from: .neck,   to: .shoulderR),
        ]

        return StickFigurePose(
            joints: joints,
            bones: bones,
            head: .init(center: head, radiusRatio: 0.06)
        )
    }
}

// MARK: - BurpeeAnimation
// バーピー: 立位 → スクワットで床に手 → プランク → スクワット → 立位 → ジャンプ。
// 7 つのキーポーズを用意し、`StickFigure.keyframe` で位相補間する。

import SwiftUI

enum BurpeeAnimation {
    static let cycleDuration: TimeInterval = 3.6

    /// 各ポーズのキーフレーム phase。
    private static let phases: [CGFloat] = [
        0.00,  // stand
        0.18,  // squat (両手床)
        0.42,  // plank
        0.58,  // plank (キープ)
        0.78,  // squat (両手床)
        0.93,  // jump apex
        1.00,  // stand
    ]

    // 各キーポーズでの関節位置(横向き、顔は右)。
    private static let stand = JointSet(
        toes: .init(x: 0.45, y: 0.95),
        knee: .init(x: 0.45, y: 0.78),
        hip:  .init(x: 0.45, y: 0.55),
        shoulder: .init(x: 0.45, y: 0.30),
        head: .init(x: 0.45, y: 0.20),
        elbow: .init(x: 0.45, y: 0.42),
        wrist: .init(x: 0.45, y: 0.54)
    )
    private static let squatHands = JointSet(
        toes: .init(x: 0.45, y: 0.95),
        knee: .init(x: 0.40, y: 0.82),
        hip:  .init(x: 0.50, y: 0.80),
        shoulder: .init(x: 0.55, y: 0.72),
        head: .init(x: 0.62, y: 0.70),
        elbow: .init(x: 0.60, y: 0.86),
        wrist: .init(x: 0.66, y: 0.94)
    )
    private static let plank = JointSet(
        toes: .init(x: 0.13, y: 0.95),
        knee: .init(x: 0.30, y: 0.85),
        hip:  .init(x: 0.46, y: 0.74),
        shoulder: .init(x: 0.70, y: 0.62),
        head: .init(x: 0.80, y: 0.57),
        elbow: .init(x: 0.70, y: 0.78),
        wrist: .init(x: 0.72, y: 0.94)
    )
    private static let jump = JointSet(
        toes: .init(x: 0.45, y: 0.86),
        knee: .init(x: 0.45, y: 0.69),
        hip:  .init(x: 0.45, y: 0.47),
        shoulder: .init(x: 0.45, y: 0.22),
        head: .init(x: 0.45, y: 0.12),
        // 腕は頭上に挙上。
        elbow: .init(x: 0.45, y: 0.06),
        wrist: .init(x: 0.45, y: 0.00)
    )

    private static let sequence: [JointSet] = [
        stand, squatHands, plank, plank, squatHands, jump, stand
    ]

    static func pose(phase: CGFloat) -> StickFigurePose {
        let toes = keyframes(\.toes, at: phase)
        let knee = keyframes(\.knee, at: phase)
        let hip  = keyframes(\.hip,  at: phase)
        let shoulder = keyframes(\.shoulder, at: phase)
        let head = keyframes(\.head, at: phase)
        let elbow = keyframes(\.elbow, at: phase)
        let wrist = keyframes(\.wrist, at: phase)

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

    // MARK: - Helpers

    private struct JointSet {
        var toes: CGPoint
        var knee: CGPoint
        var hip: CGPoint
        var shoulder: CGPoint
        var head: CGPoint
        var elbow: CGPoint
        var wrist: CGPoint
    }

    private static func keyframes(
        _ keyPath: KeyPath<JointSet, CGPoint>,
        at phase: CGFloat
    ) -> CGPoint {
        let pairs = zip(phases, sequence).map { ($0, $1[keyPath: keyPath]) }
        return StickFigure.keyframe(Array(pairs), at: phase)
    }
}

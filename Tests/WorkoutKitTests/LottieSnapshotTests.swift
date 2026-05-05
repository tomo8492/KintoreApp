// MARK: - LottieSnapshotTests
// sample/2d-lottie-prototype 用のスモークテスト。
//
// 役割:
//   - `Resources/Lottie/<slug>.json` が Bundle にロードできることを確認する
//     (Bundle 同梱抜けを早期検知。SPM 依存追加 + xcodegen 再生成の手順抜け
//      で一番ハマりやすいポイント)。
//
// 「実際に Lottie が画面でアニメするか」は live simulator で
// `LottieGalleryDebugView` を起動して目視確認する経路で検証する
// (本ファイルでは扱わない理由: 一般的に `view.layer.render(in:)` を
//  オフスクリーン UIView に対して呼んでも CAShapeLayer の presentation
//  値が反映されず、空相当の PNG が出力される)。

import Foundation
import Lottie
import Testing

@testable import WorkoutKit

@MainActor
@Suite("LottieSnapshot")
struct LottieSnapshotTests {

    @Test("All 5 Lottie JSON resources are present in the main bundle")
    func bundleContainsAllLottieFiles() {
        for kind in ExerciseAnimationKind.allCases {
            let animation = LottieAnimation.named(kind.lottieResourceName, bundle: .main)
            #expect(animation != nil, "missing Lottie resource: \(kind.lottieResourceName).json")
        }
    }
}

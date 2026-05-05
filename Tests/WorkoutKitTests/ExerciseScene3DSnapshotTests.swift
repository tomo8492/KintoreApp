// MARK: - ExerciseScene3DSnapshotTests
// 3D プロト用の使い捨てスナップショットテスト。
// `FigureSceneDriver` のシーンを SCNView 経由で PNG 画像にレンダリングし、
// 5 種目分を `/tmp/3d-sample/` に書き出す。
// ホスト側で `cp` できるよう、絶対パスを NSLog で残す。
//
// 通常テスト実行から除外したい場合は `WK_SKIP_3D_SNAPSHOTS=1` を立てる。
// 既存の 2D 版(ExerciseAnimationSnapshotTests)とは別ターゲット出力で衝突しない。

import Foundation
import SceneKit
import Metal
import UIKit
import Testing
@testable import WorkoutKit

@MainActor
@Suite("ExerciseScene3DSnapshot")
struct ExerciseScene3DSnapshotTests {

    @Test("Render all 5 exercise 3D scenes to PNG (phase=0.5)")
    func renderMidPhase() throws {
        try render(phaseLabel: "mid", phase: 0.5)
    }

    @Test("Render all 5 exercise 3D scenes to PNG (phase=0.0 / start of cycle)")
    func renderStartPhase() throws {
        try render(phaseLabel: "start", phase: 0.0)
    }

    @Test("Render all 5 exercise 3D scenes to PNG (phase=0.75 / late in cycle)")
    func renderLatePhase() throws {
        try render(phaseLabel: "late", phase: 0.75)
    }

    // MARK: - Helpers

    private func render(phaseLabel: String, phase: CGFloat) throws {
        if ProcessInfo.processInfo.environment["WK_SKIP_3D_SNAPSHOTS"] == "1" {
            return
        }

        // 実機シミュレータでは host の `/tmp` に書ける(Permission に依らない)。
        // 失敗時は NSTemporaryDirectory にフォールバック。
        let primary = URL(fileURLWithPath: "/tmp/3d-sample", isDirectory: true)
        let fallback = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("3d-sample", isDirectory: true)

        let outputDir = (try? makeDir(primary)) ?? (try? makeDir(fallback))
        guard let outputDir else {
            Issue.record("Failed to create output directory")
            return
        }

        for kind in ExerciseAnimationKind.allCases {
            let url = outputDir.appendingPathComponent("\(kind.rawValue)-\(phaseLabel).png")
            try renderPNG(kind: kind, phase: phase, to: url)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }

        NSLog("[3d-sample/\(phaseLabel)] wrote PNGs to: \(outputDir.path)")
    }

    private func makeDir(_ url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let probe = url.appendingPathComponent(".probe")
        try Data().write(to: probe)
        try? FileManager.default.removeItem(at: probe)
        return url
    }

    private func renderPNG(kind: ExerciseAnimationKind, phase: CGFloat, to url: URL) throws {
        let driver = FigureSceneDriver(kind: kind)
        driver.isPaused = true
        driver.applyPose(at: phase)

        // 背景を不透明白に置き換え(driver は clear だが、テスト出力 PNG では
        // SCNRenderer の透過合成が黒になることがあるため明示的に色を指定)。
        driver.scene.background.contents = UIColor(white: 0.96, alpha: 1.0)

        // 描画: SCNRenderer によるオフスクリーン描画。
        // SCNView.snapshot() はホストウィンドウ無しのテストで不安定なため使わない。
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(
                domain: "ExerciseScene3DSnapshotTests",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Metal device unavailable"]
            )
        }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = driver.scene
        renderer.pointOfView = driver.cameraNode

        let size = CGSize(width: 800, height: 500)
        let img = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)

        guard let png = img.pngData() else {
            throw NSError(
                domain: "ExerciseScene3DSnapshotTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG for \(kind)"]
            )
        }
        try png.write(to: url, options: .atomic)
    }
}

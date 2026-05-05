// MARK: - ExerciseAnimationSnapshotTests
// プロトタイプ用の使い捨てスナップショットテスト。
// `ImageRenderer` で 5 種目の動作アニメ中間ポーズを PNG に書き出す。
// 通常テスト実行から除外したい場合は `WK_SKIP_ANIM_SNAPSHOTS=1` を立てる。

import Foundation
import SwiftUI
import Testing
@testable import WorkoutKit

@MainActor
@Suite("ExerciseAnimationSnapshot")
struct ExerciseAnimationSnapshotTests {

    /// 各種目を中間ポーズで PNG 出力。
    /// 出力先候補:
    ///   1. `/tmp/anim-proto/` (host の `/tmp`、Simulator から書き込めることが多い)
    ///   2. 失敗時は `NSTemporaryDirectory()` にフォールバック(ログに絶対パスを残す)
    @Test("Render all 5 exercise animations to PNG")
    func renderAll() throws {
        if ProcessInfo.processInfo.environment["WK_SKIP_ANIM_SNAPSHOTS"] == "1" {
            return
        }

        let primary = URL(fileURLWithPath: "/tmp/anim-proto", isDirectory: true)
        let fallback = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("anim-proto", isDirectory: true)

        let outputDir = (try? makeDir(primary)) ?? (try? makeDir(fallback))
        guard let outputDir else {
            Issue.record("Failed to create output directory in either /tmp or NSTemporaryDirectory")
            return
        }

        for kind in ExerciseAnimationKind.allCases {
            let url = outputDir.appendingPathComponent("\(kind.rawValue).png")
            try renderPNG(kind: kind, phase: 0.5, to: url)

            // 既存ファイルが書けたか軽く確認。
            #expect(FileManager.default.fileExists(atPath: url.path))
        }

        // ホスト側からこのパスを `cp` で持ち出すため、絶対パスをログに残す。
        // (Logger は subsystem 違いになるので NSLog でいい)
        NSLog("[anim-proto] wrote PNGs to: \(outputDir.path)")
    }

    // MARK: - Helpers

    private func makeDir(_ url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        // 書き込み権限の確認。
        let probe = url.appendingPathComponent(".probe")
        try Data().write(to: probe)
        try? FileManager.default.removeItem(at: probe)
        return url
    }

    private func renderPNG(kind: ExerciseAnimationKind, phase: CGFloat, to url: URL) throws {
        // TimelineView の中ではなく、ポーズを直接描く Canvas で静的にレンダリング。
        let pose = kind.pose(phase: phase)
        let view = StaticPoseSnapshot(pose: pose)
            .frame(width: 800, height: 500)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let cg = renderer.cgImage else {
            throw NSError(
                domain: "ExerciseAnimationSnapshotTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "ImageRenderer returned nil cgImage for \(kind)"]
            )
        }

        let img = UIImage(cgImage: cg)
        guard let png = img.pngData() else {
            throw NSError(
                domain: "ExerciseAnimationSnapshotTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG for \(kind)"]
            )
        }
        try png.write(to: url, options: .atomic)
    }
}

/// `ExerciseAnimationView` 本体は TimelineView を含むのでスナップショット用に
/// シンプルな静的版を別に持つ(プロト目的: テスト専用)。
private struct StaticPoseSnapshot: View {
    let pose: StickFigurePose

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.12),
                        Color.accentColor.opacity(0.03),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            Canvas { context, size in
                var ctx = context
                StickFigure.draw(
                    pose,
                    in: &ctx,
                    size: size,
                    color: Color(white: 0.18)
                )
            }
            .padding(16)
        }
    }
}

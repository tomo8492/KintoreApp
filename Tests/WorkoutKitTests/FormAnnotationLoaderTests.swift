// MARK: - FormAnnotationLoaderTests
// CLAUDE.md §1.1 F-02 / §11.4 準拠。
// AnnotatedFormView に渡る FormAnnotationSet の JSON
// (Resources/FormAnnotations/<slug>-annotations.json)が正しくデコードでき、
// 座標が正規化範囲 [0, 1] に収まっていることを Swift Testing で凍結する。
//
// バンドル内 resource の解決はテスト時に環境差が出るため、
// ExerciseAnnotationLoaderTests と同じく #filePath からリポジトリ相対で
// JSON を直接読む方針(unit test の純粋性を優先)。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("FormAnnotationLoader")
struct FormAnnotationLoaderTests {

    /// Tests/WorkoutKitTests/ から見て、リポジトリルートの
    /// WorkoutKit/Resources/FormAnnotations を絶対パスで返す。
    private static var annotationsDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()       // Tests/WorkoutKitTests/
            .deletingLastPathComponent()       // Tests/
            .deletingLastPathComponent()       // <repo root>
            .appendingPathComponent("WorkoutKit/Resources/FormAnnotations")
    }

    private static func decode(slug: String) throws -> FormAnnotationSet {
        let url = annotationsDir.appendingPathComponent("\(slug)-annotations.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FormAnnotationSet.self, from: data)
    }

    @Test("barbell-back-squat は start + bottom の 2 フレームを持つ")
    func decodesBarbellBackSquat() throws {
        let set = try Self.decode(slug: "barbell-back-squat")
        #expect(set.slug == "barbell-back-squat")
        #expect(set.frames.count == 2)
        #expect(set.frames.map(\.id) == ["start", "bottom"])
    }

    @Test("座標・labelKey・assetName が代表種目の全フレームで妥当な形式に収まる")
    func coordinatesAndFieldsAreValid() throws {
        // barbell-bench-press(2 フレーム)、reverse-lunge(2 フレーム)、
        // sumo-deadlift(1 フレーム)、wrist-flexor-stretch(1 フレーム)を代表として検査する。
        let slugs = [
            "barbell-back-squat",
            "push-up",
            "barbell-bench-press",
            "reverse-lunge",
            "sumo-deadlift",
            "wrist-flexor-stretch"
        ]
        for slug in slugs {
            let set = try Self.decode(slug: slug)
            #expect(set.slug == slug)
            #expect(set.frames.isEmpty == false, "\(slug) has no frames")

            for (index, frame) in set.frames.enumerated() {
                // assetName は `<slug>-<N>` パターン(1-origin、フレーム出現順)。
                let expectedAssetName = "\(slug)-\(index + 1)"
                #expect(frame.assetName == expectedAssetName, "\(slug) frame \(frame.id) assetName=\(frame.assetName)")
                #expect(frame.annotations.isEmpty == false, "\(slug) frame \(frame.id) has no annotations")

                for ann in frame.annotations {
                    #expect((0.0...1.0).contains(ann.position.x), "\(slug) \(frame.id) \(ann.id) position.x")
                    #expect((0.0...1.0).contains(ann.position.y), "\(slug) \(frame.id) \(ann.id) position.y")
                    #expect((0.0...1.0).contains(ann.labelAnchor.x), "\(slug) \(frame.id) \(ann.id) labelAnchor.x")
                    #expect((0.0...1.0).contains(ann.labelAnchor.y), "\(slug) \(frame.id) \(ann.id) labelAnchor.y")
                    #expect(ann.labelKey.isEmpty == false, "\(slug) \(frame.id) \(ann.id) labelKey is empty")
                }
            }
        }
    }

    @Test("push-up のボトムフレームは hand-2 が削除され、アノテーション 3 件になる")
    func pushUpBottomFrameHasThreeAnnotations() throws {
        let set = try Self.decode(slug: "push-up")
        #expect(set.frames.count == 2)
        let bottom = try #require(set.frames.first { $0.id == "bottom" })
        #expect(bottom.annotations.count == 3)
        #expect(bottom.annotations.map(\.id).contains("hand-2") == false)
    }

    @Test("sumo-deadlift / wrist-flexor-stretch は単一フレームで frames.count == 1")
    func singleFrameExercisesDecodeToOneFrame() throws {
        for slug in ["sumo-deadlift", "wrist-flexor-stretch"] {
            let set = try Self.decode(slug: slug)
            #expect(set.frames.count == 1, "\(slug) should have exactly 1 frame")
        }
    }

    @Test("FormAnnotationLoader は未定義 slug に対し nil を返す(冪等)")
    func loaderReturnsNilForUnknownSlug() {
        #expect(FormAnnotationLoader.load(slug: "this-slug-does-not-exist-xyz-7777") == nil)
    }
}

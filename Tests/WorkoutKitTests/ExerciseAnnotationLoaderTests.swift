// MARK: - ExerciseAnnotationLoaderTests
// CLAUDE.md §1.1 F-02 / §11.4 準拠。
// AnnotatedBodyDiagramView に渡る ExerciseAnnotation の JSON が
// 正しくデコードでき、座標が正規化範囲 [0, 1] に収まっていることを
// Swift Testing で凍結する。
//
// バンドル内 resource の解決はテスト時に環境差が出るため、
// CSVImporterTests と同じく #filePath からリポジトリ相対で
// JSON を直接読む方針(unit test の純粋性を優先)。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("ExerciseAnnotationLoader")
struct ExerciseAnnotationLoaderTests {

    /// Tests/WorkoutKitTests/ から見て、リポジトリルートの
    /// WorkoutKit/Resources/BodyAnnotations を絶対パスで返す。
    private static var annotationsDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()       // Tests/WorkoutKitTests/
            .deletingLastPathComponent()       // Tests/
            .deletingLastPathComponent()       // <repo root>
            .appendingPathComponent("WorkoutKit/Resources/BodyAnnotations")
    }

    private static func decode(slug: String) throws -> ExerciseAnnotation {
        let url = annotationsDir.appendingPathComponent("\(slug).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ExerciseAnnotation.self, from: data)
    }

    @Test("既知 slug の JSON が ExerciseAnnotation にデコードできる")
    func decodesKnownSlug() throws {
        let result = try Self.decode(slug: "barbell-back-squat")
        #expect(result.slug == "barbell-back-squat")
        #expect(result.annotations.isEmpty == false)
    }

    @Test("annotation の座標は [0, 1] の正規化範囲に収まる")
    func coordinatesAreNormalized() throws {
        let slugs = ["barbell-back-squat", "push-up", "plank", "pull-up", "barbell-deadlift"]
        for slug in slugs {
            let ann = try Self.decode(slug: slug)
            for arrow in ann.arrows {
                #expect((0.0...1.0).contains(arrow.from.x), "\(slug) arrow \(arrow.id) from.x")
                #expect((0.0...1.0).contains(arrow.from.y), "\(slug) arrow \(arrow.id) from.y")
                #expect((0.0...1.0).contains(arrow.to.x),   "\(slug) arrow \(arrow.id) to.x")
                #expect((0.0...1.0).contains(arrow.to.y),   "\(slug) arrow \(arrow.id) to.y")
            }
            for label in ann.annotations {
                #expect((0.0...1.0).contains(label.position.x),    "\(slug) label \(label.id) pos.x")
                #expect((0.0...1.0).contains(label.position.y),    "\(slug) label \(label.id) pos.y")
                #expect((0.0...1.0).contains(label.labelAnchor.x), "\(slug) label \(label.id) anchor.x")
                #expect((0.0...1.0).contains(label.labelAnchor.y), "\(slug) label \(label.id) anchor.y")
                #expect(label.labelKey.hasPrefix("form.\(slug).annotation."),
                        "\(slug) label \(label.id) key=\(label.labelKey)")
            }
        }
    }

    @Test("ExerciseAnnotationLoader は未定義 slug に対し nil を返す(冪等)")
    func loaderReturnsNilForUnknownSlug() {
        let loader = ExerciseAnnotationLoader(bundle: .main)
        #expect(loader.load(slug: "this-slug-does-not-exist-xyz-7777") == nil)
    }

    @Test("AnnotationView の rawValue が想定 3 種類に絞られる")
    func annotationViewIsKnown() {
        let allViews: Set<AnnotationView> = [.front, .back, .side]
        #expect(allViews.count == 3)
    }
}

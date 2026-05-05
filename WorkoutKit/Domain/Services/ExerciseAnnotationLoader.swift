// MARK: - ExerciseAnnotationLoader
// Resources/BodyAnnotations/<slug>.json をバンドルから遅延読み込みする。
// 全 345 種目分の JSON を一度に読むとメモリと起動時間に響くため、
// 必要になった種目だけ読み、結果はプロセス内で軽くキャッシュする。
//
// MainActor 規約 (CLAUDE.md §-1.6):
//   - 本 loader は non-isolated。SwiftUI から呼ぶ場合は Task で逃がす想定。
//   - キャッシュは internal な NSCache で簡素に。Sendable な値型を返す。
//
// 失敗時の振る舞い:
//   - JSON が存在しない: nil を返す(View 側でフォールバック描画)
//   - JSON が破損している: error を Logger.data に書き、nil を返す
//   - 例外は投げない(View に AppError を晒すと UX が悪化するため)。

import Foundation
import OSLog

final class ExerciseAnnotationLoader: @unchecked Sendable {
    private let bundle: Bundle
    private let cache = NSCache<NSString, CachedEntry>()

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// slug に対応する annotation JSON を返す。
    /// `Resources/BodyAnnotations/<slug>.json` で見つからなければ nil。
    func load(slug: String) -> ExerciseAnnotation? {
        let key = slug as NSString
        if let cached = cache.object(forKey: key) {
            return cached.value
        }

        let value = decodeFromBundle(slug: slug)
        cache.setObject(CachedEntry(value: value), forKey: key)
        return value
    }

    private func decodeFromBundle(slug: String) -> ExerciseAnnotation? {
        // Xcode は `Resources/BodyAnnotations/<slug>.json` を `BodyAnnotations`
        // サブディレクトリ付きで bundle.url(forResource:withExtension:subdirectory:)
        // に渡せばよい。flat resource 化されるケースも考慮し、subdirectory 無しも
        // 続けて試す(Tests bundle や将来の最適化対策)。
        let candidates: [URL?] = [
            bundle.url(forResource: slug, withExtension: "json", subdirectory: "BodyAnnotations"),
            bundle.url(forResource: slug, withExtension: "json")
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ExerciseAnnotation.self, from: data)
            return decoded
        } catch {
            Logger.data.error(
                "Failed to decode annotation for slug=\(slug, privacy: .public): \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    /// テストやプレビュー用に、任意のキャッシュをクリアする。
    func invalidate() {
        cache.removeAllObjects()
    }

    /// NSCache は値型を直接保持できないので、参照型の薄いラッパーで包む。
    private final class CachedEntry: NSObject {
        let value: ExerciseAnnotation?
        init(value: ExerciseAnnotation?) { self.value = value }
    }
}

// MARK: - SchemaV1
// CLAUDE.md §-1.3 準拠。初日から VersionedSchema を明示し、
// 後で破壊的変更を加えるときに V2 へ昇格できるようにする。
// プレリリースでも V1 を勝手に変えない(規約)。

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            WorkoutSession.self,
            ExerciseSet.self,
            Template.self,
        ]
    }
}

// MARK: - KeyPath + Sendable (SwiftData モデル限定)
//
// SwiftData の `@Model` クラス(Exercise / WorkoutSession / Template)は可変
// 参照型のため `Sendable` に適合できない。その結果 `#Predicate` / `@Query` /
// `SortDescriptor` に渡す `KeyPath<Model, _>` が Swift 6 strict concurrency 下で
// 「type 'KeyPath<...>' does not conform to the 'Sendable' protocol」警告を出す
// (Swift 6 言語モードではエラー扱い)。
//
// stored-property への KeyPath は生成後イミュータブルで可変状態を持たず、
// subscript 引数のような非 Sendable な値もキャプチャしないため、スレッドを
// 跨いで共有しても安全。Apple SDK 側で KeyPath が Sendable 化されるまでの
// 橋渡しとして、`PersistentModel` を Root とする KeyPath に限定して
// `@unchecked Sendable` を明示的に表明する。
//
// スコープを `where Root: PersistentModel` に絞っているため、一般の KeyPath
// 全体や `SWIFT_STRICT_CONCURRENCY = complete` 設定そのものには影響しない。
extension KeyPath: @retroactive @unchecked Sendable where Root: PersistentModel {}

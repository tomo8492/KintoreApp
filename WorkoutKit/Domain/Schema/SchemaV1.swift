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

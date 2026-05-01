// MARK: - WorkoutKitMigrationPlan
// CLAUDE.md §-1.3 準拠。V1 のみは stages が空。
// 破壊的変更を加える場合は SchemaV2 を別ファイルで作って schemas / stages に追加する。

import Foundation
import SwiftData

enum WorkoutKitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        [] // V1 のみ。V2 追加時に MigrationStage を書く。
    }
}

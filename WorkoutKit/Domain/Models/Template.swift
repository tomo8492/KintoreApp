// MARK: - Template
// 任意のセッションをテンプレート化して再利用するモデル(F-05)。
// CLAUDE.md §4.2 準拠。主キーは UUID。

import Foundation
import SwiftData

@Model
final class Template {
    @Attribute(.unique) var id: UUID

    var name: String
    /// 含まれる Exercise の slug 配列を JSON 文字列で保持。
    /// 例: `["barbell-back-squat","bench-press"]`
    var exerciseSlugsRaw: String
    /// `Goal.rawValue` を保存。
    var defaultGoalRaw: String
    var createdAt: Date
    /// プリセット(PPL/上下分割/全身)はアプリ同梱、その他はユーザー作成。
    /// ユーザー作成は ProFeature.customTemplates で無制限化される。
    var isUserCreated: Bool

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        exerciseSlugsRaw: String = "[]",
        defaultGoalRaw: String,
        createdAt: Date = .now,
        isUserCreated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.exerciseSlugsRaw = exerciseSlugsRaw
        self.defaultGoalRaw = defaultGoalRaw
        self.createdAt = createdAt
        self.isUserCreated = isUserCreated
    }
}

extension Template {
    var defaultGoal: Goal {
        Goal(rawValue: defaultGoalRaw) ?? .hypertrophy
    }

    /// JSON 文字列から slug 配列を復元する。壊れていれば空配列を返す。
    var exerciseSlugs: [String] {
        guard let data = exerciseSlugsRaw.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
}

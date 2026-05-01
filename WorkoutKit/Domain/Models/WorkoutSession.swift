// MARK: - WorkoutSession
// CLAUDE.md §4.2 準拠。1回のワークアウト実行(または手動ログ)に対応。
// 主キーは UUID(端末固有・衝突しない、§-1.2)。

import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID

    // --- 時刻 ---------------------------------------------------------
    /// 開始時刻(UTC、§-1.4 規約)。
    var startedAt: Date
    /// 終了時刻。実行中は nil。
    var finishedAt: Date?
    /// セッション開始時の TimeZone 識別子(海外移動でズレないため、§-1.4)。
    var timeZoneIdentifier: String

    // --- 入力 ---------------------------------------------------------
    var notes: String
    /// `Goal.rawValue` を保存。
    var goalRaw: String

    // --- 構成(F-01b) ------------------------------------------------
    var includesWarmup: Bool
    var includesCooldown: Bool

    // --- 種別フラグ ---------------------------------------------------
    /// Builder ウィザード経由か、後付けの手動ログ(F-04 / Issue #88)か。
    /// true の場合は ProFeature.manualEntry が必要。
    var isManualEntry: Bool

    // --- 関連 ---------------------------------------------------------
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.session)
    var sets: [ExerciseSet] = []

    // MARK: - Init

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        finishedAt: Date? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        notes: String = "",
        goalRaw: String,
        includesWarmup: Bool = true,
        includesCooldown: Bool = true,
        isManualEntry: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.notes = notes
        self.goalRaw = goalRaw
        self.includesWarmup = includesWarmup
        self.includesCooldown = includesCooldown
        self.isManualEntry = isManualEntry
    }
}

extension WorkoutSession {
    var goal: Goal {
        Goal(rawValue: goalRaw) ?? .hypertrophy
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}

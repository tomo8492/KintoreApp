// MARK: - ExerciseSet
// 1セット分の実行記録。CLAUDE.md §4.2 準拠。
// 重量は kg、距離は m、時刻は UTC で必ず内部単位を保持する(§-1.4)。

import Foundation
import SwiftData

@Model
final class ExerciseSet {
    @Attribute(.unique) var id: UUID

    /// セッション内での並び順(0始まり)。
    var order: Int
    /// `SessionSection.rawValue` を保存。Builder の3部構成で振り分けに使う。
    var sectionRaw: String

    // --- 数値(必ず内部単位で保存) -----------------------------------
    /// 回数。時間ベースの種目では 0 を許容(代わりに durationSeconds を使う)。
    var reps: Int
    /// 重量(kg、§-1.4 内部単位ロック)。表示変換は View 層のみ。
    var weightKg: Double
    /// RPE(Rate of Perceived Exertion、6.0〜10.0 が一般的)。任意。
    var rpe: Double?
    /// インターバル(秒)。
    var restSeconds: Int
    /// 時間ベースの種目用(プランク等、秒)。任意。
    var durationSeconds: Int?

    /// 完了時刻(UTC)。実行中は nil。
    var completedAt: Date?

    // --- 関連 ---------------------------------------------------------
    var exercise: Exercise?
    var session: WorkoutSession?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        order: Int,
        sectionRaw: String = SessionSection.main.rawValue,
        reps: Int = 0,
        weightKg: Double = 0,
        rpe: Double? = nil,
        restSeconds: Int = 60,
        durationSeconds: Int? = nil,
        completedAt: Date? = nil,
        exercise: Exercise? = nil,
        session: WorkoutSession? = nil
    ) {
        self.id = id
        self.order = order
        self.sectionRaw = sectionRaw
        self.reps = reps
        self.weightKg = weightKg
        self.rpe = rpe
        self.restSeconds = restSeconds
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
        self.exercise = exercise
        self.session = session
    }
}

extension ExerciseSet {
    var section: SessionSection {
        SessionSection(rawValue: sectionRaw) ?? .main
    }
}

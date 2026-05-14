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

    // MARK: - 集計 (v1.0 §5-2 AI Coach 用)

    /// CLAUDE.md v1.0 §5-2 の AICoachView 用に「日付」を一語で取れるエイリアス。
    /// 既存 `startedAt` をそのまま返す。
    var date: Date { startedAt }

    /// このセッションで実施した種目数(重複なし)。
    var exerciseCount: Int { exerciseNames.count }

    /// このセッションで実施した種目名(日本語表示、重複なし、順序保持)。
    /// AICoachView のプロンプト生成に使う。Locale に応じて nameJa / nameEn を選ぶ。
    var exerciseNames: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for set in sets.sorted(by: { $0.order < $1.order }) {
            guard let ex = set.exercise else { continue }
            let name = ex.localizedName
            if seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result
    }

    /// 完了済みセット数(`sets.count` のエイリアス)。
    /// `nil` 状態の completedAt はまだ実装に無いので、現状は全件をカウントする。
    var totalSets: Int { sets.count }

    /// 総ボリューム = Σ (reps × weightKg)。kg 単位。
    /// reps=0 のセット(時間ベース種目など)は計算に含めない。
    var totalVolume: Double {
        sets.reduce(0) { acc, set in
            guard set.reps > 0, set.weightKg > 0 else { return acc }
            return acc + Double(set.reps) * set.weightKg
        }
    }

    /// 前回セッションとの総ボリューム差を「+12kg」「-3kg」「変わらず」のように整形。
    /// 比較対象が nil なら空文字を返す(AICoachView 側で前回比較を省略する)。
    /// CLAUDE.md v1.0 §5-2 の buildPrompt で使う `session.volumeDifferenceText` に相当。
    func volumeDifferenceText(versus previous: WorkoutSession?) -> String {
        guard let previous else { return "" }
        let delta = totalVolume - previous.totalVolume
        if abs(delta) < 0.5 {
            return String(localized: "workout.volume.diff.unchanged",
                          defaultValue: "前回と同じボリューム")
        }
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(Int(delta))kg"
    }
}

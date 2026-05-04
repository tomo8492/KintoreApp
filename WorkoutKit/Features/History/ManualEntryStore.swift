// MARK: - ManualEntryStore
// CLAUDE.md §1.1 F-04 / §-1.4 (内部単位 kg / UTC) / §11.4 NG リスト準拠。
// ManualEntryView の状態保持と保存ロジックを切り出した @Observable Store。
// ManualEntryView.swift と分離するのは、ファイル 300 行ルール (§11.4 行末項目) を守るため。

import Foundation
import SwiftData
import OSLog

// MARK: - ManualEntryStore

@Observable
@MainActor
final class ManualEntryStore {
    /// セッションの開始日時 (ユーザー選択)。常に「今」より前であること。
    var sessionDate: Date

    /// 目的。デフォルトは hypertrophy。WorkoutSession.goalRaw に保存される。
    var goal: Goal = .hypertrophy

    /// メモ。
    var notes: String = ""

    /// セッションの所要時間 (分)。0 = 未計測 (finishedAt = startedAt として保存)。
    /// 旧実装では「60 秒 × 総セット数」で推定していたが、3 時間セッションが
    /// 20 分扱いになるなど集計を汚染するため撤去 (DEBUG_REPORT Critical-4)。
    /// 1 〜 600 分 (10 時間) を許容範囲とする。
    var durationMinutes: Int = 0

    /// 追加された種目 (順序保持)。各種目は 1 行以上の set draft を持つ。
    var drafts: [ManualEntryDraft] = []

    /// 単体テスト / Preview から「現在時刻」を差し替えるためのフック。
    let now: Date

    init(now: Date = .now) {
        self.now = now
        // 既定は「1 時間前」。「今」を選べないよう DatePicker の in: でも制約するが、
        // 初期値も明確に過去にしておくことで「未来を選んでしまう」事故を防ぐ。
        let calendar = HistoryCutoff.defaultCalendar
        self.sessionDate = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
    }

    // MARK: - Mutations

    func addExercises(_ exercises: [Exercise]) {
        for exercise in exercises {
            guard !drafts.contains(where: { $0.slug == exercise.slug }) else { continue }
            drafts.append(
                ManualEntryDraft(
                    slug: exercise.slug,
                    persistentID: exercise.persistentModelID,
                    displayName: Self.displayName(for: exercise),
                    sets: [ManualEntrySetDraft.empty(order: 0)]
                )
            )
        }
    }

    func removeExercise(id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    func addSet(toExerciseID exerciseID: UUID) {
        guard let idx = drafts.firstIndex(where: { $0.id == exerciseID }) else { return }
        let nextOrder = drafts[idx].sets.count
        drafts[idx].sets.append(ManualEntrySetDraft.empty(order: nextOrder))
    }

    func removeSet(exerciseID: UUID, setID: UUID) {
        guard let idx = drafts.firstIndex(where: { $0.id == exerciseID }) else { return }
        drafts[idx].sets.removeAll { $0.id == setID }
        // 種目が残るなら最低 1 行は維持する。完全に消したい場合は removeExercise を使う。
        if drafts[idx].sets.isEmpty {
            drafts[idx].sets.append(ManualEntrySetDraft.empty(order: 0))
        }
    }

    // MARK: - Validation

    var canSave: Bool {
        guard !drafts.isEmpty else { return false }
        // reps == 0 でも duration ベースの種目を許容したいが、手動ログの簡易性を優先し
        // reps > 0 または weight > 0 のセットが 1 つ以上ある種目だけを保存対象にする。
        return drafts.contains { draft in
            draft.sets.contains { $0.reps > 0 || $0.weightKg > 0 }
        }
    }

    var totalSetCount: Int {
        drafts.reduce(0) { $0 + $1.sets.count }
    }

    // MARK: - Save

    /// SwiftData に WorkoutSession + ExerciseSet 群を書き込む。成功すれば作成した
    /// session を返す。`exerciseLookup` は PersistentIdentifier から実 Exercise を解決する
    /// クロージャ (View 側で modelContext.model(for:) を使って実装する)。
    @discardableResult
    func save(
        modelContext: ModelContext,
        exerciseLookup: (PersistentIdentifier) -> Exercise?
    ) -> WorkoutSession? {
        guard canSave else { return nil }

        // 過去日のはずだが、念のため未来日は now にクランプする。
        let startedAt = min(sessionDate, now)
        // durationMinutes == 0 は「未計測」扱い: finishedAt = startedAt とし、
        // チャート集計には所要時間ゼロのデータポイントとして残す
        // (DEBUG_REPORT Critical-4: 自動推定の 60 秒/セットは撤去)。
        let clampedMinutes = max(0, min(durationMinutes, 600))
        let finishedAt = startedAt.addingTimeInterval(TimeInterval(clampedMinutes * 60))

        let session = WorkoutSession(
            startedAt: startedAt,
            finishedAt: finishedAt,
            timeZoneIdentifier: TimeZone.current.identifier,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            goalRaw: goal.rawValue,
            includesWarmup: false,
            includesCooldown: false,
            isManualEntry: true
        )
        modelContext.insert(session)

        var globalOrder = 0
        var savedSetCount = 0
        for draft in drafts {
            guard let exercise = exerciseLookup(draft.persistentID) else {
                Logger.app.warning("manual-entry: exercise not found for slug=\(draft.slug, privacy: .public)")
                continue
            }
            for set in draft.sets where set.reps > 0 || set.weightKg > 0 {
                let entity = ExerciseSet(
                    order: globalOrder,
                    sectionRaw: SessionSection.main.rawValue,
                    reps: set.reps,
                    weightKg: set.weightKg,
                    rpe: set.rpe,
                    restSeconds: 60,
                    completedAt: finishedAt,
                    exercise: exercise,
                    session: session
                )
                modelContext.insert(entity)
                globalOrder += 1
                savedSetCount += 1
            }
        }

        guard savedSetCount > 0 else {
            modelContext.rollback()
            return nil
        }

        do {
            try modelContext.save()
            Logger.app.info("manual-entry: saved \(savedSetCount) sets across \(self.drafts.count) exercises")
            return session
        } catch {
            Logger.app.error("manual-entry: save failed - \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            return nil
        }
    }

    // MARK: - Helpers

    /// 行に出す名前。日本語ロケールでは nameJa を優先、空なら nameEn にフォールバック。
    static func displayName(for exercise: Exercise) -> String {
        let langCode = Locale.current.language.languageCode?.identifier
        if langCode == "ja", !exercise.nameJa.isEmpty {
            return exercise.nameJa
        }
        if !exercise.nameEn.isEmpty {
            return exercise.nameEn
        }
        return exercise.slug
    }
}

// MARK: - Draft types

struct ManualEntryDraft: Identifiable, Hashable {
    var id = UUID()
    let slug: String
    let persistentID: PersistentIdentifier
    let displayName: String
    var sets: [ManualEntrySetDraft]
}

struct ManualEntrySetDraft: Identifiable, Hashable {
    var id = UUID()
    var order: Int
    var reps: Int
    var weightKg: Double
    var rpe: Double?

    static func empty(order: Int) -> ManualEntrySetDraft {
        ManualEntrySetDraft(order: order, reps: 10, weightKg: 0, rpe: nil)
    }
}

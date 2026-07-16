// MARK: - WorkoutInsightGenerator
// CLAUDE.md v0.5 §-1.17 / §11.4 準拠。
//
// Foundation Models Framework(iOS 26+)を使い、当日のワークアウトを
// オンデバイス LLM で 1〜3 行に要約する。
//
// 設計:
//   - iOS 26 未満では `generate(...)` が常に `WorkoutInsightSnapshot.fallback` を返す
//     (`AICoachView` 側で `#available` ガードして呼ばない設計だが、内部でも保険を入れる)
//   - 入力は WorkoutSession + 直前比較データ。プロンプトは日本語固定で、
//     出力スキーマは `WorkoutInsight`(@Generable)で型安全に受け取る
//   - 失敗(モデル未ロード / 推論タイムアウト等)時もフォールバックで返す
//   - 推論は async。SessionStore 終了直後の SessionSummaryView で `.task` から呼ぶ
//
// プロンプト方針(医療助言ガイドライン 1.4.1 準拠):
//   - 「効果的」「最適」等の助言系は許容、断定的な医療表現は禁止
//   - 数値は固定文ではなくモデルに渡し、自然な日本語で言及してもらう

import Foundation
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

/// LLM 推論に渡す入力。SessionSummaryView 側で組み立て。
/// v1.0 §5-2 で示された `buildPrompt(from session: WorkoutSession)` 例に合わせ、
/// `WorkoutInsightInput.from(session:previous:)` ファクトリを別途提供する。
struct WorkoutInsightInput: Sendable, Equatable {
    /// 今日実施した種目名 + セット数 + 総ボリューム(reps × weight)。
    let todayExercises: [ExerciseLine]
    /// 前回同条件セッションがあれば総ボリュームの差分(kg)。
    let volumeDeltaKgVsLastTime: Double?
    /// 目的(Builder で選んだもの)。プロンプトのトーン調整用。
    let goalRaw: String

    struct ExerciseLine: Sendable, Equatable {
        let name: String        // 表示用(日本語解決済)
        /// `Exercise.slug`。FormAnnotationLoader でフォーム注釈 JSON を引くためのキー。
        /// デフォルト値を持たせることで、slug を持たない既存の呼び出し元(プレビュー等)を
        /// 壊さずに追加できるようにしている(memberwise init がデフォルト値付き
        /// パラメータを生成するのは `var` のみ。`let` だと init から除外される)。
        var slug: String = ""
        let setCount: Int
        let totalVolumeKg: Double
    }
}

// MARK: - WorkoutSession → WorkoutInsightInput

extension WorkoutInsightInput {

    /// `WorkoutSession`(SwiftData @Model、非 Sendable)から
    /// Sendable な `WorkoutInsightInput` を組み立てるファクトリ。
    ///
    /// MainActor 隔離下で呼び出して値だけ抜き出す:
    /// - `previous` は前回比較用の任意 WorkoutSession(同 goal の最新を渡す等)。
    ///   nil なら `volumeDeltaKgVsLastTime = nil` で構築。
    /// - SessionSummaryView から `WorkoutInsightInput.from(session: session, previous: lastSession)`
    ///   のように呼ぶ想定。
    @MainActor
    static func from(session: WorkoutSession, previous: WorkoutSession? = nil) -> WorkoutInsightInput {
        // 種目ごとに setCount + totalVolume を集計。
        // 同じ exercise が複数 set にまたがるので reduce で集約する。
        // キーは表示名ではなく slug にする(表示名だけでは JP/EN 切替え時や
        // 同名種目で衝突し得るため。slug は Exercise の主キーで安定)。
        var perExercise: [String: (name: String, count: Int, volume: Double)] = [:]
        var order: [String] = []
        for set in session.sets.sorted(by: { $0.order < $1.order }) {
            guard let ex = set.exercise else { continue }
            let slug = ex.slug
            if perExercise[slug] == nil { order.append(slug) }
            let prev = perExercise[slug] ?? (name: ex.localizedName, count: 0, volume: 0)
            let added = (set.reps > 0 && set.weightKg > 0)
                ? Double(set.reps) * set.weightKg
                : 0
            perExercise[slug] = (name: prev.name, count: prev.count + 1, volume: prev.volume + added)
        }

        let lines = order.compactMap { slug -> ExerciseLine? in
            guard let agg = perExercise[slug] else { return nil }
            return ExerciseLine(name: agg.name, slug: slug, setCount: agg.count, totalVolumeKg: agg.volume)
        }

        let delta: Double? = previous.map { session.totalVolume - $0.totalVolume }

        return WorkoutInsightInput(
            todayExercises: lines,
            volumeDeltaKgVsLastTime: delta,
            goalRaw: session.goalRaw
        )
    }
}

enum WorkoutInsightGenerator {

    /// 当日のワークアウトを 3 文に要約する。
    /// iOS 26+ では Foundation Models を使い、未満では fallback を返す。
    static func generate(_ input: WorkoutInsightInput) async -> WorkoutInsightSnapshot {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return await generateWithFoundationModels(input)
        }
        #endif
        Logger.app.info("WorkoutInsight: Foundation Models unavailable, returning fallback")
        return .fallback
    }

    // MARK: - iOS 26+

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private static func generateWithFoundationModels(_ input: WorkoutInsightInput) async -> WorkoutInsightSnapshot {
        do {
            // SystemLanguageModel.default はオンデバイス LLM のデフォルト。
            // LanguageModelSession に prompt を渡して `WorkoutInsight` 型で受け取る。
            let session = LanguageModelSession(
                instructions: """
                あなたはユーザー専属のフィットネスコーチです。
                提示されたワークアウトデータを 1〜3 文の日本語で要約してください。
                必ず以下の 3 フィールドを埋めること:
                - summary: 全体の総評(1 文、敬体)
                - highlight: 今日のハイライト種目に触れる文(1 文)
                - advice: 明日に向けた前向きなアドバイス(1 文)
                医療助言は避け、「○○の傾向」「○○がおすすめ」のようなトーンで書くこと。
                """
            )

            let prompt = buildPrompt(input)
            let response = try await session.respond(
                to: prompt,
                generating: WorkoutInsight.self
            )
            let insight = response.content
            return WorkoutInsightSnapshot(
                summary: insight.summary,
                highlight: insight.highlight,
                advice: insight.advice
            )
        } catch {
            Logger.app.error("WorkoutInsight LLM failed: \(error.localizedDescription, privacy: .public)")
            return .fallback
        }
    }

    @available(iOS 26, *)
    private static func buildPrompt(_ input: WorkoutInsightInput) -> String {
        var lines: [String] = []
        lines.append("目的: \(input.goalRaw)")
        lines.append("今日の種目:")
        for ex in input.todayExercises {
            lines.append("- \(ex.name): \(ex.setCount) セット / 総ボリューム \(Int(ex.totalVolumeKg)) kg")
        }
        if let delta = input.volumeDeltaKgVsLastTime {
            let sign = delta >= 0 ? "+" : ""
            lines.append("前回比較: 総ボリューム \(sign)\(Int(delta)) kg")
        }
        // Phase D-2(キュー連動): フォーム注釈 JSON を持つ種目があれば、
        // その日本語キュー文言を「参考」として添付する。これにより advice が
        // 「膝はつま先方向に」のような具体的な文言を参照しやすくなる。
        // JSON を持たない種目(345種目中まだ一部のみ)は単にスキップされる。
        if let cueContext = buildCueContext(input.todayExercises) {
            lines.append(cueContext)
        }
        return lines.joined(separator: "\n")
    }

    /// 今日実施した種目のうち、最大 `maxExercises` 件について
    /// `FormAnnotationLoader.load(slug:)` でフォーム注釈 JSON を引き、
    /// 見つかった種目ごとに先頭フレームの上位 `maxCuesPerExercise` 件の
    /// キュー文言(`labelKey` を実行時解決した日本語テキスト)を
    /// 「種目名=キュー1・キュー2」の形でまとめる。
    ///
    /// 該当種目が 1 つも無ければ nil を返す(プロンプトに余計な行を足さない)。
    /// FormAnnotationLoader / FormAnnotationSet は純粋な JSON デコードのみで
    /// OS バージョン依存が無いため、iOS 26 未満でも呼び出し自体は安全。
    /// ただしこのメソッド自体は buildPrompt からのみ呼ばれ、buildPrompt は
    /// #if canImport(FoundationModels) / @available(iOS 26, *) の内側にある。
    @available(iOS 26, *)
    private static func buildCueContext(_ exercises: [WorkoutInsightInput.ExerciseLine]) -> String? {
        let maxExercises = 3
        let maxCuesPerExercise = 2

        var parts: [String] = []
        for ex in exercises {
            guard parts.count < maxExercises else { break }
            guard let set = FormAnnotationLoader.load(slug: ex.slug),
                  let firstFrame = set.frames.first else { continue }

            let cueTexts = firstFrame.annotations
                .prefix(maxCuesPerExercise)
                .map { String(localized: String.LocalizationValue($0.labelKey)) }
            guard !cueTexts.isEmpty else { continue }

            parts.append("\(ex.name)=\(cueTexts.joined(separator: "・"))")
        }

        guard !parts.isEmpty else { return nil }
        return "フォームの要点(参考): " + parts.joined(separator: "、")
    }
    #endif
}

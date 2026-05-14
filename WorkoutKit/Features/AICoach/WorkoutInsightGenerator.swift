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
struct WorkoutInsightInput: Sendable, Equatable {
    /// 今日実施した種目名 + セット数 + 総ボリューム(reps × weight)。
    let todayExercises: [ExerciseLine]
    /// 前回同条件セッションがあれば総ボリュームの差分(kg)。
    let volumeDeltaKgVsLastTime: Double?
    /// 目的(Builder で選んだもの)。プロンプトのトーン調整用。
    let goalRaw: String

    struct ExerciseLine: Sendable, Equatable {
        let name: String        // 表示用(日本語解決済)
        let setCount: Int
        let totalVolumeKg: Double
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
        return lines.joined(separator: "\n")
    }
    #endif
}

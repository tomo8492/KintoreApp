// MARK: - WorkoutInsight
// CLAUDE.md v0.5 §-1.17 準拠。
//
// Foundation Models Framework(iOS 26+)向けの構造化出力モデル。
// `@Generable` マクロにより、オンデバイス LLM の出力を型安全に受け取る。
//
// iOS 26 未満の端末では本ファイルそのものは存在するが、`AICoachView` が
// `#available(iOS 26, *)` でガードして表示しないので問題にならない。
// `import FoundationModels` も iOS 26 SDK の availability に従う。

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// セッション完了画面で表示する AI コーチのコメント。
/// - summary: 全体要約(1 文)
/// - highlight: 今日のハイライト種目(1 文)
/// - advice:   明日へのアドバイス(1 文)
///
/// `@Generable` は iOS 26 SDK で初登場のマクロ。canImport ガード下に置き、
/// 古い SDK では未定義になるが、コンパイル単位は `#if canImport(FoundationModels)`
/// で完全に消されるので問題にならない。
#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct WorkoutInsight {
    let summary: String
    let highlight: String
    let advice: String
}
#endif

/// `WorkoutInsight` の Sendable / Codable 表現。Foundation Models 非対応 SDK でも
/// View / Tests がコンパイルできるよう、本構造体は無条件で存在する。
/// LLM 生成失敗時のフォールバック値もこの型で扱う。
struct WorkoutInsightSnapshot: Codable, Hashable, Sendable {
    let summary: String
    let highlight: String
    let advice: String

    static let fallback: WorkoutInsightSnapshot = .init(
        summary: String(localized: "ai-coach.fallback.summary",
                        defaultValue: "今日のワークアウト、お疲れさまでした。"),
        highlight: String(localized: "ai-coach.fallback.highlight",
                          defaultValue: "完了したセットを記録に残しています。"),
        advice: String(localized: "ai-coach.fallback.advice",
                       defaultValue: "明日は十分な休息を取りましょう。")
    )
}

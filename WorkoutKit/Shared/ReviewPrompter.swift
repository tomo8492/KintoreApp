// MARK: - ReviewPrompter
// CLAUDE.md §11 準拠(Apple のレビュー依頼ベストプラクティス:割り込まない・懇願しない)。
//
// App Store レビュー依頼(SKStoreReviewController / StoreKit `requestReview`)の
// 「今出していいか」を判定する純粋ロジックのみを持つ。副作用(実際の呼び出し)は
// SwiftUI の `@Environment(\.requestReview)` 側に委譲し、本 enum は
// Singleton(.shared)クラスを新規に作らずステートレスな static API として提供する。
//
// ポリシー:
//   1. ワークアウトを「完了」(中断ではない)した回数が 2 回以上
//   2. アプリバージョンごとに最大 1 回まで(バージョンが上がれば再度出せる)
//   3. 初回起動から 3 日以上経過(LaunchTrialTracker が書き込む
//      `LaunchTrialTracker.firstLaunchedAtKey` を読み取り専用で再利用する)
//
// 呼び出し側(View)の役割:
//   - ワークアウト完了時に `recordFinishedSession()` を呼ぶ
//   - `shouldPrompt()` が true なら `@Environment(\.requestReview)` を実行し、
//     直後に `recordPrompted()` を呼んで「このバージョンでは出した」と記録する

import Foundation
import OSLog

@MainActor
enum ReviewPrompter {

    // MARK: - Constants

    /// レビュー依頼の前提となる「完了セッション数」の閾値。
    static let requiredFinishedSessionCount = 2

    /// 初回起動からレビュー依頼が許可されるまでの最短日数。
    static let minimumDaysSinceFirstLaunch = 3

    /// 完了セッション累計数を保存する UserDefaults キー。
    static let finishedSessionCountKey = "review.finishedSessionCount"

    /// 直近でレビュー依頼を出したアプリバージョンを保存する UserDefaults キー。
    static let lastPromptedVersionKey = "review.lastPromptedVersion"

    // MARK: - Recording

    /// ワークアウトを完了(中断ではない)した直後に呼ぶ。冪等ではなく毎回加算する。
    static func recordFinishedSession(defaults: UserDefaults = .standard) {
        let next = defaults.integer(forKey: finishedSessionCountKey) + 1
        defaults.set(next, forKey: finishedSessionCountKey)
        Logger.app.info("review prompt: finished session recorded (count=\(next, privacy: .public))")
    }

    /// 実際にレビュー依頼(`requestReview` action)を呼び出した直後に呼ぶ。
    static func recordPrompted(
        defaults: UserDefaults = .standard,
        currentVersion: String = ReviewPrompter.currentAppVersion
    ) {
        defaults.set(currentVersion, forKey: lastPromptedVersionKey)
        Logger.app.info("review prompt: recorded as prompted for this version")
    }

    // MARK: - Decision

    /// 現時点でレビュー依頼を出してよいかどうか。
    static func shouldPrompt(
        defaults: UserDefaults = .standard,
        currentVersion: String = ReviewPrompter.currentAppVersion,
        now: Date = Date()
    ) -> Bool {
        let finishedCount = defaults.integer(forKey: finishedSessionCountKey)
        guard finishedCount >= requiredFinishedSessionCount else {
            Logger.app.info("review prompt: skip (not enough finished sessions)")
            return false
        }

        let lastPromptedVersion = defaults.string(forKey: lastPromptedVersionKey) ?? ""
        guard lastPromptedVersion != currentVersion else {
            Logger.app.info("review prompt: skip (already prompted this version)")
            return false
        }

        guard let firstLaunchedAt = defaults.object(forKey: LaunchTrialTracker.firstLaunchedAtKey) as? Date else {
            // 初回起動日が未記録(通常は起動直後に LaunchTrialTracker が書き込む)。
            // 保守的に未確定として見送る。
            Logger.app.info("review prompt: skip (first-launch date unknown)")
            return false
        }
        let daysSinceFirstLaunch = Int(now.timeIntervalSince(firstLaunchedAt) / 86_400)
        guard daysSinceFirstLaunch >= minimumDaysSinceFirstLaunch else {
            Logger.app.info("review prompt: skip (too soon since first launch)")
            return false
        }

        Logger.app.info("review prompt: eligible")
        return true
    }

    // MARK: - Helpers

    /// 現在のアプリバージョン(CFBundleShortVersionString)。取得できない場合は空文字。
    static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

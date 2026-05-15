// MARK: - StepsMistakesScreenshotTests
// CLAUDE.md §1.1 F-02 / §11.4(NG リストから除外: XCUITest は XCTest 必須)。
// ExerciseDetailView に新設した「ステップ番号カード」と「よくある間違いカード」
// を視覚確認するための UI テスト。bench-press / squat / deadlift / pull-up / plank
// の 5 種目に絞ってスクリーンショットを取り、xcresult のアタッチメントとして残す。
//
// ホスト側からは `xcrun xcresulttool export attachments ...` で
// /tmp/steps-mistakes/ に PNG を取り出す前提(README で運用)。

import XCTest

// Swift 6: XCUI API は @MainActor 隔離 — クラス全体に @MainActor を付ける。
@MainActor
final class StepsMistakesScreenshotTests: XCTestCase {

    private struct Target {
        let slug: String
        /// `ExerciseListView.matches(...)` がヒットする種目固有のフレーズ。
        /// description / introduction にしか登場しない単語を選び、検索結果が 1 件に絞られるようにする。
        let uniquePhrase: String
    }

    private static let targets: [Target] = [
        .init(slug: "barbell-bench-press",  uniquePhrase: "王道複合種目"),  // chest compound
        .init(slug: "barbell-back-squat",   uniquePhrase: "下半身全体を鍛える"), // squat
        .init(slug: "barbell-deadlift",     uniquePhrase: "全身の連動と背面"),  // deadlift
        .init(slug: "pull-up",              uniquePhrase: "広背筋の代表"),     // pull
        .init(slug: "plank",                uniquePhrase: "姿勢維持力"),       // core
    ]

    func testCaptureStepsMistakesScreenshots() throws {
        // 1 launch ごとに完全リセット。Library 検索の状態残りで flaky になるのを防ぐ。
        for target in Self.targets {
            let app = XCUIApplication()
            app.launch()

            let libraryTabJa = app.tabBars.buttons["ライブラリ"]
            let libraryTabEn = app.tabBars.buttons["Library"]
            if libraryTabJa.waitForExistence(timeout: 5) {
                libraryTabJa.tap()
            } else if libraryTabEn.waitForExistence(timeout: 5) {
                libraryTabEn.tap()
            } else {
                XCTFail("Library tab not found")
                return
            }

            try captureDetail(for: target, in: app)
            app.terminate()
        }
    }

    private func captureDetail(for target: Target, in app: XCUIApplication) throws {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field not found before \(target.slug)")
        searchField.tap()
        searchField.typeText(target.uniquePhrase)

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5),
                      "No cell after searching for unique phrase '\(target.uniquePhrase)' "
                      + "(target slug: \(target.slug))")
        firstCell.tap()

        // ScrollView の内容描画と SwiftData @Query が落ち着くのを待つ。
        sleep(2)

        // ステップ + よくある間違いセクションは画面の下半分に出るので、少しスクロールしてから撮る。
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            sleep(1)
        }

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "steps-mistakes-\(target.slug)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

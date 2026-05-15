// MARK: - BackSectionCuesScreenshotTests
// 「後面セクションが空」問題を解決した後の動作確認用スクショ。
// scap / back / hinge / lats / glute / hip(plank) などが
// 後面セクションに正しく振り分けられることを 5 種目で目視確認する。

import XCTest

// Swift 6: XCUI API は @MainActor 隔離 — クラス全体に @MainActor を付ける。
@MainActor
final class BackSectionCuesScreenshotTests: XCTestCase {

    private struct Target {
        let slug: String
        let uniquePhrase: String
    }

    private static let targets: [Target] = [
        .init(slug: "barbell-bench-press", uniquePhrase: "胸・三頭・前部三角筋"),
        .init(slug: "barbell-back-squat",  uniquePhrase: "下半身全体を鍛える"),
        .init(slug: "barbell-deadlift",    uniquePhrase: "全身の連動と背面"),
        .init(slug: "pull-up",             uniquePhrase: "広背筋の代表"),
        .init(slug: "plank",               uniquePhrase: "姿勢維持力"),
    ]

    func testCaptureBackSectionCueScreenshots() throws {
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

        sleep(2)

        // 後面セクションを撮るためにスクロールダウン。
        app.swipeUp()
        sleep(1)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "back-\(target.slug)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

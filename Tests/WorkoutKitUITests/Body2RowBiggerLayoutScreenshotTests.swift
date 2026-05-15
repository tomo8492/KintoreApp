// MARK: - Body2RowBiggerLayoutScreenshotTests
// 2 行レイアウトを VStack(body 上 → comments 下)に変更し、人体図を
// 全幅表示にした最新版を 5 種目で目視確認するためのスクショテスト。
//
// XCTAttachment は xcresult バンドルに記録され、ホスト側で
// xcrun xcresulttool により /tmp/2row-bigger/ に抽出する。

import XCTest

// Swift 6: XCUI API は @MainActor 隔離 — クラス全体に @MainActor を付ける。
@MainActor
final class Body2RowBiggerLayoutScreenshotTests: XCTestCase {

    private struct Target {
        let slug: String
        let uniquePhrase: String
    }

    /// 推奨 5 種目: bench / squat / deadlift / pull-up / plank。
    /// 上半身・下半身・背面・体幹で異なる muscle 強調を覆う。
    private static let targets: [Target] = [
        .init(slug: "barbell-bench-press", uniquePhrase: "胸・三頭・前部三角筋"),
        .init(slug: "barbell-back-squat",  uniquePhrase: "下半身全体を鍛える"),
        .init(slug: "barbell-deadlift",    uniquePhrase: "全身の連動と背面"),
        .init(slug: "pull-up",             uniquePhrase: "広背筋の代表"),
        .init(slug: "plank",               uniquePhrase: "姿勢維持力"),
    ]

    func testCaptureBiggerLayoutScreenshots() throws {
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

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "bigger-\(target.slug)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

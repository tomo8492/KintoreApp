// MARK: - Body2RowLayoutScreenshotTests
// 2 行レイアウト(前面 / 後面)に変更した AnnotatedBodyDiagramView を
// Library 詳細から表示し、各セクションが正しく描画されることを
// 5 種目のスクショで目視確認する。
//
// XCTAttachment は xcresult バンドルに記録され、ホスト側で
// xcrun xcresulttool により /tmp/2row-layout/ に抽出する。

import XCTest

final class Body2RowLayoutScreenshotTests: XCTestCase {

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

    func testCapture2RowLayoutScreenshots() throws {
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
        attachment.name = "2row-\(target.slug)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

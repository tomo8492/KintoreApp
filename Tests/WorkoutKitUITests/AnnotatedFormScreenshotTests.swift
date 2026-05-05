// MARK: - AnnotatedFormScreenshotTests
// AnnotatedFormView (写真 + 吹き出しアノテーション) を 5 種目で視覚確認するための
// プロト用 UI テスト。CompactBodyDiagramScreenshotTests と独立しており、
// アノテーション JSON を更新したときに撮り直すだけの「専用ハーネス」として残す。
// Phase P3 で UI テストを本格化する際に統合 / 削除予定。

import XCTest

final class AnnotatedFormScreenshotTests: XCTestCase {

    private struct Target {
        let slug: String
        /// `descriptionJa` 内に1度しか登場しないフレーズ。
        /// `ExerciseListView.matches(...)` の検索範囲(name / description / slug)に確実にヒットする。
        let uniquePhrase: String
    }

    /// AnnotatedFormView 対応 5 種目。順序はスクショ並べたときの見栄え順
    /// (シンプル → 複合)を意図したもの。
    private static let targets: [Target] = [
        .init(slug: "plank",         uniquePhrase: "姿勢維持力"),
        .init(slug: "push-up",       uniquePhrase: "三角筋前部"),
        .init(slug: "air-squat",     uniquePhrase: "スクワットの基本形"),
        .init(slug: "reverse-lunge", uniquePhrase: "後ろに踏み出すランジ"),
        .init(slug: "burpee",        uniquePhrase: "全身連動を高める自重複合種目"),
    ]

    func testCaptureAnnotatedFormScreenshots() throws {
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

        // 写真の Asset 読み込み + アノテーション描画の安定を待つ。
        sleep(2)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "annotated-\(target.slug)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

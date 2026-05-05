// MARK: - AnnotatedDiagramAllScreenshotTests
// 281 種目の annotation 自動生成カバレッジを目視確認するためのスクショ取得。
// 既存 64 種目とは別カテゴリの代表 10 種目を Library 詳細から拾い、
// 注釈付き解剖図(Pull/Push/Squat/Hinge/Curl/Stretch/Cardio…)が
// 正しいテンプレートで描画されることを担保する。
//
// CompactBodyDiagramScreenshotTests と同形パターン。XCTAttachment は
// xcresult バンドルへ記録され、ホスト側で xcrun xcresulttool により
// /tmp/all-345-annotations/ へ抽出する。

import XCTest

final class AnnotatedDiagramAllScreenshotTests: XCTestCase {

    private struct Target {
        let slug: String
        /// description / introduction にしか出ないユニークなフレーズ。
        let uniquePhrase: String
    }

    /// カテゴリ代表 10 種目。各 template の網羅を意識:
    /// shrug / back_extension / curl / side_bend / jump_squat /
    /// back_extension / curl(spider) / warmup_full / stretch_glute / cardio_punch
    private static let targets: [Target] = [
        .init(slug: "barbell-shrug",          uniquePhrase: "高重量で僧帽筋を狙う"),
        .init(slug: "good-morning",           uniquePhrase: "バーを担いで前傾する"),
        .init(slug: "concentration-curl",     uniquePhrase: "片肘を膝に当てて"),
        .init(slug: "dumbbell-side-bend",     uniquePhrase: "片手ダンベルで腹斜筋"),
        .init(slug: "broad-jump",             uniquePhrase: "前方に大きく跳ぶ"),
        .init(slug: "hyperextension",         uniquePhrase: "45度ベンチで腰と臀部"),
        .init(slug: "spider-curl",            uniquePhrase: "インクラインベンチにうつ伏せ"),
        .init(slug: "world-greatest-stretch", uniquePhrase: "ランジ+回旋+前屈"),
        .init(slug: "frog-stretch",           uniquePhrase: "両膝を広げる股関節"),
        .init(slug: "battle-ropes",           uniquePhrase: "両手でロープを振る"),
    ]

    func testCaptureAllAnnotationDiagrams() throws {
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
        attachment.name = "annot-\(target.slug)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

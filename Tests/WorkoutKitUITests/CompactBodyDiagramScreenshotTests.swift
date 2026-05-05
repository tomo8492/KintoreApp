// MARK: - CompactBodyDiagramScreenshotTests
// プロト用スクリーンショットキャプチャ。tomo に「写真+人体図+説明」が縦に並んだ
// ExerciseDetailView の MVP を見せる目的(本タスクの Deliverables)。
//
// 試験的実装のため、本テストは Phase P3 で UI テストを本格化する際に削除予定。
// XCUITest 規約 (CLAUDE.md §11.4 NG リスト除外) に従い XCTest を使う。

import XCTest

final class CompactBodyDiagramScreenshotTests: XCTestCase {

    private struct Target {
        let slug: String
        /// 検索ボックスに入れる文字列。description / introduction にしか登場しない
        /// 1 種目固有のフレーズを使い、`archer-push-up` などの派生にヒットしないように。
        let uniquePhrase: String
    }

    /// Library のサーチは slug / nameEn / nameJa / descriptionJa などを横断する。
    /// 派生種目(archer-push-up 等)が「プッシュアップ」を suffix に含むため、
    /// description 内にしか出ない単語(例: "三角筋前部")をピンとして使う。
    private static let targets: [Target] = [
        .init(slug: "push-up",             uniquePhrase: "三角筋前部"),
        .init(slug: "air-squat",           uniquePhrase: "スクワットの基本形"),
        .init(slug: "plank",               uniquePhrase: "姿勢維持力"),
        .init(slug: "pull-up",             uniquePhrase: "広背筋の代表"),
        .init(slug: "barbell-bench-press", uniquePhrase: "王道複合"),
    ]

    func testCaptureExerciseDetailScreenshots() throws {
        // 1 回の launch ではナビゲーションスタックや検索フィールドの状態が
        // 残ってしまい、3 ターゲット目以降で flaky になることが分かったため、
        // 各ターゲットごとに app を terminate → launch して完全にリセットする。
        // プロト用スクリーンショットなので速度より再現性を優先。
        for target in Self.targets {
            let app = XCUIApplication()
            app.launch()

            // ライブラリタブへ。
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
        // launch 直後なので検索フィールドは空。フォーカスを当てて即タイプ。
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field not found before \(target.slug)")
        searchField.tap()
        searchField.typeText(target.uniquePhrase)

        // uniquePhrase は description にしか出ない単語なので、検索結果は 1 件のみ。
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5),
                      "No cell after searching for unique phrase '\(target.uniquePhrase)' "
                      + "(target slug: \(target.slug))")
        firstCell.tap()

        // 詳細描画の安定を待つ(ExerciseAnimationView の TimelineView があるので
        // 1秒程度の余裕を入れる。Reduce Motion オフのデフォルトで動く)。
        sleep(2)

        // スクリーンショット → XCTAttachment(後で xcresulttool で抽出)。
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "detail-\(target.slug)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // launch 単位でリセットしているので、戻るやキャンセル操作は不要。
        // app.terminate() は呼び出し側で行う。
    }
}

// MARK: - CompactBodyDiagramScreenshotTests
// プロト用スクリーンショットキャプチャ。tomo に「鍛える筋肉」セクションが
// 上半身/下半身/体幹で異なる筋肉を正しくハイライトしていることを 8 種目で
// 視覚確認するための UI テスト。
//
// Phase P3 で UI テストを本格化する際に削除予定。
// XCUITest 規約 (CLAUDE.md §11.4 NG リスト除外) に従い XCTest を使う。

import XCTest

final class CompactBodyDiagramScreenshotTests: XCTestCase {

    private struct Target {
        let slug: String
        /// description / introduction にしか登場しない 1 種目固有のフレーズ。
        /// Library のサーチは slug / nameEn / nameJa / description を横断するので、
        /// `barbell-curl` のような短い slug を入れると派生種目もヒットしてしまう。
        let uniquePhrase: String
    }

    /// 8 種目: 上半身 4(胸/背中/肩/腕)+ 下半身 3(脚/背面/ふくらはぎ)+ 体幹 1。
    /// 各部位で違う筋肉がハイライトされることをスクショで確認する。
    /// `ExerciseListView.matches(...)` は nameEn / nameJa / descriptionEn /
    /// descriptionJa / slug / slugJa の 6 フィールドだけを見るので、
    /// `introductionJa` 由来のフレーズは効かない。本テストでは必ず
    /// `descriptionJa` の文字列断片で 1 種目に絞り込む。
    private static let targets: [Target] = [
        // 上半身
        .init(slug: "push-up",                 uniquePhrase: "三角筋前部"),       // chest
        .init(slug: "pull-up",                 uniquePhrase: "広背筋の代表"),     // lats
        .init(slug: "dumbbell-shoulder-press", uniquePhrase: "三角筋全体を狙う"),  // deltoids
        .init(slug: "barbell-curl",            uniquePhrase: "二頭筋の代表"),     // biceps
        // 下半身
        .init(slug: "barbell-back-squat",      uniquePhrase: "下半身全体を鍛える"), // quadriceps
        .init(slug: "barbell-deadlift",        uniquePhrase: "全身の連動と背面"),  // lowerBack
        .init(slug: "standing-calf-raise",     uniquePhrase: "腓腹筋を狙う立位"),  // calves
        // 体幹
        .init(slug: "plank",                   uniquePhrase: "姿勢維持力"),      // abs
    ]

    func testCaptureExerciseDetailScreenshots() throws {
        // 1 回の launch でナビゲーション/検索の状態が残ると flaky になるため、
        // 各ターゲットごとに app を terminate → launch して完全リセット。
        // プロト用スクショ取得なので速度より再現性を優先する。
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

        // 詳細画面の描画安定を待つ(SwiftData @Query / Image 読み込み)。
        sleep(2)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "detail-\(target.slug)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

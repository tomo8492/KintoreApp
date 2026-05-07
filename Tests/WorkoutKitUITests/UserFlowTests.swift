// MARK: - UserFlowTests
// 実機テスト前の sanity check 用に、ユーザー目線の主要フローを XCUITest で
// 実行する。各ステップの XCUIScreen.main.screenshot を XCTAttachment に
// 添付し、xcrun xcresulttool export attachments で /tmp/user-flow/ に
// 取り出す。
//
// 4 フロー:
//   1. Today → Builder(Goal/Muscle/Equipment/Time)→ Result → Session
//   2. Library 検索 → 種目詳細(前面・後面ドット)→ YouTube → Paywall
//   3. Settings 重量単位 切替
//   4. History → 手動エントリ → Paywall(8 機能のみ表示)

import XCTest

final class UserFlowTests: XCTestCase {

    // MARK: - Helpers

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP",
        ]
        return app
    }

    /// 名前付きのスクショを attach する。
    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// タブを切り替える。日本語 / 英語両ラベルを試す。
    private func switchTab(ja: String, en: String, in app: XCUIApplication) -> Bool {
        let jaButton = app.tabBars.buttons[ja]
        if jaButton.waitForExistence(timeout: 5) { jaButton.tap(); return true }
        let enButton = app.tabBars.buttons[en]
        if enButton.waitForExistence(timeout: 2) { enButton.tap(); return true }
        return false
    }

    // MARK: - Flow 1: Today → Builder → Session

    func testFlow1_TodayToSession() throws {
        let app = makeApp()
        app.launch()

        // 01: Today タブ起動直後
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 5),
                      "Today tab not found")
        sleep(1)
        snap("flow1-01-today")

        // 02: 「ワークアウトを組む」CTA をタップ
        let cta = app.buttons["ワークアウトを組む"].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "Today CTA not found")
        cta.tap()
        sleep(2)
        snap("flow1-02-builder-goal")

        // 03: Goal step「筋肥大」を選択
        let hyper = app.buttons["筋肥大"].firstMatch
        if hyper.waitForExistence(timeout: 5) { hyper.tap(); sleep(1) }
        snap("flow1-03-goal-selected")

        // 04: 「次へ」で Muscle step
        tapNext(in: app)
        sleep(1)
        snap("flow1-04-builder-muscle")

        // 05: Muscle step。BodyDiagram の hit zone は座標タップになるため、
        //   レガシー list mode に切り替えて「胸」をタップする。
        let listToggle = app.segmentedControls.buttons["リスト"].firstMatch
        if listToggle.waitForExistence(timeout: 3) { listToggle.tap(); sleep(1) }
        let chest = app.buttons["胸"].firstMatch
        if chest.waitForExistence(timeout: 3) { chest.tap(); sleep(1) }
        snap("flow1-05-muscle-chest-selected")

        tapNext(in: app)
        sleep(1)
        snap("flow1-06-builder-equipment")

        // 07: Equipment「自重」
        let bodyweight = app.buttons["自重"].firstMatch
        if bodyweight.waitForExistence(timeout: 3) { bodyweight.tap(); sleep(1) }
        snap("flow1-07-equipment-selected")

        tapNext(in: app)
        sleep(1)
        snap("flow1-08-builder-time")

        // 08: Time step「45 分」
        let t45 = app.buttons.matching(NSPredicate(format: "label CONTAINS '45'")).firstMatch
        if t45.waitForExistence(timeout: 3) { t45.tap(); sleep(1) }
        snap("flow1-09-time-selected")

        // 09: 「ワークアウトを生成」
        let generate = app.buttons["ワークアウトを生成"].firstMatch
        if generate.waitForExistence(timeout: 3) { generate.tap(); sleep(2) }
        snap("flow1-10-result")

        // 10: 結果スクロール
        app.swipeUp()
        sleep(1)
        snap("flow1-11-result-scrolled")

        // 11: 「このメニューで始める」→ SessionView
        let start = app.buttons["このメニューで始める"].firstMatch
        if start.waitForExistence(timeout: 3) {
            start.tap()
            sleep(3)
            snap("flow1-12-session")
        } else {
            // 環境によってはスクロール先まで詰めてから出てくることがある
            app.swipeUp()
            sleep(1)
            let start2 = app.buttons["このメニューで始める"].firstMatch
            if start2.waitForExistence(timeout: 3) {
                start2.tap(); sleep(3); snap("flow1-12-session")
            } else {
                snap("flow1-12-session-not-reached")
            }
        }
    }

    private func tapNext(in app: XCUIApplication) {
        let next = app.buttons["次へ"].firstMatch
        if next.waitForExistence(timeout: 5) { next.tap() }
    }

    // MARK: - Flow 2: Library → Bench Press → YouTube paywall

    func testFlow2_LibraryDetailToYouTubePaywall() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(switchTab(ja: "ライブラリ", en: "Library", in: app))
        sleep(2)
        snap("flow2-01-library-list")

        // 検索フィールドに「ベンチ」入力
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("ベンチプレス")
        sleep(2)
        snap("flow2-02-search-result")

        // 1 件目セルをタップ
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        firstCell.tap()
        sleep(2)
        snap("flow2-03-detail-top")

        // 鍛える筋肉セクション(前面)が見えるはず
        app.swipeUp()
        sleep(1)
        snap("flow2-04-detail-front-section")

        app.swipeUp()
        sleep(1)
        snap("flow2-05-detail-back-section")

        // ステップカード / よくある間違い / 注意点
        for i in 6...8 {
            app.swipeUp()
            sleep(1)
            snap("flow2-0\(i)-detail-scroll")
        }

        // YouTube ボタン → Paywall
        let youtube = app.buttons.matching(NSPredicate(format: "label CONTAINS 'YouTube'")).firstMatch
        if youtube.waitForExistence(timeout: 3) {
            youtube.tap()
            sleep(2)
            snap("flow2-09-youtube-paywall")
        } else {
            snap("flow2-09-youtube-button-missing")
        }
    }

    // MARK: - Flow 3: Settings unit toggle

    func testFlow3_SettingsUnitToggle() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(switchTab(ja: "設定", en: "Settings", in: app))
        sleep(2)
        snap("flow3-01-settings")

        // 重量単位 picker(Menu スタイル)
        // 日本語 ja で kg / lbs (= キログラム / ポンド) が出る想定。
        let kgButton = app.buttons["キログラム (kg)"].firstMatch
        let lbsButton = app.buttons["ポンド (lbs)"].firstMatch
        // セクションを確認するためのスクロール
        app.swipeUp()
        sleep(1)
        snap("flow3-02-settings-scrolled")

        if lbsButton.waitForExistence(timeout: 3) {
            lbsButton.tap()
            sleep(1)
            snap("flow3-03-units-lbs")
        } else if kgButton.waitForExistence(timeout: 2) {
            // 既に kg。Picker が SegmentedPicker か Menu か環境次第。
            snap("flow3-03-units-kg")
        } else {
            snap("flow3-03-units-picker-not-found")
        }

        // ライブラリに移動して反映を確認(重量表示は session 入力で確認するため
        // ここではタブ切替のみで完結)。
        _ = switchTab(ja: "ライブラリ", en: "Library", in: app)
        sleep(2)
        snap("flow3-04-library-after-toggle")

        // 設定に戻って kg にリセット
        _ = switchTab(ja: "設定", en: "Settings", in: app)
        sleep(1)
        if kgButton.waitForExistence(timeout: 3) {
            kgButton.tap()
            sleep(1)
            snap("flow3-05-units-back-to-kg")
        }
    }

    // MARK: - Flow 4: History → Manual entry → Paywall (8 features only)

    func testFlow4_HistoryManualEntryPaywall() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(switchTab(ja: "履歴", en: "History", in: app))
        sleep(2)
        snap("flow4-01-history-empty")

        // 手動エントリボタン(右上 toolbar、または empty state 内)
        let manualEntry = app.buttons["手動でログ"].firstMatch
        if manualEntry.waitForExistence(timeout: 3) {
            manualEntry.tap()
            sleep(2)
            snap("flow4-02-paywall-top")

            // Paywall 機能リスト確認用にスクロール
            app.swipeUp()
            sleep(1)
            snap("flow4-03-paywall-feature-list")

            app.swipeUp()
            sleep(1)
            snap("flow4-04-paywall-bottom")
        } else {
            snap("flow4-02-manual-entry-button-missing")
        }
    }
}

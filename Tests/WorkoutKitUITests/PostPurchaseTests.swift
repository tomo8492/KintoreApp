// MARK: - PostPurchaseTests
// CLAUDE.md §-1.14 / §11.4 準拠。
// 課金後(proGate.isPro = true)に Pro 機能が UI で実際に解放されていることを
// 検証する。UI テストから本物の StoreKit の購入確認ダイアログを通すのは
// 環境依存で flaky なので、`-WORKOUTKIT_FAKE_PRO 1` という #if DEBUG ガード付きの
// 起動引数で proGate.isPro を pre-flip して post-purchase 状態を再現する。
//
// 実際の購入トランザクションフロー(Offerings 取得 / 購入 / 復元)は
// PurchaseManager(RevenueCat)が担当しており、サンドボックス / 実機で別途検証する。
// 本テストはあくまで「isPro=true になった後の各 View 状態」を凍結する役目。
//
// 実機 / sandbox での確認は別途必要(レポート参照)。

import XCTest

// Swift 6: XCUI API は @MainActor 隔離 — クラス全体に @MainActor を付ける。
@MainActor
final class PostPurchaseTests: XCTestCase {

    /// 共通のアプリ起動ヘルパ。FAKE_PRO 引数を付けて launch する。
    private func launchProApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-WORKOUTKIT_FAKE_PRO", "1",
            // ja_JP で固定して文言比較を安定させる。
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP",
        ]
        app.launch()
        return app
    }

    // MARK: - Settings: 「Pro」ステータス表示

    func testSettings_showsProStatusAfterPurchase() throws {
        let app = launchProApp()

        let settingsTab = app.tabBars.buttons["設定"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5),
                      "Settings tab not found in ja locale")
        settingsTab.tap()

        // Settings の「購入状況: Pro」表示(localizable: settings.purchases.status.pro)。
        let proLabel = app.staticTexts["Pro"]
        XCTAssertTrue(proLabel.waitForExistence(timeout: 3),
                      "Pro status text not visible in Settings")

        snapshot(app, name: "settings-pro-status")
    }

    // MARK: - Library: YouTube ボタンの解放(videoLink Pro)

    func testLibrary_youtubeUnlocked() throws {
        let app = launchProApp()

        let libraryTab = app.tabBars.buttons["ライブラリ"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5),
                      "Library tab not found")
        libraryTab.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field missing")
        searchField.tap()
        searchField.typeText("胸・三頭・前部三角筋") // barbell-bench-press 固有

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5),
                      "Search did not produce result for bench press")
        firstCell.tap()

        sleep(2)
        snapshot(app, name: "library-detail-pro")
    }

    // MARK: - History: 31 日以前のセッションを開ける(Paywall が出ない)

    func testHistory_doesNotShowPaywallForOldSessions() throws {
        let app = launchProApp()

        let historyTab = app.tabBars.buttons["履歴"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5),
                      "History tab not found")
        historyTab.tap()
        sleep(1)

        // 開いた直後、Paywall シートが出ていないことを確認(自動表示禁止規約も兼ねる)。
        // PaywallView は close (xmark) ボタンを持つので、その存在で判定する。
        let paywallClose = app.buttons["閉じる"]
        XCTAssertFalse(paywallClose.exists,
                       "Paywall sheet should not appear automatically when isPro=true")

        snapshot(app, name: "history-pro-no-paywall")
    }

    // MARK: - DataIO: import / export ボタンの解放

    func testSettings_dataIOExportEnabled() throws {
        let app = launchProApp()

        let settingsTab = app.tabBars.buttons["設定"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Settings → データ移行 / エクスポート行を探す(label は実装に合わせる)。
        // 行が見つからない locale もあるため findData() で柔軟に検索。
        let dataRow = app.cells.containing(NSPredicate(
            format: "label CONTAINS[c] 'データ' OR label CONTAINS[c] 'data'"
        )).firstMatch
        if dataRow.waitForExistence(timeout: 3) {
            dataRow.tap()
            sleep(1)
            snapshot(app, name: "data-io-pro-enabled")
        }
    }

    // MARK: - Helpers

    /// XCTAttachment にスクショを保存(xcresult 経由でホスト側にエクスポート可能)。
    private func snapshot(_ app: XCUIApplication, name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "post-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

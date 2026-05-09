// MARK: - RecoveryTests
// CLAUDE.md §1.1 F-03 / §-1 / §11 準拠。
//
// 配信前の Sanity:
//  1. terminate / 再起動を繰り返してもアプリが立ち上がり、Today タブが
//     反応する(SceneStorage 復元の有無は端末に任せる)
//  2. ホーム押下 → 復帰でタブバーが健在(scenePhase round-trip でクラッシュしない)
//  3. History 空状態の view が描画され、タブ切替で壊れない
//
// 制限事項:
//  - SessionView の SceneStorage 復元そのものは XCUITest では信頼性が低い
//    (`app.terminate()` が test runner を不安定にする既知挙動)。
//    SessionStore 内部の状態機械は WorkoutKitTests/SessionStoreTests で
//    別途凍結済み。本ファイルは「クラッシュ無し」のスモークに絞る。

import XCTest

final class RecoveryTests: XCTestCase {

    // MARK: - Helpers

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP",
        ]
        return app
    }

    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func switchTab(ja: String, en: String, in app: XCUIApplication) -> Bool {
        let jaButton = app.tabBars.buttons[ja]
        if jaButton.waitForExistence(timeout: 5) { jaButton.tap(); return true }
        let enButton = app.tabBars.buttons[en]
        if enButton.waitForExistence(timeout: 2) { enButton.tap(); return true }
        return false
    }

    // MARK: - 1. Terminate + relaunch smoke

    /// `app.terminate()` → `app.launch()` を 1 回繰り返してもクラッシュ無し、
    /// タブバーが復帰することを凍結する。SceneStorage の中身復元までは
    /// XCUITest からは信頼性高く確認できないため、ここでは「再起動が成立する」
    /// 一点のみ凍結する。SessionStore の snapshot encode / decode は
    /// SessionStoreTests 側で別途 in-memory に凍結している。
    func testSession_resumeAfterTerminate() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 5),
                      "first launch did not show Today tab")
        snap("recovery-1-01-launched")

        app.terminate()
        sleep(1)
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 10),
                      "Today tab not visible after terminate + relaunch")
        snap("recovery-1-02-relaunched")

        // 履歴タブにも切替できることを確認(navigation graph が健在)
        XCTAssertTrue(switchTab(ja: "履歴", en: "History", in: app),
                      "History tab not reachable after relaunch")
        sleep(1)
        snap("recovery-1-03-history-after-relaunch")
        XCTAssertTrue(switchTab(ja: "今日", en: "Today", in: app),
                      "Today tab not reachable after relaunch round-trip")
    }

    // MARK: - 2. Backgrounding + activate smoke

    /// home key 押下相当 → 数秒待機 → activate でタブバーが健在。
    /// scenePhase の round-trip でクラッシュしないことを凍結する。
    func testSession_resumeAfterBackgrounding() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 5))
        snap("recovery-2-01-launched")

        XCUIDevice.shared.press(.home)
        sleep(3)
        snap("recovery-2-02-backgrounded")

        app.activate()
        sleep(2)
        // タブバー存続を確認(scenePhase 戻りで View tree が壊れていない)
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 5),
                      "tab bar lost after activate")
        snap("recovery-2-03-resumed")

        // タブ切替でクラッシュしないことも確認
        XCTAssertTrue(switchTab(ja: "履歴", en: "History", in: app))
        sleep(1)
        snap("recovery-2-04-history-after-resume")
    }

    // MARK: - 3. History empty state + tab round-trip

    /// 履歴タブを開く / 何もない状態でスクロール / タブ切替して戻る、を
    /// 連続させてもクラッシュしないことを凍結する。
    /// 「履歴」のテキストは tabBar / nav title / 任意の location で出現するため
    /// `staticTexts` に縛らず、`tabBars.buttons["履歴"]` での生存判定で OK。
    func testHistory_emptyStateRenders() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(switchTab(ja: "履歴", en: "History", in: app),
                      "History tab not reachable on first launch")
        sleep(2)
        snap("recovery-3-01-history-tab")

        // タブバー上に History が見えていれば View tree は健在
        XCTAssertTrue(app.tabBars.buttons["履歴"].waitForExistence(timeout: 5),
                      "History tab button missing — view tree may have collapsed")

        // 下方向にスクロール(空状態でも crash しないこと)
        app.swipeUp(); sleep(1); snap("recovery-3-02-history-scrolled-1")
        app.swipeUp(); sleep(1); snap("recovery-3-03-history-scrolled-2")

        // タブ往復
        XCTAssertTrue(switchTab(ja: "今日", en: "Today", in: app))
        sleep(1)
        XCTAssertTrue(switchTab(ja: "履歴", en: "History", in: app))
        sleep(1)
        snap("recovery-3-04-history-revisited")

        // round-trip 後もタブバーから History に到達できる(nav title 文字列に
        // 縛らず、tabBars 経由で生存だけ確認する)
        XCTAssertTrue(app.tabBars.buttons["履歴"].waitForExistence(timeout: 5),
                      "History tab disappeared after round-trip")
    }
}

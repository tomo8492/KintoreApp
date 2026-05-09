// MARK: - AccessibilityVisualTests
// Dynamic Type AccessibilityXXXL と Reduce Motion 設定で
// 主要画面が描画破綻しないことを目視確認するための UI テスト。
//
// 確認事項:
//   - launchArguments に `-UIPreferredContentSizeCategoryName` を渡せば
//     SwiftUI Dynamic Type が反映される(layoutTraits 経由)。
//   - `-AppleReduceMotion 1` を渡せば UIAccessibility.isReduceMotionEnabled が
//     true になり、`@Environment(\.accessibilityReduceMotion)` も true を返す。
//
// XCTAttachment で xcresult に積んだスクショは
//   xcrun xcresulttool export attachments で /tmp/a11y-visual/ に取り出せる。

import XCTest

@MainActor
final class AccessibilityVisualTests: XCTestCase {

    // MARK: - Dynamic Type AccessibilityXXXL

    /// Dynamic Type を最大(AccessibilityXXXL)に固定し、主要画面が
    /// 切り抜け / overlap / 致命的な truncation を起こさないことを目視できるよう
    /// スクショを溜める。文言の自動チェックは行わず、attachmnent をホスト側で確認する。
    func testDynamicType_xxxLarge() throws {
        let app = launchApp(extraArgs: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ])

        // 1. Today (起動直後 = Today タブ想定)
        snap(app, name: "today")

        // 2. Library 一覧 → 最初の種目詳細
        let libraryTab = app.tabBars.buttons["ライブラリ"]
        if libraryTab.waitForExistence(timeout: 5) {
            libraryTab.tap()
            sleep(1)
            snap(app, name: "library-list")
            if app.cells.firstMatch.waitForExistence(timeout: 3) {
                app.cells.firstMatch.tap()
                sleep(2)
                snap(app, name: "library-detail")
                app.navigationBars.buttons.firstMatch.tap()
            }
        }

        // 3. Templates タブ
        let templatesTab = app.tabBars.buttons["テンプレート"]
        if templatesTab.waitForExistence(timeout: 3) {
            templatesTab.tap()
            sleep(1)
            snap(app, name: "templates")
        }

        // 4. History タブ(空でも UI は出る)
        let historyTab = app.tabBars.buttons["履歴"]
        if historyTab.waitForExistence(timeout: 3) {
            historyTab.tap()
            sleep(1)
            snap(app, name: "history")
        }

        // 5. Settings タブ
        let settingsTab = app.tabBars.buttons["設定"]
        if settingsTab.waitForExistence(timeout: 3) {
            settingsTab.tap()
            sleep(1)
            snap(app, name: "settings")
        }
    }

    // MARK: - Reduce Motion

    /// Reduce Motion をオンにして主要画面が描画破綻しないことを確認する。
    /// SessionView / IntervalCountdownView / AutoScrollEffect / BodyDiagramView は
    /// `@Environment(\.accessibilityReduceMotion)` を読んでアニメ抑制する実装。
    /// 本テストは launch して落ちないこと + 主要画面のスクショ取得まで。
    func testReduceMotion() throws {
        let app = launchApp(extraArgs: ["-AppleReduceMotion", "1"])

        // Today
        snap(app, name: "rm-today")

        // Builder へ進むボタンがあれば叩く(無くてもテストは通す)。
        if let startButton = firstButton(app, labels: ["メニューを生成", "Generate workout", "次へ"]) {
            startButton.tap()
            sleep(1)
            snap(app, name: "rm-builder-goal")
        }

        // Library 詳細(BodyDiagramView の transition が抑制されるはず)
        let libraryTab = app.tabBars.buttons["ライブラリ"]
        if libraryTab.waitForExistence(timeout: 3) {
            libraryTab.tap()
            sleep(1)
            if app.cells.firstMatch.waitForExistence(timeout: 3) {
                app.cells.firstMatch.tap()
                sleep(2)
                snap(app, name: "rm-library-detail")
            }
        }
    }

    // MARK: - Helpers

    private func launchApp(extraArgs: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP",
        ]
        app.launchArguments += extraArgs
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "a11y-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func firstButton(_ app: XCUIApplication, labels: [String]) -> XCUIElement? {
        for label in labels {
            let b = app.buttons[label]
            if b.exists { return b }
        }
        return nil
    }
}

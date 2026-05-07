// MARK: - AppStoreScreenshotTests
// CLAUDE.md §-1.15(iPad/iPhone 両対応)準拠。App Store 提出用の
// マーケティングスクリーンショットを 10 シナリオ × 2 ロケール(ja/en)で生成する。
//
// 撮影:
//   - 各テストはアプリを fresh launch → 目的画面まで navigate → XCTAttachment 保存
//   - ロケールは UITEST_LOCALE 環境変数(ja|en)で切替、launchArguments で
//     `-AppleLanguages` / `-AppleLocale` を上書き
//   - デバイスサイズは UITEST_DEVICE_LABEL(iphone-67|iphone-69|ipad-13)で識別
//   - attachment.name が "<device>-<locale>-<scenario>" の形になるので、
//     scripts/generate_app_store_screenshots.sh が xcresulttool でそのまま
//     /tmp/app-store/<device>-<locale>-<scenario>.png に書き出せる
//
// Xcode 17 では Set { ... } 環境変数を直接渡せないので、シェル側で
// `xcodebuild test ... -test-iterations 1 ...` 経由で env を渡す。
//
// XCUITest は依然 XCTest 上で動くため CLAUDE.md §11.4 NG リストの除外対象。

import XCTest

final class AppStoreScreenshotTests: XCTestCase {

    // MARK: - Environment

    /// "ja" or "en"。未設定時は ja(主言語)。
    private var locale: String {
        ProcessInfo.processInfo.environment["UITEST_LOCALE"] ?? "ja"
    }

    /// e.g. "iphone-67" / "iphone-69" / "ipad-13"。未設定時は "device"。
    private var deviceLabel: String {
        ProcessInfo.processInfo.environment["UITEST_DEVICE_LABEL"] ?? "device"
    }

    private var languageCode: String { locale == "en" ? "en" : "ja" }
    private var regionCode: String { locale == "en" ? "en_US" : "ja_JP" }

    /// 各テスト共通の前処理。失敗時に testRunner を継続するため
    /// `continueAfterFailure = false` のままにしておく(navigate 失敗で連鎖 flake を防ぐ)。
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// fresh app に既定の locale 切替引数を足して返す。各テスト先頭で `launch()` する想定。
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        // -AppleLanguages の値は先頭/末尾のカッコ + 配列リテラル形式で渡す。
        app.launchArguments += [
            "-AppleLanguages", "(\(languageCode))",
            "-AppleLocale", regionCode,
            // 1 文字目が数字のスタートアップアニメーションを抑える保険(SwiftUI 標準ではあまり効かないが副作用なし)。
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        return app
    }

    /// scenario の screenshot を XCTAttachment で保存する。
    /// shell 側で `xcresulttool export attachments` するため、
    /// `<device>-<locale>-<scenario>` のファイル名で書き出される。
    private func attach(_ scenario: String, app: XCUIApplication) {
        // app.screenshot() はアプリ範囲のみ、main は OS の status bar も含む。
        // App Store 提出用は OS chrome 込みの全画面が望ましいので main を使う。
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(deviceLabel)-\(locale)-\(scenario)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 指定タブに移動。ja/en の両ラベルを試し、見つかった方を tap する。
    /// 見つからない場合は XCTFail。
    ///
    /// iPhone(compact)は UITabBar 配下に button が並び、accessibility identifier に
    /// ラベル文字列が入る(`app.buttons["今日"]` で引ける)。
    /// 一方 iPad(regular)の TabView は iOS 18 既定で「上部にタブを横並び」で
    /// 描画され、各 button の identifier は SF Symbol(`figure.strengthtraining.traditional`)、
    /// label が "今日" になる。subscript 検索は identifier 優先のためヒットしないので、
    /// 必ず label 述語で引きにいく。
    @discardableResult
    private func tapTab(jaLabel: String, enLabel: String, in app: XCUIApplication) -> Bool {
        let primary = locale == "en" ? enLabel : jaLabel
        let fallback = locale == "en" ? jaLabel : enLabel

        for label in [primary, fallback] {
            // 1) tabBars 配下(iPhone)
            let tabBarButton = app.tabBars.buttons[label]
            if tabBarButton.waitForExistence(timeout: 2), tabBarButton.isHittable {
                tabBarButton.tap()
                return true
            }
            // 2) iPad: label predicate で引く。表示直後 identifier が安定しないことが
            //    あるので waitForExistence ではなく element.firstMatch.exists で確認。
            let labelPredicate = NSPredicate(format: "label == %@", label)
            let byLabel = app.buttons.matching(labelPredicate).firstMatch
            if byLabel.waitForExistence(timeout: 3), byLabel.isHittable {
                byLabel.tap()
                return true
            }
            // 3) 最終手段: identifier 検索(label がそのまま identifier の旧 iPhone 系も拾う)
            let anyButton = app.buttons[label]
            if anyButton.waitForExistence(timeout: 2), anyButton.isHittable {
                anyButton.tap()
                return true
            }
        }
        XCTFail("Tab not found: ja=\(jaLabel) en=\(enLabel)")
        return false
    }

    /// Builder ウィザード冒頭(Today タブ → CTA tap)を共通処理として切り出す。
    private func openBuilder(in app: XCUIApplication) {
        // Today タブはデフォルトで選ばれているはず。念のため明示的に切替えてから CTA を探す。
        _ = tapTab(jaLabel: "今日", enLabel: "Today", in: app)
        let ctaJa = app.buttons["ワークアウトを組む"]
        let ctaEn = app.buttons["Build a workout"]
        let cta = locale == "en" ? ctaEn : ctaJa
        XCTAssertTrue(cta.waitForExistence(timeout: 5),
                      "Builder CTA not found (locale=\(locale))")
        cta.tap()
    }

    /// Builder の primary action (`Next` / `次へ` / `Generate workout` / `ワークアウトを生成`)。
    /// step によって表示が変わるので、まず両ラベルをマッチさせる。
    private func tapBuilderPrimary(in app: XCUIApplication) {
        let candidates = [
            app.buttons["次へ"], app.buttons["Next"],
            app.buttons["ワークアウトを生成"], app.buttons["Generate workout"],
        ]
        for button in candidates where button.exists && button.isHittable {
            button.tap()
            return
        }
        // hittable で取れない (segmented picker や bottomBar 配下) ケースの保険。
        let firstHit = candidates.first(where: { $0.exists })
        firstHit?.tap()
    }

    // MARK: - 1. Today (CTA)

    func test01_today() throws {
        let app = makeApp()
        app.launch()
        // Today はデフォルトタブ。表示が安定するまで少し待つ。
        _ = tapTab(jaLabel: "今日", enLabel: "Today", in: app)
        sleep(2)
        attach("today", app: app)
    }

    // MARK: - 2. Builder Goal step

    func test02_builderGoal() throws {
        let app = makeApp()
        app.launch()
        openBuilder(in: app)
        // 起動直後の goal step。デフォルトは hypertrophy が選択されている。
        sleep(2)
        attach("builder-goal", app: app)
    }

    // MARK: - 3. Builder Muscle step (BodyDiagram)

    func test03_builderMuscle() throws {
        let app = makeApp()
        app.launch()
        openBuilder(in: app)
        sleep(1)
        // Goal は default (hypertrophy) のまま Next で muscle へ。
        tapBuilderPrimary(in: app)
        sleep(2)
        attach("builder-muscle", app: app)
    }

    // MARK: - 4. Builder Result step (生成済み)

    func test04_builderResult() throws {
        let app = makeApp()
        app.launch()
        openBuilder(in: app)

        // goal -> muscle
        sleep(1)
        tapBuilderPrimary(in: app)

        // muscle: List mode に切り替えて、ローカライズされた "胸"/"Chest" を tap する。
        // (BodyDiagram は SVG オーバーレイなので XCUITest からは確実に押しづらい)
        sleep(1)
        let listLabelJa = app.buttons["リスト"]
        let listLabelEn = app.buttons["List"]
        let listButton = locale == "en" ? listLabelEn : listLabelJa
        if listButton.waitForExistence(timeout: 3) {
            listButton.tap()
        }
        sleep(1)
        let chestJa = app.buttons["胸"]
        let chestEn = app.buttons["Chest"]
        let chest = locale == "en" ? chestEn : chestJa
        if chest.waitForExistence(timeout: 3), chest.isHittable {
            chest.tap()
        }
        sleep(1)
        // muscle -> equipment
        tapBuilderPrimary(in: app)

        // equipment: 自重 / Bodyweight を 1 つ選択。
        sleep(1)
        let bwJa = app.buttons["自重"]
        let bwEn = app.buttons["Bodyweight"]
        let bw = locale == "en" ? bwEn : bwJa
        if bw.waitForExistence(timeout: 3), bw.isHittable {
            bw.tap()
        }
        sleep(1)
        // equipment -> time
        tapBuilderPrimary(in: app)

        // time: デフォルト 45 分のまま generate。
        sleep(1)
        tapBuilderPrimary(in: app)
        // generation 完了 + result 描画を待つ。
        sleep(3)
        attach("builder-result", app: app)
    }

    // MARK: - 5. Library exercise detail (bench-press)

    func test05_libraryDetail() throws {
        let app = makeApp()
        app.launch()
        _ = tapTab(jaLabel: "ライブラリ", enLabel: "Library", in: app)
        sleep(1)

        // iPad の NavigationSplitView は portrait だと sidebar が折り畳まれていて
        // searchField / セルが detail pane の "種目を選択" 状態に隠れる。
        // navigationBar 上の ToggleSidebar ボタンを最初に tap して sidebar を出す。
        let toggleSidebar = app.buttons["ToggleSidebar"]
        if toggleSidebar.exists, toggleSidebar.isHittable {
            toggleSidebar.tap()
            sleep(1)
        }

        // ja は description の固有フレーズ、en は nameEn 由来の文字列を打つ。
        let query = locale == "en" ? "barbell bench" : "胸・三頭・前部三角筋"

        // 検索フィールドが見つかれば検索で絞り、見つからない場合はリストを
        // 直接スクロールして bench-press セルを探す。
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText(query)
            sleep(1)
            let firstCell = app.cells.firstMatch
            XCTAssertTrue(firstCell.waitForExistence(timeout: 5),
                          "No exercise cell after search query: \(query)")
            firstCell.tap()
        } else {
            // フィルタなしのリストから「ベンチプレス / Bench Press」を含む行をタップ。
            // 注意: subscript は identifier 検索になるため label 述語で引く。
            let needle = locale == "en" ? "Barbell Bench Press" : "バーベルベンチプレス"
            let predicate = NSPredicate(format: "label == %@", needle)
            let cell = app.staticTexts.matching(predicate).firstMatch
            XCTAssertTrue(cell.waitForExistence(timeout: 5),
                          "No bench-press row found on Library tab")
            cell.tap()
        }
        // 詳細(BodyDiagram + Steps + CommonMistakes)の描画安定を待つ。
        sleep(3)
        attach("library-detail-bench-press", app: app)
    }

    // MARK: - 6. Session in progress

    func test06_session() throws {
        let app = makeApp()
        app.launch()
        openBuilder(in: app)

        // goal -> muscle
        sleep(1)
        tapBuilderPrimary(in: app)

        // muscle: 同上、リスト切替 → 胸/Chest 選択
        sleep(1)
        let listJa = app.buttons["リスト"]
        let listEn = app.buttons["List"]
        let listButton = locale == "en" ? listEn : listJa
        if listButton.waitForExistence(timeout: 3) { listButton.tap() }
        sleep(1)
        let chestJa = app.buttons["胸"]
        let chestEn = app.buttons["Chest"]
        let chest = locale == "en" ? chestEn : chestJa
        if chest.waitForExistence(timeout: 3), chest.isHittable { chest.tap() }
        sleep(1)
        tapBuilderPrimary(in: app)

        // equipment
        sleep(1)
        let bwJa = app.buttons["自重"]
        let bwEn = app.buttons["Bodyweight"]
        let bw = locale == "en" ? bwEn : bwJa
        if bw.waitForExistence(timeout: 3), bw.isHittable { bw.tap() }
        sleep(1)
        tapBuilderPrimary(in: app)

        // time -> generate
        sleep(1)
        tapBuilderPrimary(in: app)
        sleep(3)

        // result: Start session を tap
        let startJa = app.buttons["このメニューで始める"]
        let startEn = app.buttons["Start this workout"]
        let start = locale == "en" ? startEn : startJa
        XCTAssertTrue(start.waitForExistence(timeout: 5),
                      "Start session button not found")
        start.tap()
        sleep(3)
        attach("session", app: app)
    }

    // MARK: - 7. History

    func test07_history() throws {
        let app = makeApp()
        app.launch()
        _ = tapTab(jaLabel: "履歴", enLabel: "History", in: app)
        sleep(2)
        // Charts モードがあれば切替。空履歴でも UI 自体は見せるため呼ぶ。
        // segmented picker のアクセシビリティラベルは Label の text に従うので
        // "Charts" / "推移" 等の片方だけマッチすれば OK。
        let chartsCandidates = [app.buttons["推移"], app.buttons["Charts"]]
        for c in chartsCandidates where c.exists && c.isHittable {
            c.tap()
            break
        }
        sleep(2)
        attach("history-charts", app: app)
    }

    // MARK: - 8. Settings

    func test08_settings() throws {
        let app = makeApp()
        app.launch()
        _ = tapTab(jaLabel: "設定", enLabel: "Settings", in: app)
        sleep(2)
        attach("settings", app: app)
    }

    // MARK: - 9. Paywall

    func test09_paywall() throws {
        let app = makeApp()
        app.launch()
        // Templates タブの "+" ボタン(accessibilityIdentifier=templates.addButton)
        // は customTemplates ゲートを叩くので、無料状態だと PaywallView がシート表示される。
        _ = tapTab(jaLabel: "テンプレート", enLabel: "Templates", in: app)
        sleep(1)
        let addButton = app.buttons["templates.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                      "Templates add button not found")
        addButton.tap()
        // PaywallView が sheet で出るまで待つ。
        sleep(3)
        attach("paywall", app: app)
    }

    // MARK: - 10. Templates list

    func test10_templates() throws {
        let app = makeApp()
        app.launch()
        _ = tapTab(jaLabel: "テンプレート", enLabel: "Templates", in: app)
        // TemplateSeeder が PPL / 上下分割 / 全身 の 3 プリセットを起動時に投入する。
        // SwiftData の reload 完了を待つ。
        sleep(3)
        attach("templates", app: app)
    }
}

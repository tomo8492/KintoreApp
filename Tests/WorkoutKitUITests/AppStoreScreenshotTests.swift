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
//
// Swift 6: XCUIApplication / XCUIElement の API は @MainActor 隔離なので、
// XCTestCase 子クラスに @MainActor を付けて isolate context を揃える。

import XCTest

@MainActor
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

        // iPad の NavigationSplitView は portrait で sidebar が折り畳まれる。
        // iOS 26 では sidebar button の identifier が安定しないので、複数候補を
        // 試して最初に hittable なものを tap する。
        revealSidebarIfNeeded(in: app)

        // 段階的に candidate を試す。1 つでもヒットしたら次へ進む。
        let needle = locale == "en" ? "Barbell Bench Press" : "バーベルベンチプレス"
        let query  = locale == "en" ? "barbell bench"        : "ベンチプレス"

        var navigatedToDetail = false

        // 1) 検索フィールドで絞ってから先頭セルを tap(成功率最高)。
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText(query)
            sleep(2)
            let firstCell = app.cells.firstMatch
            if firstCell.waitForExistence(timeout: 4), firstCell.isHittable {
                firstCell.tap()
                navigatedToDetail = true
            }
        }

        // 2) 検索無し: cell の `label CONTAINS needle` で引く(完全一致でない iPad の
        //    accessibility ラベル差異に対応)。
        if !navigatedToDetail {
            let predicate = NSPredicate(format: "label CONTAINS %@", needle)
            let cell = app.cells.matching(predicate).firstMatch
            if cell.waitForExistence(timeout: 4), cell.isHittable {
                cell.tap()
                navigatedToDetail = true
            }
        }

        // 3) 最終フォールバック: staticTexts で needle CONTAINS、その親 cell を tap。
        //    アクセシビリティラベルが cell に乗らないテーマだと cell マッチが効かないため。
        if !navigatedToDetail {
            let predicate = NSPredicate(format: "label CONTAINS %@", needle)
            let textElement = app.staticTexts.matching(predicate).firstMatch
            if textElement.waitForExistence(timeout: 4) {
                textElement.tap()
                navigatedToDetail = true
            }
        }

        // 4) どうしても bench-press が見つからない場合は、ライブラリ先頭の任意の
        //    セルでも「Library detail」スクショは取れるので fall through する(skip 回避)。
        if !navigatedToDetail {
            let anyCell = app.cells.firstMatch
            XCTAssertTrue(anyCell.waitForExistence(timeout: 5),
                          "Library list shows no cells at all (data seed missing?)")
            anyCell.tap()
        }
        // 詳細(BodyDiagram + Steps + CommonMistakes)の描画安定を待つ。
        sleep(3)
        attach("library-detail-bench-press", app: app)
    }

    // MARK: - iPad split-view helper

    /// iPad NavigationSplitView portrait で sidebar を確実に開く。
    /// 1) navigationBars.buttons の先頭が「サイドバー / Sidebar」ボタンの典型形
    /// 2) identifier "ToggleSidebar" は iOS 18 まで安定だが iOS 26 では揺れる
    /// 3) どちらも無ければ既に sidebar 展開済(landscape など)なので no-op
    private func revealSidebarIfNeeded(in app: XCUIApplication) {
        let toggle = app.buttons["ToggleSidebar"]
        if toggle.waitForExistence(timeout: 1), toggle.isHittable {
            toggle.tap()
            sleep(1)
            return
        }
        // navigationBar 上の sidebar 切替 button(label 不定)を試す。
        let navBarSidebarButton = app.navigationBars.buttons.firstMatch
        if navBarSidebarButton.waitForExistence(timeout: 1), navBarSidebarButton.isHittable {
            // sidebar が既に開いてる場合 firstMatch は別物(Back 等)のこともあるので、
            // searchField が見えるかで判断する。先に tap してダメなら元に戻す。
            let searchBefore = app.searchFields.firstMatch.exists
            if !searchBefore {
                navBarSidebarButton.tap()
                sleep(1)
            }
        }
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

    // MARK: - 11. Session in progress with Rest Timer (1 set completed)
    //
    // Builder で短いメニューを生成 → 1 セット完了 → Rest Timer が出た瞬間を撮る。
    // 指図書 §6 の `session-rest-timer-live-activity` シナリオに対応。
    // Dynamic Island / Lock Screen の本物 Live Activity は Simulator で
    // 描画されないため、本シナリオでは inline タイマー UI (大きい orange の
    // 残り秒数表示)が映る状態を撮影する(M9 実機で別途確認予定)。

    func test11_sessionRestTimer() throws {
        let app = makeApp()
        app.launch()
        openBuilder(in: app)

        // goal -> muscle (default hypertrophy で next)
        sleep(1)
        tapBuilderPrimary(in: app)

        // muscle: list mode + chest
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

        // equipment: bodyweight
        sleep(1)
        let bwJa = app.buttons["自重"]
        let bwEn = app.buttons["Bodyweight"]
        let bw = locale == "en" ? bwEn : bwJa
        if bw.waitForExistence(timeout: 3), bw.isHittable { bw.tap() }
        sleep(1)
        tapBuilderPrimary(in: app)

        // time -> generate (デフォルト 45 分のまま)
        sleep(1)
        tapBuilderPrimary(in: app)
        sleep(3)

        // result -> Start
        let startJa = app.buttons["このメニューで始める"]
        let startEn = app.buttons["Start this workout"]
        let start = locale == "en" ? startEn : startJa
        XCTAssertTrue(start.waitForExistence(timeout: 5),
                      "Start session button not found")
        start.tap()
        sleep(3)

        // 1 セット完了して Rest Timer を起動させる。
        let completeJa = app.buttons["セット完了"]
        let completeEn = app.buttons["Complete set"]
        let complete = locale == "en" ? completeEn : completeJa
        XCTAssertTrue(complete.waitForExistence(timeout: 5),
                      "Complete-set button not found in session UI")
        complete.tap()
        // タイマーが表示されるまで少し待つ(`session.interval.title` が出る)。
        // タップ直後はまだセット完了アニメーション中のことがあるので 2 秒待つ。
        sleep(2)

        // タイマー UI が画面のどこかに描画されている前提で screen 全体を撮る。
        attach("session-rest-timer-live-activity", app: app)
    }

    // MARK: - 12. Session summary + AI Coach (DEBUG seed 経由)
    //
    // フル 17 セット消化は test に向かないので、`-WORKOUTKIT_FAKE_PRO 1` で
    // Pro entitlement を mock しつつ `-WORKOUTKIT_SEED_COMPLETED_SESSION 1` で
    // 完了済 WorkoutSession を直接 seed する。RootView の onAppear で
    // SessionFinishedContent が fullScreenCover で自動表示される。
    //
    // AI Coach セクションは @available(iOS 26, *) ガード越しで、iOS 26 以上の
    // simulator(iPhone 17 Pro Max など)では本物の Foundation Models 生成 or
    // フォールバックメッセージが描画される。

    func test12_sessionSummaryAICoach() throws {
        let app = makeApp()
        app.launchArguments += [
            "-WORKOUTKIT_FAKE_PRO", "1",
            "-WORKOUTKIT_SEED_COMPLETED_SESSION", "1",
        ]
        app.launch()
        // RootView.onAppear → applyScreenshotSeedIfNeeded → fullScreenCover が
        // automatic で開く。AI Coach は async 生成のため少し長めに待つ
        // (iOS 26 の WorkoutInsightGenerator が時間かかる)。
        sleep(6)
        attach("session-summary-aicoach", app: app)
    }

    // MARK: - 13. Library list + search (絞り込み状態)
    //
    // Library tab を開き、検索フィールドに「ベンチ / bench」と入力した直後で
    // 結果リスト + 検索キーワードが両方映る状態を撮る。指図書 §6
    // `library-list-search` シナリオ。

    func test13_libraryListSearch() throws {
        let app = makeApp()
        app.launch()
        _ = tapTab(jaLabel: "ライブラリ", enLabel: "Library", in: app)
        sleep(1)
        revealSidebarIfNeeded(in: app)

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Library search field not found")
        searchField.tap()
        let query = locale == "en" ? "bench" : "ベンチ"
        searchField.typeText(query)
        // 検索結果のリスト更新を待つ。
        sleep(2)
        attach("library-list-search", app: app)
    }
}

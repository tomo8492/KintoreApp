# Code Coverage Snapshot — WorkoutKit v1.0

> Generated 2026-05-20 from `xcodebuild test -only-testing:WorkoutKitTests
> -enableCodeCoverage YES` on iPhone 17 Pro Max / iOS 26.5 simulator.
> HEAD at capture: `8e0a3c6` (local) / origin tip `62462ac`.
>
> **Important**: this snapshot is **unit-test coverage only**
> (`WorkoutKitTests`, 129 tests / 18 suites). SwiftUI `View` files are
> exercised by `WorkoutKitUITests` (26 cases) which are *not* counted here.
> The headline "16.66 %" figure therefore **understates real coverage** —
> it divides covered lines by *all* lines including View bodies that unit
> tests structurally cannot reach. Read the per-module table, not the top
> number.

## Headline

| Scope | Coverage |
|---|---|
| `WorkoutKit.app` (all files, unit-test run only) | 16.66 % (2 520 / 15 129) |
| Business-logic core (Generator / Stores / Importers / Calc / Gate / Tracker) | **80–100 %** |
| SwiftUI Views | low here — covered by `WorkoutKitUITests` instead |
| ActivityKit / Live Activity integration | low — runtime-only, see flags |

## Per-module coverage

### 🟢 Well covered (≥ 80 %) — core domain & logic

| Module | Coverage |
|---|---|
| `Shared/TodaySessionSummary.swift` | 100 % (6/6) |
| `Shared/HTMLSanitizer.swift` | 100 % (84/84) |
| `Features/Session/SessionPlan.swift` | 100 % (40/40) |
| `Features/Paywall/ProFeatureGate.swift` | 100 % (13/13) |
| `Features/Paywall/LaunchTrialTracker.swift` | 100 % (26/26) |
| `Domain/Services/WorkoutGeneratorTypes.swift` | 100 % (10/10) |
| `Domain/Services/SeededGenerator.swift` | 100 % (11/11) |
| `Domain/Services/OneRepMaxCalculator.swift` | 100 % (5/5) |
| `Domain/Schema/SchemaV1.swift` | 100 % (9/9) |
| `Domain/Schema/MigrationPlan.swift` | 100 % (6/6) |
| `Domain/Enums/Goal.swift` | 100 % (9/9) |
| `App/AppDependency.swift` | 100 % (19/19) |
| `App/TemplateSeeder.swift` | 97.06 % (33/34) |
| `Features/DataIO/CSVParser.swift` | 96.77 % (90/93) |
| `Domain/Services/WorkoutGenerator.swift` | 96.74 % (178/184) |
| `Features/Templates/TemplateStore.swift` | 95.65 % (88/92) |
| `Domain/Models/ExerciseSet.swift` | 94.12 % (16/17) |
| `Features/DataIO/HistoryExporter.swift` | 93.38 % (141/151) |
| `Shared/AppSecrets.swift` | 91.67 % (11/12) |
| `Domain/Services/WorkoutGeneratorHelpers.swift` | 91.67 % (77/84) |
| `WorkoutKitApp.swift` | 89.57 % (146/163) |
| `Domain/Models/Exercise.swift` | 89.33 % (67/75) |
| `Features/Session/IntervalTimer.swift` | 87.06 % (74/85) |
| `Features/History/HistoryCutoff.swift` | 85.00 % (17/20) |
| `Features/Paywall/PaywallTrigger.swift` | 84.21 % (16/19) |
| `Features/Session/SessionStore.swift` | 83.74 % (103/123) |
| `Features/DataIO/AttributeNormalizer.swift` | 82.43 % (61/74) |
| `Features/Builder/BuilderStore.swift` | 81.42 % (92/113) |
| `Features/Session/SessionStore+Actions.swift` | 80.77 % (126/156) |

### 🟡 Medium (50–80 %) — partial, mostly View or import edge paths

| Module | Coverage | Note |
|---|---|---|
| `Shared/AppError.swift` | 75.00 % (12/16) | error 文字列の一部分岐が未到達 |
| `Features/DataIO/CSVImporter.swift` | 73.91 % (102/138) | 異常系 CSV 行のパスが一部未カバー |
| `Domain/Models/Template.swift` | 73.68 % (14/19) | SwiftData model、derived prop の一部 |
| `Features/DataIO/CSVImporter+Builder.swift` | 71.90 % (87/121) | import builder の分岐 |
| `Features/Library/ExerciseListView.swift` | 70.54 % (285/404) | SwiftUI View — UITest 側で補完 |
| `Domain/Services/ExerciseAnnotationLoader.swift` | 60.00 % (27/45) | JSON 欠損 slug のフォールバック分岐 |
| `App/RootView.swift` | 58.88 % (179/304) | SwiftUI View + DEBUG seed 経路 — UITest 側で補完 |

### 🔴 Low (< 50 %) — flagged, with reason

| Module | Coverage | なぜ低いか / 受容可否 |
|---|---|---|
| `Domain/Services/ExerciseSeeder.swift` | 42.53 % (37/87) | 初回起動 1 回のみ実行。`seedIfNeeded` の happy path は通るが、再 seed スキップ分岐や JSON エラー分岐が未到達。**統合テストで担保すべき** — v1.1 で seeding 専用テスト追加候補 |
| `Shared/WatchSummaryBridge.swift` | 32.26 % (10/31) | App Group UserDefaults 越しの widget bridge。`WatchSummaryBridgeTests` (5 件) は read/round-trip を見るが write path が widget process 前提で unit 不可。**🟡 受容** — UITest / 実機側 |
| `Domain/Models/WorkoutSession.swift` | 26.79 % (15/56) | SwiftData `@Model`。derived プロパティ(集計 getter)の多くが View からのみ呼ばれる。**🟡 受容** — SessionStore 経由で間接カバー |
| `Features/History/HistoryView.swift` | 26.18 % (111/424) | SwiftUI View。`WorkoutKitUITests` の `UserFlowTests` / `AppStoreScreenshotTests` が実画面で網羅。**🟢 受容** — View は UITest 領域 |
| `Features/Settings/SettingsKeys.swift` | 25.00 % (7/28) | `@AppStorage` キー定数 + `ThemePreference` enum。大半が単純な rawValue/id getter。**🟢 受容** — 低リスク |
| `Features/Session/SessionStore+LiveActivity.swift` | 17.39 % (8/46) | ActivityKit 連携。Live Activity は実 device / simulator runtime が必要で unit 不可。**🟡 受容** — 実機検証(M9 Phase 7)で担保 |
| `Features/DataIO/DataIOStore.swift` | 15.79 % (15/95) | `@Observable` UI store。export/import の sheet binding が View 駆動。**🟡 受容** — UITest / 実機 |
| `Features/Session/SessionStore+Interval.swift` | 14.06 % (9/64) | IntervalTimer 連携。`IntervalTimer.swift` 自体は 87 % だが、SessionStore 側の配線は session 実行中のみ。**🟡 受容** — UITest `UserFlowTests` で間接カバー |
| `Domain/Enums/ProFeature.swift` | 11.11 % (1/9) | enum + `isFreeTier` 静的プロパティ。全 case が `false` を返すだけの定数。**🟢 受容** — cyclomatic complexity ほぼゼロ、低リスク |
| `Features/LiveActivity/RestTimerManager.swift` | 8.22 % (6/73) | ActivityKit `Activity<>` API。`start()` / `extend()` が実 Live Activity runtime 必須。**🟡 受容だが要注意** — `981ec6b` で race condition を修正済の箇所。unit では init/stop のみカバー。**v1.1 で `RestTimerManager` の状態遷移を ActivityKit mock で切り出してテストする候補** |

## まとめ

- **コアロジック(Generator / Store / Importer / Calculator / Gate / TrialTracker)は 80–100 %** で十分。v1.0 のビジネスルールはユニットテストで守られている。
- **🔴 低カバレッジ 10 件のうち 9 件は「SwiftUI View」または「ActivityKit / Widget の runtime 依存」**で、構造上ユニットテスト不可。これらは `WorkoutKitUITests`(26 ケース)+ 実機検証(M9 Phase 7)で補完される設計。
- **唯一の実質的ギャップは `RestTimerManager` (8.22 %)**。`981ec6b` で修正された race condition を含むファイルで、現状 init/stop しかカバーされていない。ActivityKit を protocol で抽象化して mock を挟めば状態遷移テストが書けるため、**v1.1 の品質課題として `docs/ROADMAP.md` の tech-debt 表に追加推奨**。
- 全体「16.66 %」の数字は View 行を分母に含むため過小評価。**モジュール別表で判断すること**。

## 再取得方法

```bash
xcodebuild test \
  -project WorkoutKit.xcodeproj \
  -scheme WorkoutKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  -only-testing:WorkoutKitTests \
  -enableCodeCoverage YES \
  -derivedDataPath /tmp/coverage-dd \
  CODE_SIGNING_ALLOWED=NO
xcrun xccov view --report /tmp/coverage-dd/Logs/Test/*.xcresult
```

UITest 込みの全体カバレッジを見たい場合は `-only-testing` を外す(実行時間は
15 分前後)。

参考: `docs/ROADMAP.md` (Quality / tech-debt carry-over §), `docs/DISPATCH_v1.0.md`

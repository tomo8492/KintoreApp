# Changelog

All notable changes to WorkoutKit are documented in this file.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned (v1.1+)

These items are scoped for future versions and have no UI surface in v1.0.
The full intent is documented in [`docs/ROADMAP.md`](docs/ROADMAP.md).

- **`customExercise`** — user-created exercises in Library (Add / Edit /
  soft-delete). Schema bit `Exercise.isUserCreated` already exists.
- **`sessionPhoto`** — attach photos and structured notes to a session.
- **`appIconVariants`** — Settings → choose alternate App Icon.
- **`watchOSCompanion`** — Apple Watch companion app with Live Activity
  bridge over WatchConnectivity.
- **Localisation** — add `zh-Hans` / `zh-Hant` / `ko` / `fr` / `es` / `de` /
  `pt-BR` to the existing String Catalog.
- **Content** — grow the bundled exercise database from 345 → 600+ entries
  using the same JSON seed format and body-annotation pipeline.
- **CloudKit sync** across the user's own devices (App Group already
  declared in entitlements).
- **iCloud Drive backup** for users who prefer manual snapshots.

## [1.0.0] - 2026-XX-XX

Initial public release.

### Added

#### Core experience
- Builder wizard — Goal → Muscle → Equipment → Time, generates a workout in
  about five seconds. Shuffle and Choose modes for re-rolling or hand-picking
  exercises.
- Session execution — set / rep / weight (kg or lbs) / RPE / rest input,
  per-set log, idle-timer disabled while running, scene-storage snapshot for
  multi-task resume.
- Interval timer with light haptic at 3 s remaining, heavy haptic + system
  sound at 0 s.
- Live Activity on lock screen and Dynamic Island (compact, expanded, and
  minimal layouts), with `Text(timerInterval:countsDown:)` for local rest
  countdown — no per-second push update.

#### Library
- 345 bundled exercises, fully translated in `ja` and `en`.
- Anatomical body diagram (front + back) with primary / secondary muscle
  highlights, per-exercise cue annotations tagged by anatomical side.
- Exercise detail with steps card, common-mistakes card, cautions card.
- Search + four-facet filter (type / primary muscle / equipment / mechanics).

#### History
- List view with persistent sort.
- Calendar view, time-zone-safe cutoff (free tier sees the last 30 days).
- Manual entry editor (Pro).
- Exercise-level set history with weight unit conversion (kg ↔ lbs).

#### Templates
- Three free presets: Push-Pull-Legs, Upper-Lower, Full-body.
- Unlimited custom templates (Pro).

#### Settings
- Weight-unit toggle (kg / lbs) — internal storage stays in kg, display
  conversion only.
- Theme (system / light / dark).
- Restore Purchases via `AppStore.sync()`.
- Language deep-link to iOS Settings.
- About screen with health/fitness disclaimer and acknowledgments.

#### Premium features (Auto-Renewable Subscription)

Subscription Group `workoutkit.premium`, Family Sharing eligible.

| Product ID                  | Period   | Price    | Free trial |
|-----------------------------|----------|----------|------------|
| `workoutkit_monthly_980`    | 1 month  | ¥980     | 7 days     |
| `workoutkit_yearly_4900`    | 1 year   | ¥4 900   | 7 days     |

Entitlement is `premium`, resolved through the RevenueCat SDK.
`Purchases.shared` is only touched inside the `PurchaseManager` wrapper
(CLAUDE.md §11-5 exception). Refunds and family-sharing changes are
caught via both `Purchases.shared.customerInfo()` and RevenueCat's
`Transaction.updates`.

Hard paywall: first 3 calendar days from initial launch are grace
period (tracked by `LaunchTrialTracker`). After the grace window the
paywall is shown once per cold launch until the user subscribes.

| `ProFeature` case   | UX surface                                  |
|---------------------|---------------------------------------------|
| `unlimitedHistory`  | History list / calendar past 30 days        |
| `advancedCharts`    | History → Charts (weekly, monthly, heatmap) |
| `customTemplates`   | Templates → Add / Duplicate / Delete custom |
| `csvImport`         | Settings → Data → Import CSV / JSON         |
| `csvExport`         | Settings → Data → Export CSV                |
| `manualEntry`       | History → Add manual entry                  |

#### AI workout summary (iOS 26+, `AICoachView`)
完了画面の下部に、当日のセッションを 3 行(要約 / ハイライト種目 / 明日への
アドバイス)で要約する AI コーチを差し込む。**Foundation Models Framework** の
オンデバイス LLM を使用し、`@Generable struct WorkoutInsight` で出力を型安全に
受け取る。サーバー送信なし・推論コスト¥0・プライバシー完全保護。
iOS 18–25 では `AICoachView.isSupported == false` で UI 自体が描画されない。

#### Rest Timer Live Activity
既存のセッション進捗用 Live Activity と同一の Widget Bundle に追加で登録される
2 つ目の `ActivityConfiguration`。`SessionStore.completeCurrentSet` から起動し、
`finish()` / `abort()` で能動的に終了。ロック画面と Dynamic Island の両方で
`Text(timerInterval:countsDown:)` によるローカルカウントダウン描画
(毎秒 push なし)。

#### watchOS Smart Stack ウィジェット
`accessoryRectangular` 1 枚で今日の状況(✅ 完了 / 📅 未実施 + 総セット数)を表示。
データは **App Group UserDefaults**(`group.com.tomo.workoutkit`)経由で
`TodaySessionSummary` JSON を読む方式(`WatchSummaryBridge`)。SwiftData を
Widget Extension に直接読ませない設計で、Widget の起動コストを最小化。
iPhone 側は `SessionStore.finish()` / `abort()` 直後にサマリを書き込む。
昨日以前の値は read 時に `.empty` へダウングレードされる。

#### Localization
- 1 257 keys in `Localizable.xcstrings`, fully translated in `ja` + `en`.
- All UI labels, error messages, and accessibility hints localized.
- Stable `accessibilityIdentifier` on key Builder / Session / Settings
  controls so XCUITest is locale-independent.

#### Accessibility
- VoiceOver labels on all interactive controls; Settings unit picker shows
  short visible label ("kg" / "lbs") with full-form VoiceOver description
  ("キログラム" / "Kilograms" etc.) so narrow devices like iPhone SE never
  truncate.
- Dynamic Type honored throughout, with `minimumScaleFactor` on multi-line
  labels.
- Reduce Motion suppresses ProgressView animation interpolation.

### Foundation

These values are locked per CLAUDE.md §-1 and are intentionally immutable
across this release line.

- Bundle ID: `com.tomo.workoutkit`
- App Group: `group.com.tomo.workoutkit`
- Subscription Group: `workoutkit.premium`
- Product IDs: `workoutkit_monthly_980`, `workoutkit_yearly_4900`
- Entitlement: `premium` (via RevenueCat)
- Min iOS: 18.0 (raised from 17.0 to support Live Activities + watchOS Smart Stack)
- Devices: iPhone (Portrait) + iPad (Portrait + Landscape, NavigationSplitView) + Apple Watch (watchOS 11+)
- SwiftData schema: `SchemaV1` (1.0.0) with explicit migration plan
- Internal storage: `appSupport/WorkoutKit.store` (no CloudKit in v1.0)
- No analytics SDK, no crash-reporting SDK, no tracking
- No video files bundled — the app teaches form via illustrations and text,
  per the workout.lol lesson recorded in `CLAUDE.md` §-1
- No `print` in production code (`Logger` everywhere)
- No `.shared` singletons (env-based dependency injection)

### Acknowledgments

- **Body diagram SVG art** is derived from
  [Snouzy/workout-cool](https://github.com/Snouzy/workout-cool) under the
  MIT License. Full attribution and license text are in
  [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). The seed data,
  branding, and server code from workout-cool are not used — only the
  body silhouette and per-muscle SVG paths, normalized and re-themed.

[Unreleased]: https://github.com/tomo8492/KintoreApp/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/tomo8492/KintoreApp/releases/tag/v1.0.0

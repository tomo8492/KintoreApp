# App Review Notes — WorkoutKit v1.0

> This file contains the text we will paste into the **App Review Information →
> Notes** field in App Store Connect, plus a Japanese-language internal copy
> for tomo's own records. The English block is the canonical version that
> goes to the reviewer; the Japanese block exists only as documentation.
>
> All `[YOUR_EMAIL]` and `[YOUR_NAME]` placeholders are resolved at submission
> time per `docs/app-store/urls.md`.

---

## English (paste into App Store Connect)

Hello reviewer — thanks for taking the time. A few quick notes that should
make your review faster and avoid back-and-forth.

### About the app

WorkoutKit is a fully offline strength-training planner and logger. The
user picks a goal, a body part, available equipment, and a time budget,
and the app generates a workout in about five seconds. All 345 bundled
exercises ship with anatomical illustrations, step-by-step guides,
common-mistake notes, and form cues. The app is single-player, runs
without an account, and stores all of its data on-device.

### Demo account

**Not required.** The app has no sign-in screen, no remote backend, and
no user account concept. There is no server we could provision a test
account against. Everything in the screenshots and binary works the
moment the app launches — please install and use it directly.

### In-app purchase (subscription model)

WorkoutKit ships two Auto-Renewable Subscription products in a single
Subscription Group (`workoutkit.premium`, named "WorkoutKit Premium"):

| Product ID                | Period   | Price    | Free trial |
|---|---|---|---|
| `workoutkit_monthly_980`  | 1 month  | ¥980     | 7 days     |
| `workoutkit_yearly_4900`  | 1 year   | ¥4,900   | 7 days     |

Both unlock the same `premium` entitlement. There are no consumables, no
non-consumables, no other products. Sandbox testers will see the StoreKit
Configuration file `WorkoutKit.storekit` referenced in the scheme's Run
action; it mirrors the production product IDs and pricing.

The required disclosures (auto-renewal terms, cancellation path, free
trial conditions, price, period, Subscription Group name, link to Terms
and Privacy) are all visible on the paywall **before** the user can tap
the purchase button. See `PaywallView` (`WorkoutKit/Features/Paywall/`)
for the rendered layout. The Localizable keys are under
`paywall.legal.*` in `Localizable.xcstrings`.

Restore Purchases is implemented (Settings → Restore Purchases) and is
also available directly from the paywall, per Guideline 3.1.1.

Hard paywall: the app is free to use for the first 3 calendar days from
the initial launch (`LaunchTrialTracker`). After that grace window, any
launch will surface the paywall once until either a trial starts or a
subscription is active. Free features (basic workout logging) remain
accessible if the user dismisses the paywall after the grace window —
the app does not lock out core logging.

The Premium feature set is: full history beyond 30 days, advanced charts,
custom templates beyond three, CSV/JSON import, CSV export, manual
session entry, YouTube reference link from each exercise detail, rest
timer Live Activity (lock screen + Dynamic Island), Apple Watch Smart
Stack widget, AI workout summary (iOS 26 and later, on-device inference).

### Payment SDK (RevenueCat)

We use the RevenueCat SDK as a thin wrapper around StoreKit 2 for
subscription state management (`PurchaseManager` in
`WorkoutKit/Features/Paywall/`). RevenueCat receives only the purchase
receipt and an anonymous SDK ID (`$RCAnonymousID:*`); we transmit no
personally identifiable information. RevenueCat's attribution and
analytics features are disabled in our configuration — it is used
solely for sync of entitlement state across devices and for refund /
family-sharing change detection. This is disclosed in section 5 of the
Privacy Policy.

### YouTube link behaviour

This is the most common review question we expect, so we want to flag it
explicitly. Each exercise's detail page has a Premium-gated "YouTube"
button. **It opens an external URL only.** Specifically, the app
constructs `https://www.youtube.com/results?search_query=<exercise-specific query>`
(YouTube's public search URL) and hands it to `Environment(\.openURL)`,
which routes the link to the YouTube app if installed and to Safari
otherwise. The app does not use `WKWebView`, `AVPlayer`, `VideoPlayer`,
`SFSafariViewController`, or any embedding. We do not redistribute,
mirror, or display YouTube content — we just save the user a typing
step. The search queries are generic strings such as "barbell back squat
form" and never reference specific videos, channels, or creators.

### Live Activity / push / notifications

The app uses ActivityKit Live Activities during a running workout
session: progress and the rest-timer countdown appear on the lock
screen and in the Dynamic Island. The Live Activity starts only when
the user taps "Start workout" and ends automatically when the user
finishes or aborts the session — there is no background daemon. The
app does **not** request `UNUserNotificationCenter` authorization and
does not send push notifications. Live Activities are governed by the
separate `ActivityAuthorizationInfo().areActivitiesEnabled` check,
which the app honors silently with a no-op. The rest timer Live
Activity uses `Text(timerInterval:countsDown:)` for local rendering and
does not push per-second updates (this is required by ActivityKit's
update budget for iOS 18).

### Apple Watch widget

WorkoutKit ships a watchOS Smart Stack widget (`accessoryRectangular`)
that shows "today's session at a glance" — completion checkmark, total
sets, exercise count. The widget does **not** require a full Watch
companion app; it reads a small `TodaySessionSummary` JSON blob from
shared App Group UserDefaults (`group.com.tomo.workoutkit`) that the
iPhone writes when a session finishes. No CloudKit, no
WatchConnectivity sessions. If the user has no paired Apple Watch the
widget target is simply not installed.

### AI workout summary (iOS 26 and later)

If the user is on iOS 26 or later, the post-session summary screen
includes a 3-line AI coach card generated by Foundation Models
Framework (on-device LLM, `SystemLanguageModel.default`). The prompt is
in Japanese and asks for a summary / highlight / tomorrow's advice. The
output is bounded by a `@Generable struct WorkoutInsight` so we can
guarantee its shape. No data leaves the device. On iOS 18-25 the card
is not rendered (`AICoachView` early-returns on the availability
guard).

### Health and fitness disclaimer

The app shows form cues and common-mistake notes, but it is explicitly
not medical advice. The About screen and the Terms of Use both state
that users should consult a qualified professional for medical concerns
and should stop training if they feel pain. This satisfies Guideline
1.4.1 framing for general fitness apps.

### Third-party content

The body-diagram SVG illustrations are derived from
[Snouzy/workout-cool](https://github.com/Snouzy/workout-cool) under the
MIT License. Attribution is in `THIRD_PARTY_NOTICES.md` shipped inside
the app bundle and reachable from Settings → About → Acknowledgments.
We do not use workout-cool's exercise data, branding, or server code —
only the SVG silhouettes, normalized and re-themed to our accent color.

### Privacy and Terms

Privacy Policy URL: `https://workoutkit.app/privacy`
Terms of Use URL:   `https://workoutkit.app/terms`

Both are static pages with no analytics. The app collects nothing on
its own, ships no analytics SDKs, and contacts no servers other than
Apple's StoreKit endpoint (via RevenueCat for entitlement sync). The
Privacy Manifest (`PrivacyInfo.xcprivacy`) declares zero tracking and
the Required-Reason API uses documented in CLAUDE.md §-1.9.

### Features intentionally excluded from v1.0

Three Pro feature codes (`customExercise`, `sessionPhoto`,
`appIconVariants`) exist in the source enum but are filtered out of
the v1.0 paywall list and do not have UI surfaces. They are scoped
for v1.1+ as documented in `docs/ROADMAP.md`. The paywall the user
sees in 1.0 lists only the features that are actually implemented, so
there is no risk of over-promising at the point of sale.

### Contact

Developer contact: `[YOUR_EMAIL]`. We respond within one business day.

If anything else needs clarification we are happy to push a fresh
build with extra in-app comments or to answer in this thread.
Thank you again for the review.

— `[YOUR_NAME]`

---

## 日本語(社内記録用、Apple には提出しない)

審査官向けに上の英文を貼り付ける想定。日本語版は tomo の手元用。

### アプリ概要

「目的・部位・器具・時間で 5 秒生成」する完全オフラインの筋トレメニュー
プランナー兼ログ。同梱 345 種目すべてに解剖学イラスト・ステップ手順・
よくある間違い・注意点を付け、ユーザーは特定の本やジムに通わなくても、
正しいフォームを学びながら実行・記録できる。アカウント不要、サーバなし、
データはすべて端末内に閉じている。

### デモアカウントが不要な理由

サインイン画面が存在しない。リモートバックエンドが存在しない。テスト
用 Apple ID を発行しても接続先が無い。インストール直後から全機能が
そのまま動作するため、デモ Apple ID は不要。

### IAP の動作概要(v1.0 サブスク版)

Subscription Group `workoutkit.premium`(表示名 "WorkoutKit Premium")に
Auto-Renewable Subscription 2 種を投入:

| Product ID                | 期間   | 価格    | 無料トライアル |
|---|---|---|---|
| `workoutkit_monthly_980`  | 1 か月 | ¥980   | 7 日間 |
| `workoutkit_yearly_4900`  | 1 年   | ¥4,900 | 7 日間 |

どちらも `premium` Entitlement を解放する同一機能セット。Consumable や
Non-Consumable は無く、第 2 グループも無い。Sandbox は
`WorkoutKit.storekit` でローカル再現可能。Restore Purchase は Settings
と Paywall の両方に置く(Guideline 3.1.1 準拠)。

Apple が要求する開示(自動更新条件、解約手順、トライアル条件、
価格・期間、Subscription Group 名、Terms / Privacy リンク)は
PaywallView の購入ボタンタップ前に必ず可視。Localizable の
`paywall.legal.*` キー群を参照。

ハードペイウォール:初回起動から 3 日間は無料で全機能、4 日目以降は
起動時に 1 回 Paywall を提示(`LaunchTrialTracker`)。3 日経過後でも、
Paywall を閉じれば基本ロギング機能は引き続き使える。コア機能を
ロックアウトはしない設計。

Premium 機能一覧:31 日以前の履歴 / 詳細チャート / カスタム
テンプレート 4 件目以降 / CSV・JSON インポート / CSV エクスポート /
手動セッション入力 / 種目詳細の YouTube 検索リンク / 休憩タイマー
Live Activity / Apple Watch Smart Stack ウィジェット / AI ワークアウト
要約(iOS 26 以降、オンデバイス推論)。

### 課金 SDK(RevenueCat)

`PurchaseManager` で RevenueCat SDK を StoreKit 2 の薄いラッパとして
利用。RevenueCat には購入レシートと匿名 ID(`$RCAnonymousID:*`)のみが
渡り、個人識別情報は送信しない。attribution / analytics は無効化済。
Entitlement 状態の同期・払戻し・ファミリー共有変更の検出にのみ使用。
プライバシーポリシー第 5 条で明示。

### YouTube リンクの扱い(審査時の最頻ポイント)

各種目詳細に Premium 限定の「YouTube」ボタンがある。**外部 URL を開く
だけ**で、`https://www.youtube.com/results?search_query=<クエリ>`
を `Environment(\.openURL)` に渡す。YouTube アプリが入っていれば
そちらで、なければデフォルトブラウザで開く。アプリ内 `WKWebView` /
`AVPlayer` / `VideoPlayer` / `SFSafariViewController` は不使用。
YouTube コンテンツの再配信・ミラー・埋め込みは一切なし。検索クエリ
は "barbell back squat form" のような汎用語で、特定動画 / 特定
クリエイターを参照しない。

### Live Activity / 通知

ActivityKit による Live Activity をセッション実行中のみ起動。
ロック画面 / Dynamic Island に進捗と休憩タイマーを描画する。
ユーザーが「ワークアウトを始める」をタップしたときだけ開始、
完了 / 中断で自動終了。バックグラウンド常駐なし。
`UNUserNotificationCenter` の許可リクエストは出さない、プッシュ
通知も送らない。Live Activity は `ActivityAuthorizationInfo`
が `areActivitiesEnabled` で false なら静かに no-op。
休憩タイマー Live Activity は `Text(timerInterval:countsDown:)`
で端末側ローカル描画。毎秒 push は出さない(iOS 18 の Activity
update 予算制約)。

### Apple Watch ウィジェット

`accessoryRectangular` 1 枚で「今日のセッション状況」(完了マーク・
総セット数・種目数)を Smart Stack に出す。フル Watch アプリは
実装しない。データは App Group UserDefaults
(`group.com.tomo.workoutkit`)経由で iPhone が書く
`TodaySessionSummary` JSON を読むだけ。WatchConnectivity / CloudKit
は不使用。Apple Watch を持っていない場合は単に対象 target がインス
トールされない。

### AI ワークアウト要約(iOS 26 以降)

iOS 26 以上の端末では SessionSummaryView に 3 行の AI コーチカードを
差す。`SystemLanguageModel.default`(オンデバイス LLM)経由で
`@Generable struct WorkoutInsight` を生成。プロンプトは日本語で
summary / highlight / advice の 3 フィールドを要求。データ送信なし。
iOS 18-25 では `AICoachView` の `#available` 早期 return により非表示。

### 健康助言の免責

フォーム cue や注意点を表示するが、医療助言ではない旨を About
画面と利用規約で明記。痛みを感じたら中止、専門家に相談、と
Guideline 1.4.1 の汎用フィットネス枠に収まる文言で記載。

### 第三者コンテンツ

人体図 SVG は MIT ライセンスの workout-cool 由来。
`THIRD_PARTY_NOTICES.md` に帰属表示、Settings → About →
Acknowledgments から閲覧可能。workout-cool の seed データ /
ブランディング / サーバーコードは使っていない、SVG のみ
アクセント色に正規化して再利用。

### Privacy Policy / Terms URL

提出時に確定:`https://workoutkit.app/privacy` /
`https://workoutkit.app/terms`。アナリティクスなし、Apple StoreKit
(RevenueCat 経由)以外への外部通信なし。`PrivacyInfo.xcprivacy`
は tracking 0、Required Reason API 宣言済(CLAUDE.md §-1.9)。

### v1.0 で出荷しない機能

ProFeature enum 内の `customExercise` / `sessionPhoto` /
`appIconVariants` は v1.0 paywall に表示されず、UI も持たない。
v1.1+ 計画は `docs/ROADMAP.md` に明記。Paywall は実装済み機能のみを
列挙するので「実装の無い機能を売りつける」リスクはない。

### 連絡先

開発者連絡先: `[YOUR_EMAIL]`、24 時間以内に返信。

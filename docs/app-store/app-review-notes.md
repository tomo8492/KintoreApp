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

### In-app purchase

WorkoutKit ships one Non-Consumable IAP: `com.tomo.workoutkit.pro.unlock`,
a single one-time purchase that unlocks Pro features for life and is
Family Sharing-eligible. There are no subscriptions, no consumables, and
no second product. Sandbox testers will see the StoreKit Configuration
file `WorkoutKit.storekit` in the scheme's Run action, which mirrors the
production product. Restore Purchases is implemented (Settings → Restore
Purchases) and uses `AppStore.sync()` per Guideline 3.1.1.

The seven Pro features are: full history beyond 30 days, advanced charts,
custom templates beyond three, CSV/JSON import, CSV export, manual
session entry, and a YouTube reference link from each exercise detail.

### YouTube link behaviour

This is the most common review question we expect, so we want to flag it
explicitly. Each exercise's detail page has a Pro-gated "YouTube" button.
**It opens an external URL only.** Specifically, the app constructs
`https://www.youtube.com/results?search_query=<exercise-specific query>`
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
which the app honors silently with a no-op.

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

Both are static pages with no analytics. The app collects nothing,
ships no SDKs, and contacts no servers other than Apple's StoreKit
endpoint for IAP. The Privacy Manifest (`PrivacyInfo.xcprivacy`)
declares zero tracking and the three Required-Reason API uses
documented in CLAUDE.md §-1.9.

### Features intentionally excluded from v1.0

Three Pro feature codes (`customExercise`, `sessionPhoto`,
`appIconVariants`) exist in the source enum but are filtered out of
the v1.0 paywall list and do not have UI surfaces. They are scoped
for v1.1+ as documented in `docs/ROADMAP.md`. The paywall the user
sees in 1.0 lists only the seven features that are actually
implemented, so there is no risk of over-promising at the point of
sale.

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

### IAP の動作概要

`com.tomo.workoutkit.pro.unlock` の Non-Consumable 1 種類のみ。
1 度の買い切りで Pro 機能が永続解放され、ファミリー共有対応。
サブスクリプションなし、消費型なし、第 2 プロダクトなし。
Sandbox テスターはスキームの Run Action にバンドルしてある
`WorkoutKit.storekit` Configuration File を見れば本番と同じ
Product ID で確認可能。Restore Purchase は Settings から
`AppStore.sync()` 経由で実装(Guideline 3.1.1 準拠)。

Pro 機能は 7 項目:31 日以前の履歴 / 詳細チャート / カスタム
テンプレート 4 件目以降 / CSV・JSON インポート / CSV エクスポート /
手動セッション入力 / 種目詳細の YouTube 検索リンク。

### YouTube リンクの扱い(審査時の最頻ポイント)

各種目詳細に Pro 限定の「YouTube」ボタンがある。**外部 URL を開く
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
`https://workoutkit.app/terms`。アナリティクスなし、SDK なし、
Apple StoreKit 以外への外部通信なし。`PrivacyInfo.xcprivacy`
は tracking 0、Required Reason API 3 件のみ宣言(CLAUDE.md §-1.9)。

### v1.0 で出荷しない機能

ProFeature enum 内の `customExercise` / `sessionPhoto` /
`appIconVariants` は v1.0 paywall に表示されず、UI も持たない。
v1.1+ 計画は `docs/ROADMAP.md` に明記。Paywall は実装済みの 7 機能
だけを列挙するので「実装の無い機能を売りつける」リスクはない。

### 連絡先

開発者連絡先: `[YOUR_EMAIL]`、24 時間以内に返信。

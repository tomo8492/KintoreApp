# DISPATCH 指図書 — WorkoutKit v1.0 リリースまでの残作業

> Linux 側エージェント(本セッション)で完了させた範囲と、これ以降に
> **Mac / App Store Connect / RevenueCat dashboard / 物理的な撮影機材** が
> 必要な作業を切り分けて記述する。各タスクは独立した Dispatch worker に
> 渡せる粒度で構成。
>
> **Repo**: `tomo8492/KintoreApp`
> **Base branch**: `claude/init-workoutkit-ios-YHots`(最新は `f7f2b53`)
> **Tag target**: `v1.0.0`(全タスク完了後)

---

## 0. Linux 側で完了済み(本セッション)

push 済み commit:
```
f7f2b53 ci: add macOS GitHub Actions workflow to run xcodebuild test on every push
b876bea release: full Apple 3.1.2 disclosure on hard-paywall footer
a9a83e3 release: tighten Localizable for v1.0 subscription disclosure and watchOS widget
5cedef9 release: align en docs, App Store metadata, and Restore Purchase wiring to v1.0 subscription
060fe40 v1.0: subscription pivot + AI Coach + Rest Timer + watchOS Widget (#4)
```

| カテゴリ | 状態 | 備考 |
|---|---|---|
| EN 法務書類 v1.0 化 | ✅ | docs/legal/{privacy-policy,terms-of-service}.en.md |
| App Store metadata ja/en v1.0 化 | ✅ | docs/app-store/{ja,en}/*.txt |
| App Review Notes v1.0 化 | ✅ | docs/app-store/app-review-notes.md |
| Screenshot 計画 + Apple Watch 枠 | ✅ | docs/app-store/screenshot-captions.md |
| ROADMAP の "one-time purchase" 記述削除 | ✅ | docs/ROADMAP.md |
| Restore Purchase の RevenueCat 経路化(リリースブロッカー修正) | ✅ | AppDependency.purchaseRestorer = PurchaseManager.shared |
| Apple Guideline 3.1.2 完全開示文 | ✅ | hard-paywall.legal.disclaimer / paywall.legal.disclaimer |
| watchOS Widget メッセージ整合 | ✅ | paywall.feature.watch_companion.* |
| CI workflow(macos-15 で xcodebuild test) | ✅ | .github/workflows/test.yml |
| Linux-portable test 13 件の合格証跡 | ✅ | LaunchTrialTracker 8 + WatchSummaryBridge 5 |

---

## 0.1 マイルストーン現況サマリ(2026-05-18 更新)

| ID  | 内容                                | 状態 | 備考                                                                                  |
|-----|------------------------------------|------|---------------------------------------------------------------------------------------|
| M1  | 初回 Mac ビルド検証                | ✅   | WorkoutKitTests 155/155 グリーン(Mac-side agent 計測)                              |
| M2  | GitHub Actions 初回パス確認        | ⚠   | `gh` CLI 認証待ち。push 後の Actions UI 確認が手動になっている                       |
| M3  | RevenueCat dashboard セットアップ  | ✅   | Project / Products / Entitlement `premium` / Offerings 構成済                        |
| M4  | ASC でサブスク product 作成        | ✅   | Subscription Group + 2 product + 7-day free trial 登録済                            |
| M5  | Placeholder 一括置換               | ✅   | `[YOUR_EMAIL]` / `[YOUR_NAME]` / `workoutkit.app/*` のヒット 0 件                   |
| M6  | スクリーンショット撮影             | ✅   | 50 PNG コミット済(iPhone+iPad ja/en+追加モード)。Apple Watch のみ実機未撮影     |
| M7  | Privacy 申告(ASC App Privacy)    | ✅   | `docs/app-store/privacy-nutrition-label.md` の通り入力済                            |
| M8  | ASC メタデータ入力                 | ⚠   | tomo さんの ASC UI 入力待ち。`docs/app-store/{ja,en}/*.txt` を貼るだけ              |
| M9  | TestFlight 配布 → Sandbox 検証     | 🔴   | Apple Developer enrollment 完了が前提(M3/M4 はダッシュボード操作のみで先行可能)  |
| M10 | App Store 審査提出                 | 🔴   | M9 グリーン後に着手                                                                  |

凡例: ✅ 完了 / ⚠ 一部未了・手動待ち / 🔴 未着手・依存待ち

---

## 1. M1 — 初回 Mac ビルド検証(最優先)

**担当**: Mac 環境を持つ作業者(Tomo さん本人 or Mac runner)
**所要**: 15〜30 分
**依存**: なし

### 手順

```bash
git fetch origin
git checkout claude/init-workoutkit-ios-YHots
git pull --ff-only

# Secrets 配置(RevenueCat はあとで埋めるので空でも OK)
cp Config/Secrets.template.xcconfig Config/Secrets.xcconfig
# REVENUECAT_API_KEY = <appl_xxx> を入れるなら今、空のままでもビルドは通る

# 生成
brew install xcodegen   # 既に入っているならスキップ
xcodegen generate

# テスト実行(WorkoutKitTests のみ。UI test は P5 で別途)
xcodebuild test \
  -project WorkoutKit.xcodeproj \
  -scheme WorkoutKit \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:WorkoutKitTests \
  CODE_SIGNING_ALLOWED=NO
```

### 期待結果

- ビルド成功(警告は許容、エラーは 0)
- `WorkoutKitTests` 配下の全テスト合格(目安: 136 件)
- `LaunchTrialTrackerTests` 8 件 / `WatchSummaryBridgeTests` 5 件 は **既に Linux 側で合格を確認済み**

### 失敗時に高確率で出る issue とその対処

| symptom | 想定原因 | 対処 |
|---|---|---|
| `Cannot find type 'Offering' in scope` 系 | RevenueCat 5.x API 名差異 | `Offerings.current.monthly` → `current?.monthly`、`product.introductoryDiscount` → `subscriptionPeriod` 取り回しを RevenueCat 5.x 公式 docs で確認し PurchaseManager.swift を最小修正 |
| `Cannot find 'SystemLanguageModel'` / `Cannot find 'LanguageModelSession'` | FoundationModels が iOS 26 SDK 未配布 | Xcode 16.x の SDK ロード問題。Xcode 17 beta SDK が要る場合は `#if canImport(FoundationModels)` ガードを維持しつつ Build Settings で `OTHER_SWIFT_FLAGS=-DFOUNDATION_MODELS_AVAILABLE` 等で抑制 |
| `actor-isolated property 'now' can not be mutated from a nonisolated context` | LaunchTrialTracker.init の nonisolated 化 | Swift 5 mode で warning 化、Swift 6 mode でも `nonisolated init(...) { ... }` の中で property 代入は許容されるはず。warning が出ても error にしない設定(`SWIFT_VERSION = 5.0`)を維持 |
| StoreKit Configuration が効かず Paywall に "product not found" | `.xcscheme` の storeKitConfiguration path | `WorkoutKit.xcodeproj/xcshareddata/xcschemes/WorkoutKit.xcscheme` の `<StoreKitConfigurationFileReference identifier>` を `../WorkoutKit/Resources/WorkoutKit.storekit` に手で揃える(project.yml §101-127 のコメント参照) |
| `WorkoutKitWatch` target 未署名エラー | watchOS の自動署名 | プロビジョニングプロファイル必要。signing は CI では `CODE_SIGNING_ALLOWED=NO` で回避済み、ローカル実機は Xcode で手動 sign |

修正したら新規 commit を作って **claude/init-workoutkit-ios-YHots** に直接 push する。
GitHub Actions(`.github/workflows/test.yml`)も自動で再走するので二重確認が取れる。

---

## 2. M2 — GitHub Actions ワークフロー初回パス確認

**担当**: 任意(push 後に Actions UI を見るだけ)
**所要**: ~10 分(workflow 実行待ち)
**依存**: M1 のローカル成功(あるいは M1 をスキップして直接 Actions に任せても良い)

### 確認 URL

https://github.com/tomo8492/KintoreApp/actions

`test / xcodebuild-test (iOS Simulator)` ジョブが緑なら OK。

### 失敗時

`xcodebuild-logs` artifact をダウンロードし、`build.log` と `test.log` を読む。
よくあるのは:

- xcodegen が生成する `.xcscheme` の StoreKit configuration path が CI で解決できない → workflow 内で sed して書き換える step を追加
- iPhone 16 シミュレータが macos-15 image に未搭載 → `xcrun simctl list devices` で確認、`iPhone 15` などにフォールバック
- SPM RevenueCat の resolve 失敗 → `Resolve SPM dependencies` step のリトライ追加

---

## 3. M3 — RevenueCat dashboard セットアップ

**担当**: Tomo さん本人(RevenueCat アカウント所有者のみ)
**所要**: 15〜20 分
**依存**: Apple Developer enrollment(年 99 USD)+ App Store Connect でアプリ登録済

### 手順

1. https://app.revenuecat.com にログイン → New Project: `WorkoutKit`
2. Apps → iOS app: bundle ID `com.tomo.workoutkit`
3. Products → Add Product:
   - `workoutkit_monthly_680` / Auto-Renewable Subscription
   - `workoutkit_yearly_4900` / Auto-Renewable Subscription
4. Entitlements → New Entitlement: `premium`、上記 2 product を attach
5. Offerings → Current: 2 product を `$rc_monthly` / `$rc_annual` package に紐付け
6. Project Settings → API Keys → iOS の public key(`appl_xxxxx`)をコピー
7. ローカルの `Config/Secrets.xcconfig` に `REVENUECAT_API_KEY = appl_xxxxx` を入れる
   - **絶対に commit しない**(`.gitignore` 済み)

### 検証

```bash
# RevenueCat 設定後の sandbox 検証ビルド
xcodebuild run \
  -project WorkoutKit.xcodeproj \
  -scheme WorkoutKit \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

Paywall を出して、Offerings が空でないことを確認(空なら dashboard 側の紐付け不足)。

---

## 4. M4 — App Store Connect でサブスク product 作成

**担当**: Tomo さん本人
**所要**: 25〜35 分
**依存**: Apple Developer enrollment

### 手順

1. https://appstoreconnect.apple.com → My Apps → WorkoutKit を新規作成(bundle ID `com.tomo.workoutkit`)
2. **App Information** → Privacy Policy URL、Subcategory(Health & Fitness)を埋める
3. **In-App Purchases and Subscriptions** → Subscription Groups → New: `WorkoutKit Premium`(reference name) / display name は localized
4. Subscription Group 内に 2 product:
   - `workoutkit_monthly_680` / Subscription Duration: 1 Month / Price: 月額 ¥680
   - `workoutkit_yearly_4900` / Subscription Duration: 1 Year / Price: 年額 ¥4,900
5. 各 product に **Introductory Offer**:
   - Free Trial / 7 days / All territories / First-time subscribers only
6. App Store のレビュー用に Localized Display Name / Description を入れる(metadata.md に従う)
7. Save → submit for review(まだアプリ本体は審査前で OK、product だけ承認待ちにできる)
8. 旧 IAP `com.tomo.workoutkit.pro.unlock` が登録されていれば「Remove from sale」

### 検証

App Store Connect Sandbox tester を作成し、TestFlight ビルドで購入を通す(M9 参照)。

---

## 5. M5 — Placeholder 一括置換

**担当**: 任意(Mac でも Linux でも可)
**所要**: 15 分
**依存**: メールアドレス / 開発者名 / 公開 URL の確定

### 対象

```bash
grep -rln "\[YOUR_EMAIL\]\|\[YOUR_NAME\]\|workoutkit\.app/terms\|workoutkit\.app/privacy" \
  docs/ WorkoutKit/Features/Paywall/PaywallLegalSection.swift
```

ヒット箇所:
- `docs/app-store/{ja,en}/description.txt`(2 件)
- `docs/app-store/app-review-notes.md`(2 件)
- `docs/app-store/urls.md`(1 件)
- `docs/legal/{privacy-policy,terms-of-service}.{md,en.md}`(各 1 件)
- `WorkoutKit/Features/Paywall/PaywallLegalSection.swift`(2 件: terms URL + privacy URL)

### 確定すべき URL の選択肢

| 選択肢 | コスト | 推奨 |
|---|---|---|
| **GitHub Pages**(`tomo8492.github.io/KintoreApp/legal/*.html`) | 無料、即時 | ✅ 推奨 |
| 独自ドメイン(`workoutkit.app`) | 年 ~15 USD + DNS / Pages 設定 | 後から差し替え可 |
| Apple's standard EULA(Terms を省略) | 無料 | Terms URL は省略可、Privacy は必須 |

GitHub Pages を使う場合:

```bash
# 1. Pages 有効化(GitHub UI: Settings → Pages → Source: main, /docs)
# 2. CNAME 不要(独自ドメイン使わないので)
# 3. HTML を最新化:
#    docs/legal/*.html が docs/legal/*.md より古いので、pandoc 等で再生成
pandoc docs/legal/privacy-policy.md       -o docs/legal/privacy-policy.html       -s --metadata title="Privacy Policy"
pandoc docs/legal/privacy-policy.en.md    -o docs/legal/privacy-policy.en.html    -s --metadata title="Privacy Policy"
pandoc docs/legal/terms-of-service.md     -o docs/legal/terms-of-service.html     -s --metadata title="Terms of Service"
pandoc docs/legal/terms-of-service.en.md  -o docs/legal/terms-of-service.en.html  -s --metadata title="Terms of Service"
```

### 検証

```bash
grep -rln "\[YOUR_EMAIL\]\|\[YOUR_NAME\]\|workoutkit\.app/" docs/ WorkoutKit/
# → ヒット 0 件が合格
```

---

## 6. M6 — スクリーンショット撮影(P5)

**担当**: Tomo さん本人(物理的に Xcode が必要)
**所要**: 1〜2 時間
**依存**: M1 のビルド成功、M3〜M5 の設定完了

### 撮影対象

`docs/app-store/screenshot-captions.md` の通り:

- **iPhone 6.7"(1290×2796)**: 10 枚
  1. today-hero
  2. builder-result
  3. session-running
  4. session-rest-timer-live-activity
  5. session-summary-aicoach(iOS 26 シミュレータ必須)
  6. library-detail-annotated
  7. library-list-search
  8. history-calendar
  9. templates-presets
  10. paywall(プラン選択中の状態)
- **iPad 12.9"(2048×2732)**: 3 枚
  1. ipad-library-split
  2. ipad-builder-result
  3. ipad-session
- **Apple Watch 45mm(368×448)**: 1 枚
  1. watch-smart-stack(Smart Stack preview で TodaySessionSummary を sample 投入)

### Tip

- Tests/WorkoutKitUITests/AppStoreScreenshotTests.swift が既に UI test として
  実装済み(P5 で UI test を回せばスナップショット PNG が `.derivedData` 配下に
  出る)。
- iOS 26 simulator は Xcode 16.4+ が必要(2026 年 5 月時点)。
- Apple Watch スクショは watchOS 11 シミュレータの Smart Stack preview から撮る。
  本体側で `TodaySessionSummary(isCompletedToday: true, totalSetsToday: 12,
  exerciseCountToday: 5, updatedAt: .now)` を `WatchSummaryBridge.write` して
  おくと意味あるデータが出る。

### 出力

`docs/app-store/screenshots/` 配下に png 保存し、commit。
App Store Connect の各 localization の Media に手動アップロード。

---

## 7. M7 — Apple Developer Privacy 申告

**担当**: Tomo さん本人(App Store Connect UI 操作)
**所要**: 15〜20 分
**依存**: M4 完了

### 入力すべき項目

App Store Connect → App Privacy → "Data Types"

- **Purchases** → Yes
  - Use: App Functionality(subscription state)
  - Linked to user: No(匿名 ID のみ)
  - Tracking: No
- **Identifiers** → Yes(RevenueCat の `$RCAnonymousID:*`)
  - Use: App Functionality
  - Linked to user: No
  - Tracking: No
- 他はすべて No(no analytics、no ads、no PII collection)

### 既に整っている資料

- `docs/legal/privacy-policy.md` 第 5 条 / 第 2.3 条 に詳細記載
- `WorkoutKit/Resources/PrivacyInfo.xcprivacy` に Required Reason API 宣言済(CLAUDE.md §-1.9)

---

## 8. M8 — App Store Connect メタデータ入力

**担当**: 任意
**所要**: 30〜40 分
**依存**: M4、M5、M6

### コピペ元

| App Store フィールド | source |
|---|---|
| App Name | `docs/app-store/{ja,en}/name.txt` |
| Subtitle | `docs/app-store/{ja,en}/subtitle.txt` |
| Promotional Text | `docs/app-store/{ja,en}/promotional-text.txt` |
| Description | `docs/app-store/{ja,en}/description.txt` |
| Keywords | `docs/app-store/{ja,en}/keywords.txt` |
| What's New | `docs/app-store/{ja,en}/whats-new.txt` |
| App Review Notes(English のみ) | `docs/app-store/app-review-notes.md` の "English" セクション |
| Privacy Policy URL | M5 で確定したもの |
| Support URL | `mailto:[YOUR_EMAIL]` or サポートページ |

### 検証

各 localization の Preview が落ちていないこと、文字制限(name 30 / subtitle 30 / promo 170 / desc 4000 / keywords 100 / whats-new 4000)に収まっていることを Connect UI 上で確認。

---

## 9. M9 — TestFlight 配布 → Sandbox 検証

**担当**: Tomo さん本人
**所要**: 30〜60 分(待ち時間込み)
**依存**: M1〜M8 すべて

### 手順

1. Xcode → Product → Archive(scheme: WorkoutKit、Release config)
2. Organizer → Distribute App → App Store Connect → Upload
3. processing 完了後 TestFlight タブで internal tester(自分)に配布
4. 実機で:
   - サブスク購入(月額・年額)
   - 無料トライアル(同 Apple ID で 1 回のみ)
   - キャンセル(設定 → サブスクリプション)
   - 復元(Settings → Restore Purchases)
   - Pro 機能(履歴 31 日超、CSV 出力、Live Activity 等)が unlock されること
   - Live Activity: セット完了 → ロック画面に休憩タイマー表示
   - watchOS Widget: Smart Stack に "今日 / 完了" が出ること
   - iOS 26 デバイスがあれば AI Coach 表示

### Sandbox tester

App Store Connect → Users and Access → Sandbox Testers で 2〜3 アカウント作る。
1 アカウントで日本リージョン、1 アカウントで US リージョンを試す。

---

## 10. M10 — App Store 審査提出

**担当**: Tomo さん本人
**所要**: 15 分(提出)+ 1〜3 日(審査待ち)
**依存**: M1〜M9 すべて

### 提出前の最終チェックリスト

- [ ] M1〜M9 すべて Green
- [ ] `grep -rln "\[YOUR_EMAIL\]\|\[YOUR_NAME\]" docs/ WorkoutKit/` が空
- [ ] App Store Connect の各 subscription product が "Ready to Submit"
- [ ] Privacy Policy URL が公開・閲覧可能
- [ ] スクリーンショット iPhone 10 / iPad 3 / Apple Watch 1 がアップ済み
- [ ] App Review Information の Notes に `docs/app-store/app-review-notes.md` の English ブロックを貼った
- [ ] Build を選択(TestFlight に上げたもの)
- [ ] Age Rating: 12+(フィットネス無難ライン)
- [ ] Pricing and Availability: ¥0(無料、IAP 経由)
- [ ] Export Compliance: No(暗号化通信は Apple のもののみ)

提出 → Apple の自動チェック → 人間レビュアーへ。
ハードペイウォール + サブスクなのでレビュアーが Restore Purchase / Cancel を
試す可能性が高い。M9 で同経路を通しておけば通る確率が高い。

---

## 補足 — 各タスクの並列性

```
M1(Mac build) ── M2(CI green)
                                 ╲
M3(RevenueCat)                    ╲
M4(ASC subscription)               ─→ M9(TestFlight + Sandbox) ─→ M10(Submit)
M5(Placeholders) ── M8(ASC metadata)
M6(Screenshots)                   ╱
M7(Privacy declarations)         ╱
```

- **M1 のみ完了済みの状態**でも、M3〜M8 は順番不問で並列に進められる
- M9 は M1〜M8 がすべて Green になってから

---

## NG リスト(全 worker 共通の禁止事項)

CLAUDE.md §11 の制約と本セッションで追加された運用ルール:

- ❌ `Config/Secrets.xcconfig` を commit しない(`.gitignore` 済み、間違って add しても commit 時に弾く)
- ❌ Foundation Lock v1.0(Bundle ID / App Group / Product ID / Subscription Group)を勝手に変更しない
- ❌ `print()` を本番コードに入れない(Logger 経由のみ)
- ❌ `try!` / `as!` / 強制 unwrap を本番・テスト共に書かない
- ❌ `@available(iOS 26, *)` ガードなしに Foundation Models を呼ばない
- ❌ Live Activity を毎秒 `update` しない(`Text(timerInterval:)` 経由)
- ❌ `.shared` Singleton を新規追加しない(既存例外: PurchaseManager.shared / RestTimerManager.shared / WidgetCenter.shared / UIApplication.shared)
- ❌ Paywall を初回起動から 3 日以内に強制表示しない(LaunchTrialTracker による grace period 厳守)
- ❌ Hard-coded user-facing string を入れない(`Localizable.xcstrings` 経由のみ)

破った場合は **CI workflow が落ちる前にレビュアー(本指図書を読む worker)が
弾く** こと。

---

## 連絡

不明点・追加修正が必要なケース:
- Linux 側からは Mac の挙動を直接観測できないため、エラーログ・スタックトレース
  を可能な限りそのまま貼って質問してください。
- API mismatch は M1 の build error で表面化する想定 — 出てきたエラー文を
  そのまま投げてくだされば即修正パッチを書きます。
- GitHub Actions のジョブログは `xcodebuild-logs` artifact を 7 日間保存します。

---

*Updated 2026-05-16 by Mac-side agents. Living document — update sections
as tasks complete and commit back to this branch.*

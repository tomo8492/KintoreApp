# M9 Pre-Flight Checklist — TestFlight 提出までの単線手順

> tomo さん本人作業用の **逐次チェックリスト**。
> 各ステップを上から順に潰せば TestFlight 提出 → 審査待ちまで辿り着く。
> Apple Developer 登録後の作業は約 4〜6 時間で完走できる想定(うち登録の本人確認 2〜7 営業日は別途)。

| Phase | 推定所要 | ブロッカー解除条件 |
|---|---|---|
| 1. Apple Developer Program 登録 | 30 分 + 本人確認 2〜7 営業日 | 「Welcome to the Apple Developer Program」メール到着 |
| 2. RevenueCat API key 取得 + 投入 | 30 分 | `Config/Secrets.xcconfig` に key が入りビルドが通る |
| 3. ASC レコード作成(アプリ + IAP) | 1 時間 | Bundle ID `com.tomo.workoutkit` と 2 product が ASC 側に存在 |
| 4. GitHub Pages 有効化 | 5 分 | legal 4 URL が 200 OK |
| 5. Xcode で Signing → Team 設定 | 10 分 | 全 4 target の warning「requires a development team」消失 |
| 6. Xcode → Archive → ASC アップロード | 30 分 | Organizer に IPA が出る + ASC のビルドリストに反映 |
| 7. TestFlight でテスター追加 → 自己テスト | 1 時間 | 実機にインストールしてクラッシュなしで起動 |
| 8. App Privacy / Nutrition Label 申告 | 30 分 | 「Privacy Practices」が ✓ 表示 |
| 9. メタデータ入力 6 種(ja/en) | 30 分 | 全フィールドに値が入りバリデーション通過 |
| 10. スクショ + Apple Watch 1 枚 アップロード | 30 分 | 6.7"(iPhone)/12.9"(iPad)/45mm(Watch)全コマ完備 |
| 11. App Review Information の Notes 貼付 | 5 分 | reviewer notes フィールドに英文 + 日文(任意)が入る |
| 12. 提出 → 審査 | 1〜3 日 | 「Ready for Sale」または「Pending Developer Release」 |

---

## Phase 1 — Apple Developer Program 登録

**所要**: 申込 30 分 + 本人確認 2〜7 営業日(これだけは事前にやっておく)

1. URL: <https://developer.apple.com/programs/enroll/>
2. **個人開発者(Individual / Sole Proprietor)** を選択(法人なら別)。
3. Apple ID 2FA を有効化済の **私用 Apple ID** でサインイン(業務 ID は使わない)。
4. 氏名は **App Store に表示される実名** になる(後で変更困難)。
5. 支払い情報: **¥14,800/年**(2026 年時点、為替変動あり)、VISA / Mastercard 推奨。
6. 本人確認: マイナンバーカード or 運転免許証を求められる場合あり。
7. 承認後、Member Center の "Account → Membership" から **Team ID** をメモする。

**Completion check**: 「Welcome to the Apple Developer Program」メールが届く / Member Center にログインできる。

**Troubleshooting**:
- 支払い時 JCB が弾かれる → VISA / Mastercard に切替。
- 本人確認で何度も差し戻される → 書類の四隅まで写るよう撮り直し。
- 法人化を後で考えてる → 個人 → 法人の **アカウント移管は地獄なので最初の選択は慎重に**。

---

## Phase 2 — RevenueCat API key 取得 + `Config/Secrets.xcconfig` 投入

**所要**: 30 分

1. RevenueCat にサインアップ: <https://app.revenuecat.com/signup>
2. **Create Project**(プロジェクト名: `WorkoutKit`)。
3. 左サイドバー **Apps → + New App**:
   - Platform: **iOS**
   - Bundle ID: **`com.tomo.workoutkit`**
   - App Store Connect API Key: 後で(Phase 3 で App-specific Shared Secret を取得後)接続するので一旦スキップ。
4. **API Keys** タブ → **Public API Key**(`appl_xxxx...` で始まる文字列)をコピー。
5. ローカルで Secrets.xcconfig を編集:
   ```bash
   cd /Users/apple/Applications/KintoreApp
   # Secrets.template.xcconfig からコピーされた Secrets.xcconfig は .gitignore 済
   vi Config/Secrets.xcconfig
   ```
   ```ini
   REVENUECAT_API_KEY = appl_XXXXXXXXXXXXXXXXXXXXXX
   ```
6. RevenueCat ダッシュボードの **Entitlements** で `premium` を作成(コードは `PurchaseManager.swift` で `info.entitlements["premium"]` を見にいく既存実装)。
7. **Products** に 2 件追加:
   - `workoutkit_monthly_680` → Entitlement: premium
   - `workoutkit_yearly_4900` → Entitlement: premium
8. **Offerings** で `default` offering を作成し、上の 2 product をアサイン(monthly / annual パッケージ)。

**Completion check**: ローカルで `xcodebuild build CODE_SIGNING_ALLOWED=NO` が通る + 起動時 `[store]` ログに RevenueCat configured が出る。

**Troubleshooting**:
- API key を誤って commit しそう → `git status` で `Config/Secrets.xcconfig` が **untracked** であることを確認(`.gitignore` 済)。
- RevenueCat 側 product ID と App Store Connect 側 product ID が一致してないと entitlement が同期されない。**完全一致必須**。
- key を投入してもアプリで「product not found」 → ASC 側で IAP が **Ready to Submit** 状態でないと Sandbox / TestFlight でも引けない(Phase 3 の最後で `Ready to Submit` を確認)。

---

## Phase 3 — App Store Connect レコード作成 + IAP 設定

**所要**: 1 時間

### 3a. App 新規作成

1. <https://appstoreconnect.apple.com/> → **My Apps → +**
2. 入力:
   - Platform: **iOS**
   - Name: **WorkoutKit**(後で変更可、150 文字制限)
   - Primary Language: **Japanese (Japan)** — `developmentLanguage: ja` と整合
   - Bundle ID: **`com.tomo.workoutkit`**(ドロップダウンに出ない場合は次の手順 3a' へ)
   - SKU: 任意の社内 ID(例: `workoutkit-ios-2026`)
   - User Access: **Full Access**

   3a'. Bundle ID が出ない場合:
   - Developer Portal → Certificates, IDs & Profiles → **Identifiers → +**
   - **App IDs → App** で `com.tomo.workoutkit` を Explicit 登録
   - Capabilities: **App Groups**(`group.com.tomo.workoutkit`)を有効化

### 3b. Subscription Group + IAP 2 件作成

1. ASC の App 詳細 → **Monetization → Subscriptions**
2. **Subscription Groups → +**:
   - Reference Name: `WorkoutKit Premium`
   - Localization (ja): `WorkoutKit プレミアム` / Display Name: `WorkoutKit Premium`
3. グループ内で **+ Subscription**:
   - **Monthly**:
     - Reference Name: `WorkoutKit Premium Monthly`
     - Product ID: **`workoutkit_monthly_680`**
     - Duration: 1 Month
     - Price: ¥680 / month(Tier は ASC で自動マッピング)
   - **Yearly**:
     - Reference Name: `WorkoutKit Premium Yearly`
     - Product ID: **`workoutkit_yearly_4900`**
     - Duration: 1 Year
     - Price: ¥4,900 / year
4. 各 subscription の **Subscription Localization**(ja/en) 入力:
   - ja: 「プレミアム(月額)」「プレミアム(年額)」
   - en: "Premium (Monthly)" / "Premium (Yearly)"
   - 説明文: `docs/app-store/ja/description.txt` / `en/description.txt` の subscription 部分を流用
5. **Introductory Offer**(無料トライアル):
   - 各 subscription で **Introductory Offers → +**
   - Type: **Free**
   - Eligibility: **New Subscribers** + **Previously Subscribed**(任意で広げる場合)
   - Duration: **1 Week**(= 7 日)
6. **Family Sharing**: 各 subscription で **Family Sharing → Turn On**(`docs/app-store/urls.md` と整合)。

### 3c. App-Specific Shared Secret(RevenueCat 用)

1. ASC の App → **App Information → App-Specific Shared Secret**
2. **Generate** → 表示された文字列を RevenueCat ダッシュボードの **App Store Connect Shared Secret** フィールドに貼り付け。

**Completion check**: 2 product が ASC 側で **Ready to Submit** 表示 + RevenueCat ダッシュボードに同じ product ID が同期されている。

**Troubleshooting**:
- Product ID が変更不可 → 名前を一度設定すると変更できない。**Foundation Lock §-1.14 通りに正確に入力**: `workoutkit_monthly_680` / `workoutkit_yearly_4900`(アンダースコア、半角小文字)。
- Localization 入力をスキップすると `Missing Metadata` で submit が止まる。
- Free Trial は同一 Subscription Group 内で **1 回しか** ユーザーごとに付与されない(Apple 既定動作)。Terms of Service の §5.3 に明記済(`docs/legal/terms-of-service.md`)。

---

## Phase 4 — GitHub Pages 有効化(法務ページ配信)

**所要**: 5 分

1. リポジトリページ → **Settings → Pages**
2. **Source**: **Deploy from a branch**
3. **Branch**: `claude/init-workoutkit-ios-YHots`(または `main` after merge)、**Folder**: `/docs`
4. **Save**
5. 数分待って次の 4 URL が 200 OK で開けるか確認:
   - <https://tomo8492.github.io/KintoreApp/legal/privacy-policy.html>
   - <https://tomo8492.github.io/KintoreApp/legal/privacy-policy.en.html>
   - <https://tomo8492.github.io/KintoreApp/legal/terms-of-service.html>
   - <https://tomo8492.github.io/KintoreApp/legal/terms-of-service.en.html>
6. `docs/.nojekyll`(既存)が Jekyll を無効化、style.css がそのまま配信される確認。

**Completion check**: 4 URL すべて 200 OK + ブラウザで開いたとき lang-switcher / dl.meta / TOC が崩れず表示される。

**Troubleshooting**:
- Pages が 404 → branch / folder の選択を間違えてる。Settings → Pages を再確認。
- スタイルが崩れる(plain text 表示) → `style.css` の同階層配信に失敗。`docs/.nojekyll` がコミット済か確認。
- Private repo で Pages が有効化できない → Public に切替えるか、Private Pages を別途有効化(GitHub Pro 以上が必要)。

---

## Phase 5 — Xcode で Signing → Team 設定

**所要**: 10 分

1. Xcode で WorkoutKit.xcodeproj を開く。
2. 左 Project Navigator → 青いプロジェクトアイコンクリック → 上部 **Signing & Capabilities** タブ。
3. 4 つの target すべてに対し:
   - **WorkoutKit**(Beta / Debug / Release それぞれ)
   - **WorkoutKitLiveActivity**
   - **WorkoutKitWatchApp**
   - **WorkoutKitWatch**
4. 各 target の **Team** ドロップダウン → Phase 1 で登録した Team を選択。
5. Bundle ID が以下と一致しているか確認(変更しない):
   - WorkoutKit: `com.tomo.workoutkit` / `com.tomo.workoutkit.beta`(Beta config)
   - WorkoutKitLiveActivity: `com.tomo.workoutkit.LiveActivity`
   - WorkoutKitWatchApp: `com.tomo.workoutkit.watchkitapp`
   - WorkoutKitWatch: `com.tomo.workoutkit.watchkitapp.watchwidget`
6. App Group 確認(全 target で共有): `group.com.tomo.workoutkit`
7. **Automatically manage signing** ✓ をオンのまま。

**Completion check**: 各 target の Status 欄から ⚠ アイコンが消える(「requires a development team」warning ゼロ)。

**Troubleshooting**:
- Team が出てこない → Xcode → Settings → Accounts に Apple ID を追加し、Developer Portal と sync。
- 自動署名が動かない → Xcode を再起動 → Clean Build Folder → Build。
- Bundle ID 重複エラー → 他アプリで既に `com.tomo.workoutkit` を使っていないか Developer Portal で確認(Foundation Lock §-1.1 通り)。

---

## Phase 6 — Xcode → Product > Archive → ASC アップロード

**所要**: 30 分(ビルド 5〜10 分 + アップロード 5〜10 分 + 処理待ち 10〜20 分)

1. Xcode 上部 destination で **Any iOS Device (arm64)**(物理ビルド)を選択。
2. **Product → Scheme → Edit Scheme** → **Archive** の Build Configuration を **Release** に固定済か確認(既存 project.yml で設定済)。
3. **Product → Archive**(メニューから、Cmd+B 等のショートカットも可)
4. ビルド完了 → **Organizer** が自動で開く。
5. 最新 Archive 選択 → **Distribute App** → **App Store Connect** → **Upload** → 既定値で **Next** 連打 → **Upload**
6. アップロード成功後、ASC の App → **TestFlight → iOS** で「Processing」状態のビルドが表示される。
7. 10〜20 分待つと「Ready to Submit」に変わり、Export Compliance 質問が出る:
   - 「Does your app use encryption?」→ **No, my app uses only standard Apple cryptography**(`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption=NO` を設定済なので **このダイアログ自体出ない**ことを期待、もし出たら No を選択)

**Completion check**: TestFlight タブにビルド番号が表示される + 「Ready to Submit」または「Submit for Review」ボタンが押せる状態。

**Troubleshooting**:
- Archive が失敗する → Clean Build Folder → 再 Archive。
- Upload が失敗(「Invalid Bundle」) → Bundle ID / Team の不整合。Phase 5 を再確認。
- アップロード後 ASC に出ない → 10 分待つ。Processing が長引くなら Apple のシステムステータス確認: <https://developer.apple.com/system-status/>
- Export Compliance ダイアログが毎回出る → `Info.plist` に `ITSAppUsesNonExemptEncryption=NO` が入ってない。project.yml の WorkoutKit target を確認。

---

## Phase 7 — TestFlight でテスター追加 → 自己テスト

**所要**: 1 時間

1. ASC の App → **TestFlight → Internal Testing → + (Create a Group)**:
   - Group Name: `tomo selftest`
2. Group に **Add Testers → tomo の Apple ID** を追加(個人開発なら自分のみ)。
3. ビルドを Group に **Add Build** で割当。
4. テスター(自分)の iPhone / iPad で **TestFlight アプリ**を開いて WorkoutKit をインストール。
5. 動作確認(最低限):
   - 起動 → クラッシュなし
   - Today タブ → CTA「ワークアウトを組む」→ Builder ウィザード一周
   - Session 開始 → 1 セット完了 → Rest Timer 表示 → Live Activity がロック画面に出ること
   - 設定 → Restore Purchases ボタン押下(エラーなく完了)
   - Paywall を表示(Templates タブの + 等)→ 月額 / 年額プランが表示される

**Completion check**: 上記の主要 6 動線すべてでクラッシュなし。

**Troubleshooting**:
- アプリ起動直後にクラッシュ → Console.app で `WorkoutKit` のログを見て fatalError 発生箇所を特定。
- Paywall に「product not found」 → Phase 3 で IAP が **Ready to Submit** 状態か確認 + Phase 2 の RevenueCat 同期確認。
- Live Activity が出ない → 端末の **設定 → 通知 → WorkoutKit → Live Activities** が ON か確認。

---

## Phase 8 — App Privacy / Nutrition Label 申告

**所要**: 30 分

1. ASC の App → **App Privacy → Get Started**
2. `docs/app-store/privacy-nutrition-label.md`(worker A が作成済)を参照しながら逐次入力:
   - **Data Used to Track You**: **None**(本アプリは tracking しない)
   - **Data Linked to You**: **None**
   - **Data Not Linked to You**:
     - **Purchases** → **App Functionality**(IAP の購入状態管理)
     - **Identifiers** → **Anonymous Identifier**(`$RCAnonymousID:*`、RevenueCat 経由のみ)
3. Privacy Policy URL: `https://tomo8492.github.io/KintoreApp/legal/privacy-policy.html`
4. **Publish**

**Completion check**: App Privacy のステータスが「Set Up」(✓) になる。

**Troubleshooting**:
- 入力したのに「Missing Privacy Information」になる → 各カテゴリで **Save** をクリックしたか確認。
- RevenueCat の anonymous ID をどう申告? → `docs/app-store/privacy-nutrition-label.md` の §3 を参照。

---

## Phase 9 — メタデータ入力 6 種(ja/en)

**所要**: 30 分

ASC の App → **App Information / Pricing and Availability / iOS App** で以下を入力。`docs/app-store/` 配下のテキストをコピペすれば終わる。

### App Information

| フィールド | 値 / 出典 |
|---|---|
| Subtitle (ja) | `docs/app-store/ja/subtitle.txt`(あれば) |
| Subtitle (en) | `docs/app-store/en/subtitle.txt` |
| Category | Primary: **Health & Fitness** / Secondary: **Sports** |
| Content Rights | チェック「Does Not Contain ...」 |
| Age Rating | 4+(他選択肢なし) |

### Pricing and Availability

- Price: **Free**(IAP で課金)
- Availability: **All Countries / Regions**(個別除外なければ)

### Version Information(ja-JP / en-US 両方)

| フィールド | 出典 |
|---|---|
| Description | `docs/app-store/ja/description.txt` / `en/description.txt` |
| Keywords | `docs/app-store/ja/keywords.txt` / `en/keywords.txt`(あれば) |
| Promotional Text(任意) | `docs/app-store/ja/promotional.txt` / `en/promotional.txt`(あれば) |
| Support URL | `mailto:tomo060213@gmail.com`(`docs/app-store/urls.md`) |
| Marketing URL(任意) | `https://github.com/tomo8492/KintoreApp`(public 化したら) |
| Privacy Policy URL | ja: `.html` / en: `.en.html`(`docs/app-store/urls.md`) |
| Copyright | `© 2026 Tomo`(`docs/app-store/urls.md`) |

文字数監査結果: `docs/app-store/CHAR_COUNT_AUDIT.md` で全フィールド上限以内確認済(worker C 監査済)。

**Completion check**: 「Save」を押してバリデーション通過 + 各フィールド緑チェック。

**Troubleshooting**:
- Description が 4000 文字超 → `docs/app-store/CHAR_COUNT_AUDIT.md` のカウントを再確認。
- Keywords がカンマ区切りでなく弾かれる → `keyword1,keyword2,...` で半角カンマのみ、スペース禁止。

---

## Phase 10 — スクショアップロード(50 PNG + Apple Watch 1)

**所要**: 30 分

### 既に揃ってる素材

- iPhone 6.7"(6.9" simulator で撮影、Apple は同サイズ枠で受理): `docs/app-store/screenshots/iphone-67/*.png`(26 枚 = ja 13 + en 13)
- iPad 12.9": `docs/app-store/screenshots/ipad-13/*.png`(20 枚 = ja 10 + en 10)

### M9 直前で追加が必要

- **Apple Watch 45mm**(368×448、Smart Stack widget のスクショ 1 枚以上):
  - watchOS シミュレータか実機 Apple Watch で WorkoutKit Smart Stack を撮影
  - ASC に必須(Smart Stack widget 同梱のため)
  - 撮影方法: iPhone でペアリングした Apple Watch を起動 → Smart Stack 表示 → ⌘+S(Watch app)でスクショ撮影

### ASC でのアップロード手順

1. ASC の App → **iOS App → 1.0 Prepare for Submission** → **App Screenshots** セクション。
2. デバイス別タブ(**iPhone 6.7" / iPad 12.9" / Apple Watch**)を選択。
3. ロケール別(**ja-JP / en-US**)で対応 PNG を drag-and-drop。
4. **順序**:
   - iPhone 1 枚目: `today` または `paywall`(訴求が強い順)
   - 2-3 枚目: Builder / Session 系
   - 4-5 枚目: Library / History
   - 残り: 詳細機能
   - **指図書 §6 推奨順は** `docs/app-store/screenshots/iphone-67/` のシナリオ名から逆引き可能。

**Completion check**: 各デバイス・ロケールで「Required: 3-10 images」を満たして緑チェック。

**Troubleshooting**:
- スクショサイズエラー → Apple は 1290×2796 (iPhone 6.7") か 1320×2868 (iPhone 6.9" / Pro Max) を許容。撮影済のは 1320×2868 でこれは 6.7" / 6.9" 両枠で OK。
- iPad のサイズエラー → 2064×2752(13" iPad Pro)が許容。撮影済はこれと一致。
- Apple Watch スクショは Smart Stack の見た目をそのまま撮ればよく、サイズは 368×448(45mm)。

---

## Phase 11 — App Review Information の Notes 貼付

**所要**: 5 分

1. ASC の App → **iOS App → 1.0 Prepare for Submission** → **App Review Information** セクション。
2. **Sign-In Required**: **No**(本アプリはサインインなし)
3. **Contact Information**:
   - First Name: `Tomo` / Last Name: 任意 / Phone: 任意 / Email: `tomo060213@gmail.com`
4. **Notes**: `docs/app-store/app-review-notes.md` の英文ブロックをコピペ:
   - 「About the app」/「Privacy and Terms」/「Features intentionally excluded from v1.0」/「Contact」セクションをそのまま。
5. **Demo Account**: 不要(サインインなし)。
6. **Attachment**: 不要(reviewer がアプリ内動作だけで完結する)。

**Completion check**: Notes フィールドに英文が貼られている。

---

## Phase 12 — 提出 → 審査待ち

**所要**: 提出は 5 分、審査結果は 1〜3 日

1. ASC の App → **iOS App → 1.0 Prepare for Submission** の上部 **Add for Review** → **Submit for Review**
2. 提出時の追加質問:
   - Export Compliance: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption=NO` 済なので自動 No。
   - Advertising Identifier (IDFA): **No**
   - Content Rights: **No, it does not contain ...**
3. 「Submitted to App Review」表示 → メール通知が来るのを待つ。

**Completion check**: ステータスが「Waiting for Review」→「In Review」→「Ready for Sale」または「Pending Developer Release」へ遷移。

**Troubleshooting**:
- リジェクトされた場合: ASC の **Resolution Center** にメッセージが来る。多くは Metadata Rejection で文言修正だけで再 submit 可能。
- Guideline 違反でハードリジェクトされた場合: 対応コミットを push → Phase 6 から再 Archive → 再 Upload → 同じビルド番号は使えないので `MARKETING_VERSION` を 1.0.1 等に上げる。

---

## 完了後の Day-0 観測ポイント

- ASC の **TestFlight → Analytics**: install / crash 数(初日は数字ゼロでも気にしない)
- 法務ページ 4 URL 200 OK 継続
- RevenueCat ダッシュボード → Sandbox 環境で trial / 購入 / 復元が記録されているか
- App Store のレビュー(全世界出すなら ja / en どちらか)

---

## このチェックリストを更新するとき

- 各 Phase で詰まったポイント → **Troubleshooting** に追記して次回 release で活用。
- M9.5 / M10(v1.0.1 等の追加リリース)では Phase 1, 4, 5 を skip して Phase 6 以降に直行する流れになる。

---

参考:
- `docs/DISPATCH_v1.0.md` — マイルストーン全体図
- `docs/app-store/urls.md` — URL フィールド一覧
- `docs/app-store/CHAR_COUNT_AUDIT.md` — メタデータ文字数監査
- `docs/app-store/privacy-nutrition-label.md` — Nutrition Label 入力 cheat sheet
- `docs/app-store/app-review-notes.md` — Reviewer 向け Notes 本文
- `docs/legal/*` — Privacy Policy / Terms of Service(ja/en × md/html)
- `docs/release-notes/v1.0.0-rc1.md` — リリースノート draft

# DISPATCH 指示書 — Xcode 上での WorkoutKit v1.0 デバッグ

> **対象 worker**: Mac + Xcode 環境を持つ Dispatch worker
> **Repo**: `tomo8492/KintoreApp`
> **Branch**: `claude/init-workoutkit-ios-YHots`(最新 HEAD: `62462ac`)
> **目的**: Linux 側エージェントが書いたコードを Xcode で実ビルド・実テスト・
> 実機/シミュレータ動作確認し、コンパイルエラー・UI 不具合を潰す。
> **成果物**: 修正 commit を同ブランチに直接 push + 本書末尾の報告フォーマットで結果報告。

---

## 0. 前提と背景

Linux サンドボックス側エージェントは `xcodebuild` を実行できないため、直近の
コミット群(下記)は **静的検証(ブレース整合・JSON 妥当性・API 名の目視確認)
までしか通っていない**。Xcode での実コンパイルは未実施。

直近 6 コミット(要 Xcode 検証):
```
62462ac ux: dynamic island concentric polish + AI Coach Apple Intelligence styling
24bfb0d ux: builder wizard 2026 polish - progress bar, haptics, generate button
7a0e18d ux: paywall 2026 best-practice overhaul + gym-friendly session UI
981ec6b debug: fix 5 release-blocking bugs found by full code review
e220f46 debug: fix release-blocking iOS-17 leak + sweep 47 user-visible Pro→Premium
ae796cd merge: task/docs-audit-v1
```

特に **新規・大幅改修されたファイル**(コンパイルエラーが出やすい順):

| ファイル | 変更内容 | リスク |
|---|---|---|
| `WorkoutKit/Features/Paywall/PaywallView.swift` | 全面書き換え。Visual Trial Timeline / price anchoring / haptic / dynamic CTA 追加 | 高 |
| `WorkoutKit/Features/Session/SessionSetInputPanel.swift` | actionButtons 全面改修、confirmationDialog、haptic helper 追加 | 高 |
| `WorkoutKit/Features/Builder/BuilderView.swift` | BuilderStepProgressBar 追加、bottomBar 改修、haptic 追加 | 中 |
| `WorkoutKit/Features/AICoach/AICoachView.swift` | gradient 背景、symbolEffect、insightRow 追加 | 中 |
| `WorkoutKitLiveActivity/RestTimerLiveActivityView.swift` | Dynamic Island concentric 化 | 中 |
| `WorkoutKit/Features/LiveActivity/RestTimerManager.swift` | start() の race 修正 | 中 |
| `WorkoutKit/Features/Paywall/PurchaseManager.swift` | proGateBridge に didSet 追加、PurchaseRestoring 適合 | 中 |
| `WorkoutKit/Features/DataIO/CSVParser.swift` | CSV injection サニタイザ追加 | 低 |
| `WorkoutKit/Shared/WatchSummaryBridge.swift` | Calendar.autoupdatingCurrent 化 | 低 |

---

## 1. STEP 1 — ビルド & ユニットテスト

```bash
git fetch origin
git checkout claude/init-workoutkit-ios-YHots
git pull --ff-only

# Secrets 配置(空でもビルドは通る設計)
cp Config/Secrets.template.xcconfig Config/Secrets.xcconfig

# プロジェクト生成
brew install xcodegen   # 入っていればスキップ
xcodegen generate

# ビルド + ユニットテスト
xcodebuild test \
  -project WorkoutKit.xcodeproj \
  -scheme WorkoutKit \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:WorkoutKitTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/wk-build.log | grep -E "error:|warning:|Test Suite|passed|failed"
```

**期待結果**: ビルド成功(error 0)、`WorkoutKitTests` 全件 green(目安 155 件)。

---

## 2. STEP 2 — 想定コンパイルエラーと対処

Linux 側で書いたコードのうち、Xcode 実コンパイルで落ちる可能性がある箇所を
**先回りで列挙**する。出たらこの表に従って最小修正 → commit。

### 2-1. PaywallView.swift

| 想定エラー | 原因 | 対処 |
|---|---|---|
| `Cannot find 'UISelectionFeedbackGenerator'` | `#if canImport(UIKit)` ガード下にあるが import 漏れ | ファイル冒頭の `#if canImport(UIKit) import UIKit #endif` を確認。既に追加済みのはずだが、なければ追加 |
| `symbolEffect(.bounce, options:.nonRepeating, value:)` が解決しない | iOS 17+ API。deployment target は 18 なので通るはず | 通らなければ `.symbolEffect(.bounce, value: status)` に簡略化 |
| `contentTransition(.symbolEffect(.replace))` エラー | iOS 17+。OK のはず | ダメなら `.contentTransition(.opacity)` にフォールバック |
| `NumberFormatter` の currencySymbol 周りで型エラー | `monthlyEquivalentText` 内 | ロジックは純粋な String/Int 処理。型不一致が出たら `NSNumber(value:)` のキャストを確認 |
| `PurchaseOffering` / `PurchasePlan` の型不一致 | PurchaseManager 側と齟齬 | `PurchaseManager.swift` の struct 定義(productID/displayPrice/trialDays/rcIdentifier)と照合 |

### 2-2. SessionSetInputPanel.swift

| 想定エラー | 対処 |
|---|---|
| `confirmationDialog` の引数ラベル不一致 | iOS 15+ API。`confirmationDialog(_:isPresented:titleVisibility:actions:message:)` のシグネチャ通りか確認 |
| `UINotificationFeedbackGenerator` 未解決 | `#if canImport(UIKit) import UIKit #endif` がファイル冒頭にあるか確認 |
| `playHaptic` の enum `HapticKind` スコープ | private enum なので同 struct 内なら OK |

### 2-3. BuilderView.swift

| 想定エラー | 対処 |
|---|---|
| `BuilderStepProgressBar` で `BuilderStore.Step` が `Hashable`/`Equatable` でない | `Step` は `enum Step: Int, CaseIterable, Identifiable`。`Int` raw なので Equatable は自動。`firstIndex(of:)` も通る |
| `AnyShapeStyle` のイニシャライザ | iOS 17+。`AnyShapeStyle(Color.accentColor)` は OK |
| `.animation(_:value:)` の value に `BuilderStore.Step` | Equatable 必須 → Int raw enum なので OK |

### 2-4. AICoachView.swift

| 想定エラー | 対処 |
|---|---|
| `symbolEffect(.pulse, options:.repeating, isActive:)` | iOS 17+。`isActive:` 引数は iOS 17 で利用可。ダメなら `if isGenerating { ... }` で出し分け |
| `symbolEffect(.variableColor.iterative, ...)` | iOS 17+。同上 |
| `.transition(.opacity.combined(with:.move(edge:.top)))` | 標準 API、問題なし |

### 2-5. RestTimerLiveActivityView.swift

| 想定エラー | 対処 |
|---|---|
| `Text(timerInterval: .now ... endTime, countsDown:)` | `Text.init(timerInterval:pauseTime:countsDown:showsHours:)` は `ClosedRange<Date>` を取る。`.now ... endTime` は正しい。**`..<` に変えないこと** |
| Widget extension で `accessibilityLabel` 未解決 | WidgetKit でも SwiftUI の modifier は使える。問題なし |

### 2-6. RestTimerManager.swift

| 想定エラー | 対処 |
|---|---|
| `Task { @MainActor in ... }` 内の `oldActivity` キャプチャ | `oldActivity` は `Activity<RestTimerAttributes>`(値型でない参照)。`@preconcurrency import ActivityKit` 済みなので sending 警告は抑制される。error になる場合は `oldActivity` を `let` で明示キャプチャ |

### 2-7. PurchaseManager.swift

| 想定エラー | 対処 |
|---|---|
| `proGateBridge` の `didSet` が `@MainActor` クロージャを呼ぶ | PurchaseManager は `@MainActor` class。didSet も MainActor 隔離下なので OK |
| RevenueCat 5.x の `Offerings.current?.monthly` / `.annual` | **これが最重要**。RevenueCat 5.x 実 API と照合。`Offering.monthly` / `Offering.annual` は `Package?` を返す。`Package.storeProduct.introductoryDiscount` の型が `StoreProductDiscount?` であることを確認 |
| `Purchases.shared.purchase(package:)` の戻り型 | `PurchaseResultData`(`userCancelled: Bool`, `customerInfo: CustomerInfo` 等のタプル風 struct)。`result.userCancelled` / `result.customerInfo` でアクセス |

> **RevenueCat API が最大の不確定要素**。型不一致が出たら
> https://revenuecat.github.io/purchases-ios-docs/ の 5.x docs を参照して
> `PurchaseManager.swift` を最小修正。ロジック(configure → fetchOffering →
> purchase → restore → apply)は変えず、API 名/シグネチャだけ合わせる。

---

## 3. STEP 3 — シミュレータ実機動作確認(UX 検証)

`xcodebuild` ではなく **Xcode IDE の Run ボタン**で起動すること
(StoreKit Configuration は scheme 設定なので IDE 経由でないと効かない)。

### 3-1. Paywall(最重要・今回大改修)

- [ ] 起動 3 日後 or プレミアム機能タップで Paywall が出る
- [ ] **Visual Trial Timeline** が表示される(今日 → 5 日目 → 7 日目の 3 ステップ)
      ※ トライアル付きプラン選択時のみ。月額/年額切替で timeline が出入りする
- [ ] 年額カードに「月あたり ¥408」「40% OFF」「¥3,260 お得」3 つが出る
- [ ] プランをタップすると触覚フィードバック(軽い tick)
- [ ] CTA ボタン文言がプラン切替で変わる:
      トライアル付き → 「7 日間 無料で始める」
      トライアル無し → 「プレミアムに登録」
- [ ] 購入成功で success haptic + Paywall 自動 dismiss
- [ ] Restore ボタン(arrow.clockwise アイコン付き)が機能する
- [ ] フッタに自動更新サブスク開示文(3.1.2)が出ている
- [ ] ダークモード / ライトモード両方で崩れない
- [ ] iPhone SE(小画面)で要素が溢れない・truncate しない

### 3-2. Session(ワークアウト実行・今回改修)

- [ ] Complete Set ボタンが大きい(56pt 以上)、checkmark アイコン付き
- [ ] セット完了で success haptic
- [ ] Skip / Stop ボタンにアイコン(forward.end / stop.fill)
- [ ] **Stop タップで確認ダイアログ**が出る(即中断しない)
- [ ] 確認ダイアログ「終了する」で実際に中断、「キャンセル」で継続
- [ ] レスト中に Dynamic Island / ロック画面にタイマーが出る

### 3-3. Builder(ウィザード・今回改修)

- [ ] iPhone で 4 セグメントの進捗バーが出る(ナビバー下)
- [ ] ステップ前進で進捗バーが spring アニメで埋まる
- [ ] 次へ / 戻るで触覚フィードバック
- [ ] 最終ステップの Generate ボタンに sparkles アイコン、少し大きめ
- [ ] iPad ではサイドバーの StepIndicatorRow が従来通り動く

### 3-4. AI Coach(iOS 26 シミュレータが必要)

- [ ] iOS 26 sim でセッション完了 → AICoachView に gradient 背景
- [ ] 生成中は sparkles が pulse、3 行に各アイコン(text/star/arrow)
- [ ] iOS 18〜25 sim では AICoachView が**非表示**(クラッシュしない)

### 3-5. Live Activity(Dynamic Island)

- [ ] Dynamic Island 搭載機(iPhone 16 等)の sim でレスト開始
- [ ] 展開時、leading の timer アイコンが円形背景で島の形と馴染む
- [ ] compact / minimal でカウントダウンが表示される

---

## 4. STEP 4 — 回帰チェック

今回の改修で**触っていない**が、依存しているため壊れていないか確認:

- [ ] History 一覧・カレンダー表示
- [ ] Library 種目詳細(解剖図・ステップ)
- [ ] Templates プリセット
- [ ] Settings 各画面・kg/lbs 切替・テーマ切替
- [ ] CSV エクスポート結果を Numbers で開く → `=`/`+` 始まりセルが
      数式実行されず `'` 付きで無害化されている(CSV injection 対策の確認)

---

## 5. STEP 5 — UI test(任意・余力があれば)

```bash
xcodebuild test \
  -project WorkoutKit.xcodeproj \
  -scheme WorkoutKit \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:WorkoutKitUITests \
  CODE_SIGNING_ALLOWED=NO
```

スクリーンショット撮影 UI test(`AppStoreScreenshotTests` 等)が含まれる。
Paywall 改修で UI 階層が変わったので、`session.action.complete-set` 等の
`accessibilityIdentifier` が維持されているか確認(改修後も付与済みのはず)。

---

## 6. NG リスト(修正時の禁止事項 — CLAUDE.md §11)

- ❌ `Config/Secrets.xcconfig` を commit しない
- ❌ Foundation Lock(Bundle ID / App Group / Product ID / Subscription Group)変更禁止
- ❌ `print()` / `try!` / `as!` / 強制 unwrap を追加しない(Logger 経由)
- ❌ Foundation Models を `@available(iOS 26, *)` ガード無しで呼ばない
- ❌ Live Activity を毎秒 `update` しない(`Text(timerInterval:)` 維持)
- ❌ `.shared` Singleton を新規追加しない(既存例外: PurchaseManager / RestTimerManager)
- ❌ Hard-coded user-facing string 禁止(`Localizable.xcstrings` 経由)
- ❌ `Text(timerInterval:)` を `..<` に変えない(ClosedRange が正しい)
- ❌ UX 改修のロジック(Visual Timeline / haptic / dynamic CTA 等)を
   「コンパイルを通すため」だけの理由で削除しない。型を合わせて残すこと

---

## 7. コンパイルエラーを直したら

```bash
# 各修正ごとに、または論理単位ごとに commit
git add <修正ファイル>
git commit -m "fix(xcode): <何を直したか具体的に>"
git push origin claude/init-workoutkit-ios-YHots
```

`.github/workflows/test.yml` が push で自動再走するので、Actions UI でも
二重確認できる。

---

## 8. 報告フォーマット(完了時にこの形で報告)

```
## Xcode デバッグ結果 — WorkoutKit v1.0

### ビルド
- xcodegen generate: 成功 / 失敗
- xcodebuild (WorkoutKit scheme): 成功 / 失敗(error N 件)
- WorkoutKitTests: NNN passed / M failed
- WorkoutKitUITests: (実施した場合)NNN passed / M failed

### 修正したコンパイルエラー(commit SHA 付き)
1. <ファイル:行> — <症状> → <修正内容>  (commit xxxxxxx)
2. ...

### UX 動作確認結果
- Paywall: OK / NG(詳細)
- Session: OK / NG
- Builder: OK / NG
- AI Coach (iOS 26): OK / NG / 未確認(sim 無し)
- Live Activity: OK / NG

### 回帰
- History / Library / Templates / Settings / CSV: OK / NG

### 残課題
- <Mac でも解決できなかった項目があれば>
```

---

*この指示書は Linux 側エージェントが 2026-05-19 に作成。
質問・追加修正が必要なら、エラーログ全文を貼って Linux 側に投げ返せば
即パッチを書きます。*

# WorkoutKit Comprehensive Debug Pass — Report

- **Branch**: `debug/comprehensive-pass`
- **Base**: `claude/init-workoutkit-ios-YHots` @ `5fdadde`
- **Date**: 2026-05-04
- **Scope**: 全機能 end-to-end 動作確認 + バグ・パフォーマンス・UX 問題の洗い出し
- **修正方針**: 本タスクは **発見と報告に集中**。本ファイル以外の構造的修正は別 PR で実施。
  確認過程で書き換えたコードは **無し**(本パスでは読み取り専用で完了)。

---

## 0. Executive Summary

| 観点 | 結果 |
|---|---|
| Build (iPhone 16 Pro / iOS 18.5) | ✅ Succeeded |
| Tests (104 unit + 1 UI) | ✅ All pass (~3.3s) |
| Warnings | 22 件(主に Swift 6 strict concurrency の `#Predicate` マクロ KeyPath Sendable + LiveActivity の `sending 'activity'` 2 件) |
| `print()` 残存 | 0 件 |
| Force unwrap 残存 | 0 件 |
| 自作 `.shared` Singleton | 0 件(`UIApplication.shared` のみ — §11.4 で許可) |
| `fatalError` | 1 件(`WorkoutKitApp.swift:54` ModelContainer 初期化失敗時、許容) |
| TODO | 1 件(`PaywallSections.swift:151` Privacy/Terms URL placeholder) |
| 翻訳ステータス (ja / en) | ✅ 100% translated(missing/new/stale 0) |
| 未使用 l10n キー | 9 件(削除候補) |

**Critical findings** が 4 件、Major が 11 件、Minor が 20 件以上。詳細は §3 以降。

> **重要**: シミュレータへのクリック注入(computer-use / AppleScript / Quartz CGEvent すべて)が
> イベントとして届かず、対話的な UI ウォークスルーが Builder 以降できなかった。
> 起動状態のスクリーンショット(Light / Dark)は取得済み(`/tmp/debug-walk/01-launch.png`,
> `04-launch-dark.png`)。残りは **コードリーディング駆動** で 6 系統並列レビュー。
> UI 動作確認(視覚回帰、a11y 実機読み上げ、Dynamic Type XL 崩れ)は **未検証**。

---

## 1. ビルド & テスト

### 1.1 Build

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme WorkoutKit \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build
```

→ `** BUILD SUCCEEDED **`(`/tmp/debug-build.log`)

#### Warnings(`/tmp/debug-warnings.txt`、22 unique)

| カテゴリ | 件数 | 例 |
|---|---|---|
| `#Predicate` マクロが生成する KeyPath が Sendable に適合しない | 18 | `Features/Library/ExerciseListView.swift:15` 他 |
| `LiveActivityClient` の `await activity.update / end` で `sending 'activity' risks data races` | 2 | `Features/Session/LiveActivityClient.swift:81, 93` |
| `appintentsmetadataprocessor`: AppIntents.framework 未依存 | 1 | informational only |
| AppShortcuts 未定義 | 1 | informational only |

**前者 18 件**は Swift 6 strict concurrency が `#Predicate` マクロ展開後の KeyPath を
Sendable と判定できない既知の制限。Apple SDK 側の改善待ち。実害はないが
Swift 6 言語モードに切り替えるとエラー昇格するため、その前に macro 修正 or
`-Xfrontend -enable-bare-slash-regex` 等回避策の検討が必要。

**後者 2 件**は ActivityKit の `Activity<Attributes>` が Sendable 準拠でないことに起因。
こちらは `LiveActivityClient` を `actor` 化済みで実害は低いが、`activity` の保持と
更新タイミング次第で論理的なレースが残っているため §4.2 Critical-2 で別途指摘。

### 1.2 Tests

```
xcodebuild ... test
```

→ `** TEST SUCCEEDED **`(`/tmp/debug-test.log`)

- ✔ 104 ユニットテスト(13 suite、3.259 秒)
- ✔ 1 UI テスト(`WorkoutKitUITestsPlaceholder.testAppLaunches`、2.97 秒)
- 失敗テスト: 0
- 0.5 秒以上の slow test: 0(最遅は StoreKit 系の `0.757 秒`)

---

## 2. 静的解析

### 2.1 NG リスト準拠(CLAUDE.md §11.4)

| ルール | 結果 |
|---|---|
| `print()` 本番残存禁止 | ✅ 0 件 |
| force unwrap (`!`) 禁止 | ✅ 0 件(`!=` / `!isEmpty` 等の負号のみ) |
| 自作 Singleton 禁止 | ✅ 0 件(`.shared` は `UIApplication.shared` のみ — §11.4 例外) |
| `fatalError` / `preconditionFailure` | 1 件のみ:`WorkoutKitApp.swift:54`(ModelContainer 初期化失敗時、ブート不能エラー — 許容) |
| Combine 使用 | 確認していない(目視ベースで `import Combine` も未検出) |

### 2.2 ファイルサイズ(top 10、300 行超だけ表示)

```
315  Features/Session/SessionStore.swift
305  Features/History/HistoryView.swift
304  Features/Paywall/PaywallSections.swift
```

`SessionStore.swift` が 300 行超だが、関心が `Session 状態機 + Live Activity 連携 + 永続化`
で凝集しており、現時点では分割不要。`HistoryView.swift` は `HistoryCutoff` enum と
`HistoryMode` enum を内包しており、これらは別ファイル分離候補(`HistoryCutoff.swift`)。

### 2.3 ローカライズ

| 観点 | 結果 |
|---|---|
| 全 452 キー | ja / en 両方とも `state == translated`(missing/new/stale 0) |
| **未使用キー(コード参照なし)** | 9 件(下記、削除候補) |

```
builder.muscle.diagram.side.back
builder.muscle.diagram.side.front
builder.muscle.diagram.side.label
goal.fat-loss
session.live.ready          (実は WorkoutKitLiveActivity で参照あり、誤検出)
session.live.title          (同上)
session.header.goal %@      (同上、interpolation)
theme.dark.title
theme.light.title
theme.system.title
weight-unit.kilograms.title
weight-unit.pounds.title
```

> 厳密に未使用と確認できたのは 9 件:`builder.muscle.diagram.side.{back,front,label}`、
> `goal.fat-loss`、`theme.{dark,light,system}.title`、`weight-unit.{kilograms,pounds}.title`。
> 過去の refactor で取り残された孤児キー。

### 2.4 TODO

```
WorkoutKit/Features/Paywall/PaywallSections.swift:151:
  // TODO: 公開時に workoutkit.app の正式 URL に差し替える。
```

P-5(TestFlight 直前)で必須の差し替えとなる。1 件のみで、コード品質上の負債は最小。

---

## 3. Critical Bugs(ユーザー体験を損なう問題)

### Critical-1: 重量単位設定(kg ⇄ lbs)が表示に反映されない

`Settings → 単位` を切り替えても、Session/History の重量表示が
**全て `preference: .kilograms` でハードコード**されているため、
ユーザーには変更が一切見えない。

**根拠ファイル**:

```
Features/History/HistorySessionDetailView.swift:77,88,188
Features/History/HistoryComponents.swift:62
Features/History/HistoryListView.swift:212
Features/Session/SessionSetInputPanel.swift:114,127
```

すべて `UnitsFormatter.formatWeight(..., preference: .kilograms)` で固定。
`@AppStorage(SettingsKey.weightUnit)` を読まずに直接 `.kilograms` を渡している。

**影響**: §-1.4 で「設定で lbs に切替可」を明示しているのに、機能としては
**事実上未実装**の状態。Settings の UI は動くが効果ゼロのため、
ユーザーには「壊れている」と認識される。

**修正方向(別 PR)**:
- `WeightUnitPreference` を `@AppStorage` から取得する Environment Value を作る
- 各表示箇所で `@AppStorage(SettingsKey.weightUnit) private var weightUnitRaw: String`
  を読み、`WeightUnitPreference(rawValue:)` 経由で渡す
- 入力(`SessionSetInputPanel`)も同様(現状 0.5 kg 刻みハードコード)

---

### Critical-2: Live Activity の Task が fire-and-forget で Background Race を起こす

`SessionStore` 内で Live Activity を更新する Task が参照保持されておらず、
バックグラウンド遷移中に Task キャンセルされるとログ未保存・更新欠落の可能性。

**根拠ファイル**:

```
Features/Session/SessionStore+LiveActivity.swift:31
Features/Session/SessionStore.swift:204
Features/Session/LiveActivityClient.swift:57-60, 81, 93
```

`Task { await self.liveActivity.update(...) }` 形式でタスクハンドルを保持しないため、
連続したセット完了 → 休憩開始 のタイミングで前の更新が中断され、Live Activity の
Dynamic Island 表示が最新状態にならないケースがある。
Build warning 2 件もこの周辺(`LiveActivityClient.swift:81, 93`)。

**影響**: Live Activity の表示が一時的に古いセット番号を残す。データそのものは
SwiftData 側で別経路で保存されるためデータロスは発生しないが、UX 不整合。

**修正方向(別 PR)**:
- `liveActivityTask: Task<Void, Never>?` を `SessionStore` に持たせ、新規更新時は前の Task を `cancel()` してから生成
- もしくは `Activity` 更新を直列化する `actor` 内 task chain にする

---

### Critical-3: 30 日カットオフが TZ で挙動が変わる(境界日のセッションで ±1 日ズレる可能性)

`HistoryCutoff.freeWindowStart()` は `Calendar.current.date(byAdding: .day, value: -30)` 後に
`startOfDay` で正規化するが、`startedAt` は UTC ベースの `Date`。
ユーザーが TZ をまたいで移動した場合、本来 31 日目に該当する境界セッションが
無料窓から外れる/入る現象が発生する。

**根拠ファイル**:

```
Features/History/HistoryView.swift:23-27, 244, 249, 256
Features/History/HistoryListView.swift:117  (calendar.startOfDay)
Features/History/HistoryCalendarView.swift:163
Features/History/HistoryAggregations.swift:27, 64, 101  (週/月集計)
```

**影響**:
- 海外移動した直後、Pro でなくても 31 日目のセッションが見えてしまう、
  あるいは 30 日目のセッションが Pro 課金扱いになる
- チャートの週/月境界が ±1 日ズレる(集計値の小揺れ)

**修正方向(別 PR)**:
- カットオフ計算を `WorkoutSession.timeZoneIdentifier` ベースに揃える
  (もし保存しているなら)、保存していなければ「ユーザーの現在 TZ で十分」と
  仕様を明記してテストを追加する

---

### Critical-4: 手動エントリの `finishedAt` 推定が 1 セット = 60 秒固定

`ManualEntryStore.swift:98` で `finishedAt = startedAt + max(60, totalSetCount * 60)`。
3 時間のセッションも 20 セットなら 20 分扱いになる。

**根拠ファイル**:

```
Features/History/ManualEntryStore.swift:98-99, 103, 128
```

**影響**: 集計(週/月の総時間、平均セッション長)が manual 側だけ過小評価される。
チャートのバーが歪む。データ汚染が **手動エントリ全体に渡る**ため、
将来 Pro 機能の高度チャートを購入したユーザーがすぐに気付く。

**修正方向(別 PR)**:
- 手動エントリ画面で「実施時間」を必須入力にする(秒/分のステッパー)
- もしくは推定式を撤去して `finishedAt = startedAt`(ゼロ長)とし、
  集計側で「手動エントリは duration 計算から除外」にする

---

## 4. Major Bugs(機能不全 / 目立つ崩れ)

### Major-1: Builder の `nameMap` が body 評価ごとに再生成される

`Features/Builder/Steps/ResultStepView.swift:151-153` で
`Dictionary(uniqueKeysWithValues:)` を毎 body 評価で再構築。
345 種目 × 行数で再描画コストが膨らむ。

**修正方向**: `@State` メモ化、または `private let` で初期化時に確定。

### Major-2: Builder「全身」選択トグルが他の選択を破壊

`Features/Builder/BodyDiagram/BodyDiagramView.swift:181-186` で
`toggleFullBody()` が `selected = [.fullBody]` と destructive に書き換え。
ユーザーが胸を選択した後「全身」をタップすると胸の選択が消える。
(仕様確認必要 — UX 意図か bug か CLAUDE.md からは断定できない)

### Major-3: テンプレート「使う」が Session に渡らない

`Features/Templates/TemplateDetailView.swift:120-126` の `fireUse()` は
`GeneratorOutput` を作るだけでプレビューシートを開く。
コメントにも `B2 SessionStore に渡す想定` と書かれており未完。
プリセット 3 種を「使う」と押しても **Session 開始しない**(複製はできる)。

### Major-4: テンプレート Paywall stub が enum rawValue を生で表示

`Features/Templates/TemplateSheets.swift:144` で `feature.rawValue` を
そのまま `Text` に渡している(`customTemplates` のような開発用文字列が出る)。
本番 Paywall に差し替え必須。

### Major-5: タイマー再起動時の Task キャンセル前ウィンドウ

`Features/Session/SessionStore+Interval.swift:23` で
`intervalTask?.cancel()` 直後に新 Task を生成するため、
連続呼び出しで二重サブスクリプションが発生し得る。

### Major-6: LiveActivity の二重 `start()` で前回終了 await が残る

`Features/Session/LiveActivityClient.swift:57-60` のリスタート時 cleanup Task が
前回 Activity の完了待ちを永久に行う条件あり(activity が破棄されていれば await が解けない)。

### Major-7: Library 検索の Unicode 正規化が未対応

`Features/Library/ExerciseListView.swift:196,223` で
`.lowercased().contains()` のみ。
ICU 正規化(NFKC、ひらがな↔カタカナ)未対応。
コメント line 213 で「将来対応」と記述あり、MVP 許容範囲。

### Major-8: Library 詳細の英語ハードコード

`Features/Library/ExerciseDetailView.swift:76, 122, 126, 138` で
`Text("Steps")`, `Text("Primary muscle")`, `Text("Secondary muscles")`, `Text("Equipment")` が
**生の英文字列**。日本語ロケールでも英語のまま表示される。
String Catalog に既にキーがあるなら即修正可。

### Major-9: ManualEntryExercisePicker の英語ハードコード

`Features/History/ManualEntryExercisePicker.swift:37, 47, 52` で
`"Search exercises"`, `"Exercise library is empty"`, `"No matches"` が生英文字列。
Library と同じ問題。

### Major-10: lbs プリファレンス時のステッパーが kg 刻み

`Features/Session/SessionSetInputPanel.swift:107-129` の Stepper が
**0.5 kg 固定刻み**。lbs 設定でも 0.5 kg(≈1.1 lbs)で動く。
Imperial ユーザーには直感に合わない。
**Critical-1 と同根**(weight unit が UI に伝わっていない)。

### Major-11: RootView の Builder シートが背景化で消える

`App/RootView.swift:11` の `isBuilderPresented` が `@State` のため
バックグラウンド → フォアグラウンド復帰で `false` にリセット。
Builder ウィザードを途中まで進めて画面切替で戻ると最初からやり直しになる。
(`@SceneStorage` で永続化が望ましい)

---

## 5. Minor Bugs(翻訳ミス / 軽微 UI 問題)

### 5.1 Localization

- **未使用 l10n キー 9 件**(§2.3 参照)— 削除候補
- `Features/Templates/TemplateDetailView.swift:176` で
  `NSLocalizedString("muscle.\(muscle.rawValue)", ...)` の動的キー — 列挙ケース追加時に
  Localizable.xcstrings 側の追従漏れ検出が効かない
- `Features/Builder/Steps/TimeStepView.swift:70` の
  `a11y.builder.time.chip \(minutes)` の interpolation 妥当性確認(SwiftUI が
  `LocalizedStringKey` の interpolation を期待通り resolveするか要 device 検証)
- `Features/Paywall/PaywallView.swift:87,103` の
  `a11y.paywall.purchase.hint`, `a11y.paywall.restore.hint` キーが
  Localizable.xcstrings に存在するか要確認(Agent からの推測 — 読み取りで未確認)

### 5.2 Accessibility

- `GoalRow` のチェックマーク(`Features/Builder/Steps/GoalStepView.swift:60` 周辺)が
  `.accessibilityHidden(true)` で「選択中」が VoiceOver に伝わらない
- `IntervalCountdownView` の `.accessibilityAddTraits(.updatesFrequently)` のみで
  カウントダウン値の再アナウンスは iOS 17 以降では自動再読みされない可能性
- `SessionView.progressHeader` の `.accessibilityElement(children: .contain)` に
  `.accessibilityLabel` が無く一塊に読まれる
- TabBar の `Label(...)` が systemImage のみで補助ヒント未付与
- `TemplatesView` のスワイプアクションが「左にスワイプで Duplicate」の hint なし

### 5.3 Pro ゲート / 状態整合

- `Features/DataIO/DataIOView.swift:30-31` で **JSON import が CSV import の Pro feature を流用**
  (`feature: .csvImport`)。`ProFeature` enum に `.jsonImport` 不在のため。
  CLAUDE.md §-1.14 の表でも JSON import は明示されていないので仕様確認必要
- `Features/History/HistoryView.swift:279-288` の `handleAdvancedChartsRequested` が
  Paywall を開いた後の状態遷移が無く、ユーザーが購入をキャンセルすると
  「Charts ロック解除」ボタンが消えたままになる(再度ナビゲーションを離れて戻る必要)

### 5.4 Data Integrity

- `Features/Session/SessionStore.swift:172` の
  `order = completedSets.count` がレース時に同一 order を生成する可能性
- `Features/Session/SessionStore.swift:312` の `persist()` が catch error を
  ログのみで握り潰し、保存失敗が UI に伝わらない
- `Features/DataIO/JSONImporter.swift:220-235` で
  `ExerciseSet` 挿入時 `exercise: nil` を許容(orphan set 生成)
- `Features/DataIO/CSVImporter.swift:113-133`、`JSONImporter.swift:220-235` で
  途中失敗時のロールバックなし(部分保存される)
- `Features/DataIO/DataIOStore.swift:77` で `Data(contentsOf: url)` が
  ファイルサイズ無制限読み込み(極大 CSV/JSON で OOM)

### 5.5 BOM / Encoding

- `Features/DataIO/HistoryExporter.swift:53` が UTF-8 BOM を付加するが
  `Features/DataIO/CSVImporter.swift:30` の読み込み側は BOM strip なし(round-trip で
  最初のセルに `﻿` 混入の可能性)

### 5.6 Settings / About

- 「Restore Purchase」ボタンがネットワーク使用前の確認ダイアログなし
  (セルラー利用の警告が出ない、軽微)
- App Icon 変更(`ProFeature.appIconVariants`)に対応する Settings UI 不在
  (Pro feature 定義のみで導線がない)

### 5.7 Family Sharing / StoreKit

- `Transaction.updates` のリスナーは `start()` で起動するが、シーンフェーズ
  `.active` 復帰時に明示的なエンタイトルメント再評価フックなし。
  Family Sharing 解除直後のオフライン → オンライン復帰でラグが出る可能性
- 重複トランザクション処理が StoreKit 2 のデフォルトに依存(明示的な dedupe なし)

---

## 6. Code Quality Issues

| 観点 | 件数 / 状態 |
|---|---|
| Build Warnings | 22 件(うち 20 件は Swift 6 strict concurrency の `#Predicate` マクロ KeyPath Sendable、2 件は Live Activity `sending`) |
| `print()` | 0 件 ✅ |
| force unwrap | 0 件 ✅ |
| 自作 Singleton | 0 件 ✅ |
| 動画ファイル同梱 | 0 件 ✅(§-1 確定通り) |
| アナリティクス SDK | 0 件 ✅(§-1.11 確定通り) |
| TODO | 1 件(Paywall URL placeholder、P-5 で対応必須) |
| 大ファイル(300 行超) | 3 件(`SessionStore.swift`, `HistoryView.swift`, `PaywallSections.swift` — いずれも凝集度的には許容) |
| ハードコード英文字列 | 7 件(Library Detail, ManualEntryPicker — Major-8/Major-9 で詳述) |

---

## 7. Performance Notes(コード推測ベース)

- **Builder ResultStep**: nameMap の毎回再生成(Major-1)。345 種目で目立つ可能性
- **Library 検索**: 345 種目を毎キーストロークでメモリフィルタ。Swift 配列 filter は
  10000 件オーダーまでは数 ms 内で済むため許容範囲
- **History Charts**: `weeklyPoints / monthlyPoints / heatmap` が `body` 評価ごとに再計算
  (`HistoryChartsView.swift:138-150`)。1000 セッション超で `id` 安定性なし、
  iPad ランドスケープでフレームドロップの可能性
- **DataIO**: ファイルサイズ無制限 + 全件メモリ展開で大ファイル時 OOM(Minor、§5.4)

---

## 8. Recommendations(優先度順)

### P0(リリースブロッカー候補)

1. **Critical-1: 重量単位設定の伝播** — Settings UI が機能していない印象を与える。
   修正は `@AppStorage` を読む小規模変更で完結する見込み(本タスク外で別 PR 推奨)
2. **Critical-4: 手動エントリの finishedAt 推定撤去 or 入力化** — 集計データを汚染し続ける
3. **Critical-2: LiveActivity Task ハンドル管理** — Build warning も同根、Swift 6 移行前提なら必須
4. **Major-3: テンプレート「使う」→ Session 開始の B2 完了** — 価値提案の中核機能

### P1(高優先 — リリース前に着手したい)

5. Critical-3: 30 日カットオフの TZ 安全化(テスト追加で代替も可)
6. Major-8 / 9: Library 詳細・ManualEntryPicker の英文字列 → String Catalog
7. Major-4: テンプレート Paywall stub の差し替え
8. Major-1: ResultStepView の `nameMap` メモ化
9. Major-2: 「全身」選択トグルの UX 仕様確定

### P2(余裕があれば)

10. Minor 群:l10n 未使用キー削除、a11y ラベル整備、StoreKit シーンフェーズフック
11. Major-5/6: タイマー / Live Activity の再起動レース修正
12. Major-7: Library 検索の Unicode 正規化(MVP 後でも可)
13. Minor: DataIO の atomic 化 + ファイルサイズ上限 + エラー詳細の i18n
14. Minor: Major-11 (Builder シート の `@SceneStorage`)

### P3(技術的負債、低優先)

15. Build warnings(`#Predicate` Sendable)— Apple SDK 改善待ち。Swift 6 言語モード切替前に再評価
16. 大ファイル分割(`HistoryView.swift` 内の `HistoryCutoff` を `HistoryCutoff.swift` に)
17. `AppDependency.defaultValue` の Preview 用ファクトリ統一

---

## 9. Test Plan(別 PR で実施する際の検証観点)

- **Critical-1 修正後**: kg / lbs 切替で Session 入力・History 詳細・History リスト
  全箇所が更新されることを XCUITest または手動で確認
- **Critical-3 修正後**: TZ を変更したシミュレータ起動で 30 日境界セッションの
  扱いが期待通りであることを XCTest でユニット化
- **Critical-4 修正後**: 手動エントリ作成 → Charts の週合計時間がほぼゼロ
  (もしくは入力した時間)で表示されることを確認
- **Major-3 修正後**: テンプレート「使う」→ Session 画面遷移 → セット完了 → finishedAt 記録
  が回ることを XCUITest でカバー
- **Dynamic Type XL + 日本語**: Builder GoalRow / MuscleChip / EquipmentChip / ResultStep の
  ラベル切り捨てを目視確認(本タスクで未検証)
- **VoiceOver**: TabBar、Builder ウィザード、Session タイマー、Paywall 購入動線を
  実機スイープ(本タスクで未検証)

---

## 10. Artifacts

- `/tmp/debug-build.log` — フルビルドログ
- `/tmp/debug-warnings.txt` — ユニーク warning(22 件)
- `/tmp/debug-test.log` — テスト実行ログ(104 unit + 1 UI)
- `/tmp/debug-walk/01-launch.png` — Today タブ起動画面(Light)
- `/tmp/debug-walk/04-launch-dark.png` — Today タブ起動画面(Dark)

> シミュレータへのクリック注入が届かなかったため、Builder 以降の対話的スクショは未取得。
> 視覚回帰・a11y・Dynamic Type XL の確認は別タスクで XCUITest 化または実機操作で実施推奨。

---

## 11. レビュー実施範囲(コードリーディング)

| Feature | 対象ファイル数 | 主要発見 |
|---|---|---|
| Builder | 7 | `nameMap` 再生成 / 全身トグル UX / a11y 不整合 |
| Session | 8 | LiveActivity Task race / Interval cancel race / lbs 単位刻み |
| History | 8 | TZ-unsafe cutoff / 推定 finishedAt / Charts re-aggregation |
| Templates | 5 | 「使う」未完 / Paywall stub raw key / a11y |
| Library | 4 | 英ハードコード / Unicode 正規化 / YouTube Pro ゲート OK |
| Settings | 2 | 単位設定の伝播失敗(Critical-1 と同源) |
| Paywall | 5 | a11y key 存在確認 / Family Sharing scenePhase / 起動 paywall なし ✅ |
| DataIO | 8 | atomic 不在 / BOM 非対称 / ファイルサイズ無制限 |
| Today / Root | 3 | iPad NavigationSplitView 内包設計 ✅ / Builder シート永続化なし |

合計 50 ファイル超の Swift コードを 6 並列 Explore Agent で精読。
コードベースは全体として **NG リスト準拠が高く、テストカバレッジも厚い**。
重大バグの大半は「データ流」(設定 → 表示、TZ → 集計、推定値 → 永続化)に集中している。

---

*Report compiled by debug pass on 2026-05-04 by claude-opus-4-7@1m / debug/comprehensive-pass*

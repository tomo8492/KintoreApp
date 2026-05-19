# CLAUDE.md — WorkoutKit 設計書 v1.0

# 市場調査統合版 / Claude Code 参照用

> **このファイルはClaude Codeが常時参照する設計書です。**
> 実装前に必ずこのファイル全体を読み込んでください。
> 変更時はバージョン番号とChangelog末尾を更新してください。

---

## 目次

1. [プロジェクト概要](#1-プロジェクト概要)
2. [市場調査サマリー(意思決定の根拠)](#2-市場調査サマリー意思決定の根拠)
3. [技術スタック](#3-技術スタック)
4. [アーキテクチャ設計](#4-アーキテクチャ設計)
5. [機能仕様](#5-機能仕様)
6. [収益化設計](#6-収益化設計)
7. [UI/UX設計方針](#7-uiux設計方針)
8. [ASO戦略](#8-aso戦略)
9. [実装ロードマップ](#9-実装ロードマップ)
10. [品質基準・完了定義](#10-品質基準完了定義)
11. [制約・禁止事項](#11-制約禁止事項)
12. [Changelog](#12-changelog)

---

## 1. プロジェクト概要

| 項目 | 内容 |
|---|---|
| アプリ名 | WorkoutKit |
| Bundle ID | `com.tomo.workoutkit` |
| カテゴリ | Health & Fitness |
| 対象OS | iOS 18.0以上(AI機能はiOS 26以上) |
| 対象端末 | iPhone(メイン)/ Apple Watch(ウィジェットのみ) |
| 開発者 | Tomo(個人開発) |
| ベースリポジトリ | workout-cool fork |
| 収益モデル | フリーミアム → サブスクリプション(ハードペイウォール) |
| 月額価格 | ¥980 / 月(7日間無料トライアル付き) |
| 年額価格 | ¥4,900 / 年(7日間無料トライアル付き) |
| 収益管理 | RevenueCat + StoreKit 2 |
| 目標MRR(6か月) | ¥300,000(約300人有料転換) |
| 目標MRR(12か月) | ¥980,000(約1,000人有料転換) |

### コアバリュープロポジション

> **「記録するだけで、AIが次のアクションを教えてくれる筋トレアプリ」**

- オンデバイスAI(Foundation Models Framework)でプライバシー完全保護
- Live Activitiesでセット間レストをロック画面に表示
- Apple Watch Smart Stackで今日の記録を一目確認

---

## 2. 市場調査サマリー(意思決定の根拠)

> このセクションは実装の意思決定根拠です。機能の優先順位判断時に参照してください。

### 2-1. 市場規模・成長性

- 全世界アプリIAP収益:2024年 **$150B(+13% YoY)**、2025年 **$167B(+10.6%)**
- **非ゲームアプリが2025年史上初めてゲーム収益を上回った**
- Health & Fitness:2024年に **+24% YoY** の急成長カテゴリ
- iOS ARPU $138 vs Android $72 → **iOSが収益2倍**
- 日本市場は世界第3位($16.5B)

### 2-2. 競合優位性の根拠

| 機能 | 競合アプリ | WorkoutKit |
|---|---|---|
| AIワークアウト分析 | サーバー送信型(有料API) | **オンデバイス(無料・プライベート)** |
| レストタイマー | アプリ内表示のみ | **Live Activities(ロック画面表示)** |
| Apple Watch | フルアプリ必要 | **Smart Stackウィジェット(軽量)** |
| 価格 | $9.99〜$19.99/月 | **¥980/月(競合の1/3〜1/2)** |

### 2-3. 収益化モデルの根拠(RevenueCatデータ)

- **ハードペイウォール**のD35転換率 **12.1%** vs フリーミアム2.1%(**5倍差**)
- トライアル→有料転換の **50%以上が24時間以内**に発生
- 年額プランは月額比で **年36%のユーザー保持**(月額は6.7%)
- 週次プランは新規サブの約半数だが4か月で2/3が離脱→**年額をデフォルト推奨**
- 平均月額サブ(iOS米国):$15.20、年額:$44.60 → ¥980/月は競争力ある価格

### 2-4. 技術選定の根拠

- **Foundation Models Framework(iOS 26)**:約3Bパラメータのオンデバイス推論
  - 推論コスト¥0、プライバシー完全保護、3行でアクセス可能
  - SmartGym、Day One、STOICなど複数アプリが既に採用
- **Live Activities(ActivityKit)**:リテンション +2.7倍(Brazeデータ)
- **watchOS Smart Stack**:追加実装コスト小、発見性高い

### 2-5. 参入判断の根拠

- Health & Fitnessカテゴリは月収$5K〜$50Kの中堅アプリが多数存在 → **個人開発の勝機あり**
- 成功事例:HabitKit(習慣トラッカー)がMRR $15,000以上、SmartGym(AI連携フィットネス)が単独開発でARR数十万ドル
- **「AI + フィットネス」の組み合わせは2025年最大の成長セグメント**

---

## 3. 技術スタック

### 3-1. メインスタック

```
言語          Swift 6(strict concurrency 対応必須)
UI            SwiftUI(全画面)
データ         SwiftData(iOS 17以上)
状態管理       @Observable マクロ(iOS 17以上)
依存管理       Swift Package Manager(SPM)
```

### 3-2. フレームワーク一覧

```
Foundation Models Framework  iOS 26以上  オンデバイスAI推論
ActivityKit                  iOS 16.2以上  Live Activities
WidgetKit                    iOS 14以上   Home/Lock Screen/Watch Widget
HealthKit                    iOS 8以上    歩数・心拍連携(オプション)
StoreKit 2                   iOS 15以上   課金処理
RevenueCat SDK               iOS 13以上   サブスク管理・分析
```

### 3-3. 外部ライブラリ(SPM)

```swift
// Package.swift dependencies
.package(url: "https://github.com/RevenueCat/purchases-ios", from: "5.0.0"),
```

### 3-4. App Groups(データ共有)

```
group.com.tomo.workoutkit
```

> iPhone ↔ Watch ウィジェット間のSwiftDataコンテナ共有に使用

### 3-5. 対象プラットフォーム

```
iOS 18.0+    メインアプリ(必須)
iOS 26.0+    AI機能(#available分岐、非対応端末は非表示)
watchOS 11+  Smart Stackウィジェット
```

---

## 4. アーキテクチャ設計

### 4-1. ディレクトリ構成

```
WorkoutKit/
├── App/
│   ├── WorkoutKitApp.swift          // エントリーポイント・RevenueCat初期化
│   └── AppRouter.swift              // 画面遷移管理
│
├── Features/
│   ├── Workout/
│   │   ├── WorkoutListView.swift    // ワークアウト一覧
│   │   ├── WorkoutDetailView.swift  // ワークアウト実行画面
│   │   ├── SetCompleteButton.swift  // セット完了ボタン
│   │   └── WorkoutSummaryView.swift // 終了サマリー画面
│   │
│   ├── AICoach/                     // 【新機能】AI要約
│   │   ├── AICoachView.swift        // サマリー画面内コンポーネント
│   │   ├── WorkoutInsightGenerator.swift  // Foundation Models呼び出し
│   │   └── WorkoutInsight.swift     // @Generableモデル定義
│   │
│   ├── LiveActivity/               // 【新機能】レストタイマー
│   │   ├── RestTimerAttributes.swift       // ActivityAttributes定義
│   │   ├── RestTimerLiveActivityView.swift // Dynamic Island / Lock Screen UI
│   │   └── RestTimerManager.swift          // Activity ライフサイクル管理
│   │
│   ├── Paywall/                    // 【新機能】課金UI
│   │   ├── PaywallView.swift       // ペイウォール画面
│   │   └── PurchaseManager.swift   // RevenueCat wrapper(@Observable)
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       └── RestoreView.swift       // 購入復元(審査要件)
│
├── Models/
│   ├── WorkoutSession.swift        // SwiftDataモデル
│   ├── Exercise.swift
│   └── WorkoutSet.swift
│
├── Shared/
│   ├── Extensions/
│   ├── Helpers/
│   └── Constants.swift             // Bundle ID、Group ID、Product ID等
│
└── WorkoutKitWatch/                // watchOS Extension
    ├── WorkoutKitWatchWidget.swift
    ├── WorkoutWidgetEntry.swift
    └── WorkoutWidgetProvider.swift
```

### 4-2. データフロー

```
SwiftData(Shared Container: group.com.tomo.workoutkit)
  │
  ├── iPhone App ──→ WorkoutSession / Exercise / WorkoutSet
  │                      │
  │                      ├──→ AICoach(Foundation Models)
  │                      ├──→ Live Activities(ActivityKit)
  │                      └──→ HealthKit(オプション)
  │
  └── Watch Widget ──→ 今日のWorkoutSession読み取り(読み取りのみ)
```

### 4-3. 状態管理パターン

```swift
// @Observable を使用(Swift 5.9以上、iOS 17以上)
@Observable final class PurchaseManager { ... }
@Observable final class RestTimerManager { ... }
@Observable final class WorkoutSessionManager { ... }

// Environment経由でView階層に注入
.environment(PurchaseManager.shared)
.environment(RestTimerManager.shared)
```

---

## 5. 機能仕様

### 5-1. 機能一覧とフェーズ

| 機能 | フェーズ | 対象OS | Premium? |
|---|---|---|---|
| ワークアウト記録(基本) | 既存 | iOS 18+ | No(フリー) |
| 種目・セット管理 | 既存 | iOS 18+ | No(フリー) |
| **ペイウォール(RevenueCat)** | Phase 1 | iOS 18+ | — |
| **レストタイマー Live Activities** | Phase 2 | iOS 18+ | **Yes** |
| **AI ワークアウト要約** | Phase 3 | iOS 26+ | **Yes** |
| **Apple Watch Smart Stack** | Phase 4 | watchOS 11+ | **Yes** |
| HealthKit 心拍連携 | Phase 5 | iOS 18+ | **Yes** |
| 進捗グラフ | Phase 5 | iOS 18+ | **Yes** |

> **フリー機能はワークアウト記録のみ。** プレミアム機能にタッチした瞬間にペイウォールを表示する。

---

### 5-2. 機能詳細:AI ワークアウト要約

#### 概要

ワークアウト終了後、当日のトレーニング内容をオンデバイスLLMで分析し、
日本語で2〜3文のコーチングコメントを生成する。

#### データモデル

```swift
import FoundationModels

@Generable
struct WorkoutInsight {
    /// 全体要約(1文、最大60文字)
    @Guide(description: "今日のトレーニング全体を1文で要約してください")
    var summary: String

    /// ハイライト種目名
    @Guide(description: "最も成果があった種目名を1つ答えてください")
    var highlight: String

    /// 明日へのアドバイス(1文、最大60文字)
    @Guide(description: "明日のトレーニングや回復に向けたアドバイスを1文で答えてください")
    var advice: String
}
```

#### 実装仕様

```swift
// WorkoutInsightGenerator.swift
final class WorkoutInsightGenerator {
    func generate(from session: WorkoutSession) async -> WorkoutInsight? {
        guard #available(iOS 26, *) else { return nil }

        let model = SystemLanguageModel.default

        // 可用性チェック
        guard case .available = model.availability else { return nil }

        let prompt = buildPrompt(from: session)

        do {
            let session = LanguageModelSession()
            let result = try await session.respond(
                to: prompt,
                generating: WorkoutInsight.self
            )
            return result.content
        } catch {
            return nil
        }
    }

    private func buildPrompt(from session: WorkoutSession) -> String {
        """
        以下のワークアウト記録を分析して、日本語でフィードバックを生成してください。

        日付: \(session.date.formatted(date: .abbreviated, time: .omitted))
        実施種目: \(session.exercises.map { $0.name }.joined(separator: "、"))
        総セット数: \(session.totalSets)セット
        総ボリューム: \(session.totalVolume)kg
        前回比較: \(session.volumeDifferenceText)

        フィードバックは以下の形式で、励ましつつ具体的にお願いします。
        """
    }
}
```

#### UIコンポーネント

```swift
// AICoachView.swift
struct AICoachView: View {
    let session: WorkoutSession

    @State private var insight: WorkoutInsight?
    @State private var isLoading = false

    var body: some View {
        if #available(iOS 26, *) {
            VStack(alignment: .leading, spacing: 12) {
                Label("AIコーチ", systemImage: "sparkles")
                    .font(.headline)

                if isLoading {
                    ProgressView("分析中...")
                        .frame(maxWidth: .infinity)
                } else if let insight {
                    InsightCardView(insight: insight)
                } else {
                    Text("分析できませんでした")
                        .foregroundStyle(.secondary)
                }
            }
            .task { await loadInsight() }
        }
        // iOS 26未満では何も表示しない(UIを崩さない)
    }

    private func loadInsight() async {
        isLoading = true
        insight = await WorkoutInsightGenerator().generate(from: session)
        isLoading = false
    }
}
```

---

### 5-3. 機能詳細:Live Activities(レストタイマー)

#### 概要

セット完了後のレスト時間をDynamic Island・ロック画面にリアルタイム表示。
**毎秒のActivityUpdate(バッテリー消耗)は避け、終了時刻を渡して端末側でカウント。**

#### ActivityAttributes 定義

```swift
// RestTimerAttributes.swift
import ActivityKit

struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endTime: Date          // レスト終了時刻
        var exerciseName: String   // 現在の種目名
        var nextSetNumber: Int     // 次のセット番号
        var restDuration: Int      // レスト時間(秒)設定値
    }

    let workoutName: String        // ワークアウト名
}
```

#### Dynamic Island / Lock Screen UI

```swift
// RestTimerLiveActivityView.swift
struct RestTimerLiveActivityView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        // ロック画面 / Standby
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(.orange)

            VStack(alignment: .leading) {
                Text(context.state.exerciseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("セット \(context.state.nextSetNumber) 準備中")
                    .font(.headline)
            }

            Spacer()

            // TimelineView を使って端末側でカウント(ActivityUpdateは不要)
            Text(context.state.endTime, style: .timer)
                .font(.title2.monospacedDigit())
                .foregroundStyle(.orange)
        }
        .padding()
    }
}
```

#### Manager クラス

```swift
// RestTimerManager.swift
@Observable final class RestTimerManager {
    static let shared = RestTimerManager()

    private var currentActivity: Activity<RestTimerAttributes>?

    func start(
        exerciseName: String,
        setNumber: Int,
        restSeconds: Int,
        workoutName: String
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let endTime = Date.now.addingTimeInterval(Double(restSeconds))
        let attributes = RestTimerAttributes(workoutName: workoutName)
        let state = RestTimerAttributes.ContentState(
            endTime: endTime,
            exerciseName: exerciseName,
            nextSetNumber: setNumber + 1,
            restDuration: restSeconds
        )

        let content = ActivityContent(state: state, staleDate: endTime)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil   // ローカル更新のみ
            )
        } catch { }
    }

    func stop() async {
        await currentActivity?.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }
}
```

---

### 5-4. 機能詳細:Apple Watch Smart Stack ウィジェット

#### 概要

**Watch App本体は作らない。** Smart Stack用の `accessoryRectangular` ウィジェットのみ実装。

#### TimelineEntry / Provider

```swift
// WorkoutWidgetEntry.swift
struct WorkoutWidgetEntry: TimelineEntry {
    let date: Date
    let isCompleted: Bool
    let totalSets: Int
    let exerciseCount: Int
}

// WorkoutWidgetProvider.swift
struct WorkoutWidgetProvider: TimelineProvider {
    func getSnapshot(in context: Context, completion: @escaping (WorkoutWidgetEntry) -> Void) {
        completion(WorkoutWidgetEntry(date: .now, isCompleted: false, totalSets: 0, exerciseCount: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutWidgetEntry>) -> Void) {
        let todaySession = fetchTodaySession()  // App Groupsから読み取り

        let entry = WorkoutWidgetEntry(
            date: .now,
            isCompleted: todaySession != nil,
            totalSets: todaySession?.totalSets ?? 0,
            exerciseCount: todaySession?.exercises.count ?? 0
        )

        // 1時間ごとに更新
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchTodaySession() -> WorkoutSession? {
        // App Groups経由でSwiftDataから今日のセッションを取得
        // group.com.tomo.workoutkit
        return nil // TODO: 実装
    }
}
```

#### ウィジェットUI

```swift
// WorkoutKitWatchWidget.swift
struct WorkoutKitWatchWidgetEntryView: View {
    var entry: WorkoutWidgetProvider.Entry

    var body: some View {
        HStack {
            Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "figure.strengthtraining.traditional")
                .foregroundStyle(entry.isCompleted ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isCompleted ? "完了 ✅" : "未実施")
                    .font(.headline)

                if entry.isCompleted {
                    Text("\(entry.exerciseCount)種目 · \(entry.totalSets)セット")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("今日トレーニングしよう")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

---

## 6. 収益化設計

### 6-1. 商品定義(App Store Connect)

| Product ID | 種別 | 価格 | トライアル | 表示名 |
|---|---|---|---|---|
| `workoutkit_monthly_980` | Auto-Renewable Subscription | ¥980/月 | 7日間無料 | WorkoutKit プレミアム(月額) |
| `workoutkit_yearly_4900` | Auto-Renewable Subscription | ¥4,900/年 | 7日間無料 | WorkoutKit プレミアム(年額) |

> **¥4,900/年 = 月あたり約¥408 → 年額は月額より¥6,860お得**(UI上でバッジ表示)
> 算式: 月額 ¥980 × 12 = ¥11,760、年額 ¥4,900 を引いて差額 ¥6,860。
> ※ v1.0 ドラフト時点の暫定値 ¥7,372 は誤りだったため訂正(2026-05-18)。

### 6-2. Subscription Group

```
Group名: WorkoutKit Premium
Entitlement名(RevenueCat): premium
```

### 6-3. RevenueCat 初期化

```swift
// WorkoutKitApp.swift
import RevenueCat
import SwiftUI

@main
struct WorkoutKitApp: App {
    init() {
        Purchases.logLevel = .debug  // リリース前は .error に変更
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(PurchaseManager.shared)
                .environment(RestTimerManager.shared)
        }
    }
}
```

### 6-4. PurchaseManager

```swift
// PurchaseManager.swift
import RevenueCat

@Observable final class PurchaseManager {
    static let shared = PurchaseManager()

    var isPremium: Bool = false
    var isLoading: Bool = false

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        let info = try? await Purchases.shared.customerInfo()
        isPremium = info?.entitlements["premium"]?.isActive == true
    }

    func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
    }

    func restore() async throws {
        isLoading = true
        defer { isLoading = false }

        let info = try await Purchases.shared.restorePurchases()
        isPremium = info.entitlements["premium"]?.isActive == true
    }
}
```

### 6-5. ペイウォール表示ロジック

```swift
// 表示タイミング(優先順)
// 1. 初回起動3日後(@AppStorage("launchCount") で管理)
// 2. プレミアム機能(AI要約 / Live Activities / Watch連携)タップ時
// 3. Settings > プレミアムにアップグレード タップ時

// 実装パターン
.sheet(isPresented: $showPaywall) {
    PaywallView()
}
```

### 6-6. PaywallView 仕様

```
レイアウト(上から):
┌─────────────────────────────────┐
│  🏆 WorkoutKit プレミアム        │
│  AIコーチで、もっと賢く鍛える    │
├─────────────────────────────────┤
│  ✨ AI ワークアウト要約          │
│  ⏱️  Live Activityレストタイマー │
│  ⌚ Apple Watch対応             │
│  📊 進捗グラフ(今後追加)       │
├─────────────────────────────────┤
│  [年額 ¥4,900]  ← デフォルト選択 │
│   月あたり約¥408 / 7日間無料     │
│   💡 月額より¥6,860お得バッジ    │
│                                 │
│  [月額 ¥980]                    │
│   7日間無料トライアル付き        │
├─────────────────────────────────┤
│  [無料で始める]  ← 年額ボタンの下│
│  [購入を復元する]                │
│  利用規約 / プライバシーポリシー  │
└─────────────────────────────────┘
```

> **年額をデフォルト選択状態にする。** 月額は2番目に表示。
> 「無料で始める」はタップするとペイウォールを閉じる(フリー機能のみ利用可)。

---

## 7. UI/UX設計方針

### 7-1. デザイン原則

- **シンプル・高速**:ワークアウト中に操作。タップ数を最小化。
- **大きなタップターゲット**:汗をかいた手でも操作可能(最小44×44pt厳守)
- **ダークモード必須対応**:ジム環境での視認性
- **オレンジアクセント**:エネルギー・活力を想起。`Color.orange`

### 7-2. カラーパレット

```swift
// Constants.swift 内
enum AppColor {
    static let accent = Color.orange
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let success = Color.green
    static let destructive = Color.red
}
```

### 7-3. フォント

```swift
// ワークアウト中の数値表示
.font(.system(size: 48, weight: .bold, design: .rounded))

// セクションヘッダー
.font(.headline)

// 補足テキスト
.font(.caption).foregroundStyle(.secondary)
```

### 7-4. アニメーション

- セット完了:チェックマーク + `hapticFeedback(.success)`
- AI生成中:`ProgressView` + `sparkles` アイコンアニメーション
- ペイウォール表示:`.sheet` 遷移(デフォルト)

---

## 8. ASO戦略

### 8-1. App Store メタデータ

```
アプリ名(30文字以内):
  WorkoutKit - AI筋トレ記録

サブタイトル(30文字以内):
  AIコーチ×Live Activityで効率UP

キーワード(100文字以内):
  筋トレ,ワークアウト,トレーニング,記録,AI,フィットネス,
  ジム,筋肉,重量管理,体重,セット,レスト
```

### 8-2. スクリーンショット戦略(5枚)

```
1枚目: ワークアウト記録画面 + 「かんたん記録」テキスト
2枚目: Live Activity(Dynamic Island)+ 「レストタイマーが画面に」
3枚目: AI要約画面(AIコーチのコメント)+ 「AIが次の行動を提案」
4枚目: Apple Watch Smart Stack + 「Apple Watchで記録確認」
5枚目: ペイウォール画面 + 「7日間無料で始める」
```

> スクリーンショットのテキストにキーワードを自然に含める(iOS 26よりランキング要因)

### 8-3. App Preview動画(30秒)

```
0〜5秒:   ワークアウト記録のシンプルな操作
5〜15秒:  セット完了→Dynamic Islandにタイマー表示
15〜25秒: ワークアウト終了→AI要約生成(スパークルアニメーション)
25〜30秒: Apple Watchでの確認
```

### 8-4. カスタムプロダクトページ(CPP)計画

| CPP名 | キーワード | 差別化ポイント |
|---|---|---|
| default | 筋トレ 記録 | バランス型 |
| ai-coach | AI 筋トレ 分析 | AI強調 |
| live-activity | レストタイマー Dynamic Island | 機能強調 |
| beginners | 筋トレ 初心者 | 入門者向け |

> Apple Search Ads と CPP を紐付け、CV率テスト(目標+5.9%)

---

## 9. 実装ロードマップ

### Phase 1:収益基盤(目安:2週間)

- [ ] RevenueCat SDK セットアップ
- [ ] App Store Connect 商品登録(月額・年額)
- [ ] PurchaseManager 実装(@Observable)
- [ ] PaywallView 実装(仕様通り)
- [ ] 復元購入ボタン実装(審査要件)
- [ ] Secrets.swift 作成(.gitignore 追加)
- [ ] `isPremium` フラグで既存機能をガード

### Phase 2:Live Activities(目安:1週間)

- [ ] `NSSupportsLiveActivities = YES`(Info.plist)
- [ ] RestTimerAttributes 定義
- [ ] RestTimerLiveActivityView(Dynamic Island + Lock Screen)
- [ ] RestTimerManager(start / stop)
- [ ] SetCompleteButton からの呼び出し統合
- [ ] シミュレーターでDynamic Island 表示確認

### Phase 3:AI ワークアウト要約(目安:1週間)

- [ ] Foundation Models Framework リンク(iOS 26 SDK)
- [ ] WorkoutInsight(@Generable)定義
- [ ] WorkoutInsightGenerator 実装
- [ ] AICoachView 実装(ローディング / エラーハンドリング含む)
- [ ] WorkoutSummaryView への統合
- [ ] iOS 26 シミュレーターで動作確認

### Phase 4:Apple Watch ウィジェット(目安:1週間)

- [ ] watchOS Extension target 追加
- [ ] App Groups 設定(group.com.tomo.workoutkit)
- [ ] SwiftData Shared Container 設定
- [ ] WorkoutWidgetProvider / Entry 実装
- [ ] WorkoutKitWatchWidgetEntryView(accessoryRectangular)実装
- [ ] Watch シミュレーターの Smart Stack 表示確認

### Phase 5:ポリッシュ・ASO(目安:1週間)

- [ ] スクリーンショット 5枚作成
- [ ] App Preview 動画作成(30秒)
- [ ] App Store メタデータ入力
- [ ] TestFlight 配布(10〜20人にフィードバック)
- [ ] クラッシュゼロ確認(Xcode Organizer)
- [ ] App Store 審査提出

---

## 10. 品質基準・完了定義

### 10-1. 各機能の完了定義(Definition of Done)

#### RevenueCat / Paywall

- [ ] サンドボックス環境で月額・年額の購入フローが完走する
- [ ] 購入後 `isPremium == true` になる
- [ ] 復元購入が正常に動作する
- [ ] 未購入状態でプレミアム機能タップ時にペイウォールが表示される
- [ ] ペイウォール閉じた後にフリー機能に戻れる

#### Live Activities

- [ ] セット完了ボタンタップ時にDynamic Islandに種目名・秒数が表示される
- [ ] アプリをバックグラウンドにしてもカウントが継続する
- [ ] レスト終了後に自動でLive Activityが消える
- [ ] 非対応端末(iPhone 14以前)でクラッシュしない

#### AI ワークアウト要約

- [ ] iOS 26 シミュレーターで要約テキストが生成される
- [ ] 生成中は ProgressView が表示される
- [ ] 生成失敗時はエラーメッセージが表示される(クラッシュしない)
- [ ] iOS 25以下の端末ではAICoachViewが非表示になる

#### Apple Watch ウィジェット

- [ ] Watch シミュレーターの Smart Stack に今日の記録が表示される
- [ ] 未記録の日は「未実施」表示になる
- [ ] 1時間ごとに更新される
- [ ] iPhone側でワークアウト記録後、Watch側のデータが反映される

### 10-2. 審査前チェックリスト

- [ ] 復元購入ボタンが設置されている(App Store審査要件)
- [ ] プライバシーポリシーURLが設定されている
- [ ] `NSSupportsLiveActivities` = YES(Live Activities使用時)
- [ ] HealthKit使用する場合は `NSHealthShareUsageDescription` を記述
- [ ] Foundation Models使用時の `NLRequestUsageDescription` を確認
- [ ] In-App Purchase商品がApp Store Connect上でApprovedになっている
- [ ] サンドボックスで全課金フローをテスト済み
- [ ] iPad対応(または「iPhone only」設定を明示)
- [ ] スクリーンショットが全対象サイズ(6.9インチ必須)で用意されている

---

## 11. 制約・禁止事項

### 11-1. Swift 6 Concurrency

```swift
// ✅ 正しい
@MainActor final class WorkoutSessionManager { ... }

// ❌ 禁止
final class WorkoutSessionManager {
    var sessions: [WorkoutSession] = []  // Swift 6でコンパイルエラー
}
```

- `@MainActor`、`Sendable`、`actor` を適切に付与すること
- `@unchecked Sendable` の乱用禁止(理由がある場合はコメント必須)

### 11-2. Foundation Models Framework

```swift
// ✅ 正しい:#available 分岐必須
if #available(iOS 26, *) {
    AICoachView(session: session)
}

// ❌ 禁止:分岐なしの使用
let model = SystemLanguageModel.default  // iOS 25以下でクラッシュ
```

### 11-3. Live Activities 更新頻度

```swift
// ✅ 正しい:終了時刻を渡して端末側でカウント
Text(endTime, style: .timer)

// ❌ 禁止:毎秒 updateActivity(バッテリー消耗・AppleのRate Limit違反)
Task {
    while true {
        try await Task.sleep(for: .seconds(1))
        await activity.update(...)  // これを毎秒は禁止
    }
}
```

### 11-4. データ管理

- SwiftData の Model Context は `@MainActor` 上で操作すること
- バックグラウンドで重い処理をする場合は `ModelActor` を使用
- App Groups の Container URL を直接操作する場合は必ず `FileManager` 経由

### 11-5. セキュリティ

```swift
// Secrets.swift(.gitignoreに追加済みであること)
enum Secrets {
    static let revenueCatAPIKey = "appl_xxxxxxxxxxxxxxxxxx"
}
```

- API KeyをハードコードしてGitにコミットすること禁止
- Xcconfig または Secrets.swift で管理

### 11-6. UI制約

- タップターゲット最小44×44pt厳守
- ダークモード・ライトモード両方でテスト必須
- Dynamic Type(文字サイズ変更)に対応すること(`.font()` を固定 pt で指定しない)

---

## 12. Changelog

| バージョン | 日付 | 変更内容 |
|---|---|---|
| v1.0 | 2026-05-15 | 市場調査統合版として新規作成。AI要約・Live Activities・Watch Widget・ペイウォールを追加 |

---

*このファイルは WorkoutKit プロジェクトのルートディレクトリに配置してください。*
*Claude Code はセッション開始時にこのファイルを自動で参照します。*

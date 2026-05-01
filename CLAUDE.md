# WorkoutKit (仮) — iOS フィットネスコーチングアプリ 開発仕様書

> **参考プロジェクト**: [Snouzy/workout-cool](https://github.com/Snouzy/workout-cool) (★7.2k, MIT License, Next.js 15 + Prisma + PostgreSQL, Feature-Sliced Design)
> Web版を参考に、純ネイティブiOSアプリとして再設計。
>
> **本ドキュメントの位置づけ**: 要件定義 + アーキテクチャ設計 + Claude Code 用開発指示書(CLAUDE.md)を兼ねる。Cursor / Xcode / Claude Code から本ファイルをルートに配置して使用することを想定。
>
> **workout-cool 由来で取り込む要素**: ① エクササイズ属性ベースのスキーマ ② TYPE/PRIMARY_MUSCLE/SECONDARY_MUSCLE/EQUIPMENT/MECHANICS_TYPE の5属性体系 ③ slug ベースのID ④ 多言語フィールド(日英2語並列) ⑤ ウォームアップ/メイン/クールダウンの3部構成セッション ⑥ Shuffle と Choose Exercise の2モード ⑦ CSVインポート対応。

-----

## 🚨 §-1. 最初に確定すべき設定(Foundation Locks)

> **このセクションが本書で最も重要**。後から変更すると影響範囲が広いものを網羅する。Xcodeプロジェクト作成 **より前** に全項目を確定すること。

### -1.1 アイデンティティ(✅全確定)

|項目                          |**確定値**                                          |確定後の変更コスト                  |
|----------------------------|-------------------------------------------------|---------------------------|
|**App Display Name**        |`WorkoutKit` (仮、公開時に最終決定)                        |低                          |
|**Bundle ID**               |**`com.tomo.workoutkit`**                        |**極高**(App Store公開後は実質変更不可)|
|**Team ID**                 |Apple Developer Program 登録時に取得                   |-                          |
|**Apple ID 名義**             |**個人アカウント**                                      |高(法人化時に移管)                 |
|**App Store Connect Record**|TestFlight 直前(Phase P5)で作成                       |-                          |
|**App Category**            |Primary: `Health & Fitness` / Secondary: `Sports`|中                          |
|**Minimum iOS**             |**`iOS 17.0`**(SwiftData/Observation のため)        |中                          |
|**Supported Devices**       |**iPhone + iPad 両対応**(初版から)                      |中                          |
|**Orientation**             |iPhone: Portrait のみ / iPad: Portrait + Landscape |中                          |
|**License**                 |**Proprietary**(個人非公開、App Storeのみ)               |低                          |
|**配布方法**                    |**App Store 一般公開**                               |-                          |
|**課金モデル**                   |**Freemium**(基本無料 + Pro機能を IAP で買い切り)            |中(価格変更は容易)                 |
|**Pro 価格(初回)**              |**¥600**(Launch Price、最初の3か月)                    |低                          |
|**Pro 価格(通常)**              |**¥980**(買い切り、Non-Consumable IAP)                |低                          |
|**Subscription Group**      |不要(サブスクではない)                                     |-                          |
|**IAP Product ID**          |`com.tomo.workoutkit.pro.unlock`                 |中                          |

### -1.2 IDとスキーマの基本方針(SwiftDataで一番大事)

**決め事**: workout-cool の `id`(数値)と `slug`(文字列)の二重持ちは継承するが、**SwiftData主キーは `slug`** とする。

|観点                              |採用                                      |理由                                       |
|--------------------------------|----------------------------------------|-----------------------------------------|
|Exercise の主キー                   |`slug: String` (例: `barbell-back-squat`)|CSV再インポートで安定、URL/ディープリンクに使える、テストデータで読みやすい|
|WorkoutSession / ExerciseSet 主キー|`id: UUID`                              |端末固有、衝突しない                               |
|Template 主キー                    |`id: UUID`                              |同上                                       |
|外部CSVの数値ID                      |`legacyCsvId: Int?` (任意保持)              |workout-cool との突合用                       |


> **この決定の影響**: `slug` は世界に1つしかない安定IDになる。ローカライズで slug は変えない(英語slugで固定。日本語は表示用の `slugJa` を別カラムで持つ)。

### -1.3 SwiftData スキーマバージョニング

> SwiftDataはマイグレーションを **VersionedSchema + SchemaMigrationPlan** で扱う。**初日から V1 として明示**しないと後でハマる。

```swift
// Domain/Schema/SchemaV1.swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Exercise.self, WorkoutSession.self, ExerciseSet.self, Template.self]
    }
}

// Domain/Schema/MigrationPlan.swift
enum WorkoutKitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }  // V1 のみは空
}

// WorkoutKitApp.swift
let container = try ModelContainer(
    for: SchemaV1.self,
    migrationPlan: WorkoutKitMigrationPlan.self,
    configurations: ModelConfiguration(...)
)
```

破壊的変更(カラム削除など)は必ず V2 に上げて MigrationStage を書く。**プレリリースでもこの規約を破らない**。

### -1.4 単位系・ロケール・時刻

|項目        |**確定値**                                   |設定で変更可               |
|----------|------------------------------------------|---------------------|
|重量単位 デフォルト|**kg(0.1 単位、全ロケール共通)**                    |✅ Settings で lbs に切替可|
|距離単位      |システムロケール準拠                                |✅                    |
|体重表示      |kg(0.1 単位)                                |✅                    |
|週の開始曜日    |システム設定に従う(`Calendar.current.firstWeekday`)|✅                    |
|履歴の日付表示   |システムロケール                                  |-                    |
|TimeZone  |`TimeZone.current` をセッションに記録(海外移動でズレない)   |-                    |

**保存は常に内部単位(kg, m, UTC)で**。表示変換は View 層のみ。これを破ると履歴データが汚染される。

### -1.5 同期とデータ所在

|項目                   |v1.0 既定                                                                |v1.1+               |
|---------------------|-----------------------------------------------------------------------|--------------------|
|データ所在                |端末ローカル (`appSupport/WorkoutKit.store`)                                 |iCloud (CloudKit) 検討|
|App Group            |**`group.com.tomo.workoutkit`** を **初日から作成**(watchOS/Widget で必須、後付けは面倒)|watchOS時に活用         |
|Keychain Access Group|同上                                                                     |認証導入時               |
|バックアップ               |iCloudバックアップ対象に含める(デフォルト)                                              |エクスポート機能(F-06)併用    |


> **App Groupだけは v1.0 で使わなくても初日に作っておく**。後から追加すると既存DBの移行が必要になる。

### -1.6 ロギング・エラー・MainActor 規約

```swift
// Shared/Logging.swift
import OSLog
extension Logger {
    static let app       = Logger(subsystem: "com.tomo.workoutkit", category: "app")
    static let data      = Logger(subsystem: "com.tomo.workoutkit", category: "data")
    static let generator = Logger(subsystem: "com.tomo.workoutkit", category: "generator")
    static let importer  = Logger(subsystem: "com.tomo.workoutkit", category: "importer")
}

// Shared/AppError.swift
enum AppError: LocalizedError {
    case dataCorruption(String)
    case importFailed(reason: String)
    case generatorEmpty(GeneratorInput)
    case videoMissing(slug: String)
    var errorDescription: String? { /* String Catalog 経由 */ }
}
```

**MainActor 規約**:

- すべての SwiftUI View / `@Observable` Store は `@MainActor`
- `Repository` / `Importer` / `Generator` は **non-isolated**(必要に応じて `actor` 化)
- `print` 禁止。**全部 `Logger`**。
- 例外は `throws` で投げる、UI で `AppError` に正規化してから表示

### -1.7 .xcconfig による設定外部化

`Info.plist` のべた書きは禁止。Build Settings から呼び出す形にする:

```
Config/
├── Shared.xcconfig          // Bundle ID, Team ID, Min iOS
├── Debug.xcconfig           // include "Shared.xcconfig"
├── Beta.xcconfig            // TestFlight 用、別 Bundle ID 推奨 (.beta サフィックス)
└── Release.xcconfig
```

### -1.8 Xcode プロジェクト命名規約(後で変えると事故る)

|種類            |命名                                    |例                       |
|--------------|--------------------------------------|------------------------|
|Target 名      |`WorkoutKit`                          |-                       |
|Test Target   |`WorkoutKitTests`, `WorkoutKitUITests`|-                       |
|Scheme 名      |Target と同名                            |-                       |
|Asset Catalog |`Assets.xcassets`(一つだけ)               |-                       |
|アクセントカラー名     |`AccentColor`(SwiftUI標準名)             |-                       |
|App Icon 名    |`AppIcon`(標準)                         |-                       |
|String Catalog|`Localizable.xcstrings`(複数禁止、1ファイルに集約)|-                       |
|同梱動画ファイル      |`<slug>.mp4`(全小文字、ハイフン区切り)            |`barbell-back-squat.mp4`|
|同梱サムネイル       |`<slug>.jpg`                          |`barbell-back-squat.jpg`|
|ODR タグ        |`videos.<muscle>`                     |`videos.chest`          |

### -1.9 Privacy / Required Reason API

iOS 17.4+ 必須。`PrivacyInfo.xcprivacy` を **初日から空でも作成**:

|使う API             |Reason Code                       |用途           |
|-------------------|----------------------------------|-------------|
|`UserDefaults`     |`CA92.1`                          |アプリ自身の設定保存   |
|`FileTimestamp API`|`C617.1`                          |エクスポートファイル名生成|
|(将来 HealthKit 使うなら)|別途 `NSHealthShareUsageDescription`|-            |

**収集する情報**: なし。トラッキング: なし。これを揺るがさない。

### -1.10 同梱種目の最低ライン(v1.0 出荷条件)

|カテゴリ                |種目数      |用途                 |
|--------------------|---------|-------------------|
|WARMUP              |10       |F-01b ウォームアップ      |
|STRENGTH (compound) |30       |各部位×2種目以上          |
|STRENGTH (isolation)|50       |細部位                |
|CALISTHENICS        |20       |自重組向け              |
|STRETCHING          |30       |F-01b クールダウン       |
|CARDIO              |10       |目的=cardio用         |
|**合計**              |**150以上**|(workout-cool 同等密度)|

ChatGPT で生成する場合のプロンプトは `Resources/prompts/exercise-generation.md` に同梱。

### -1.11 計測・分析

> **Plausible Analytics は workout-cool でも撤去された**(`chore: remove Plausible analytics integration` PR #45 確認済)。**WorkoutKit も初日からアナリティクスゼロ**。クラッシュレポートも入れない(Xcode Organizer で十分)。

### -1.12 Git 戦略

```
.gitignore に追加必須:
  *.xcuserstate
  xcuserdata/
  DerivedData/
  .swiftpm/
  *.xcodeproj/project.xcworkspace/xcuserdata/
  Pods/                  # 念のため(本プロジェクトでは使わないが)
  *.ipa
  *.dSYM.zip
  build/
  .DS_Store
```

ブランチ戦略は **Trunk-Based**(個人開発のため `main` 直 + feature ブランチ)。`v0.1.0` から SemVer。

### -1.13 一発確認チェックリスト(✅全項目確定済み 2026-05-01)

- [x] Bundle ID 確定: **`com.tomo.workoutkit`**
- [ ] Apple Developer Program アクティブ ← **未登録、P-1で登録手続き(年額99 USD、本人確認に2-3日)**
- [ ] Team ID メモ済み ← Developer登録後に取得
- [x] App Group ID 確定: **`group.com.tomo.workoutkit`**
- [x] Min iOS 確定: **`17.0`**
- [x] 対応デバイス: **iPhone + iPad**(初版から)
- [x] アクセントカラーHEX確定: `#FF6B35`(Light)/`#FF8F66`(Dark)
- [x] ロケール: **日本語(主) + 英語**
- [x] ライセンス: **Proprietary**(個人非公開)
- [x] 配布: **App Store 一般公開**
- [x] 課金モデル: **Freemium + Pro買い切り ¥980(Launch ¥600)**
- [x] IAP Product ID: **`com.tomo.workoutkit.pro.unlock`**
- [x] App名: **`WorkoutKit`**(仮、公開時最終決定)
- [x] スキーマバージョン: **`SchemaV1`(1.0.0)** から開始
- [x] 単位系: 内部 **kg/m/UTC**、デフォルト表示は **kg + システムロケール**
- [x] アナリティクス: **入れない**(明示的決定)
- [x] Logger subsystem: **`com.tomo.workoutkit`**
- [x] リポジトリ: **GitHub Private**
- [x] 開発環境: **自宅 Mac**(個人所有)
- [x] 動画: **同梱しない**(文字説明 + ステップイラストのみ)

### -1.14 課金モデル詳細(Freemium + Pro 買い切り)

**実装方針**: StoreKit 2 + Non-Consumable In-App Purchase(サブスクリプションではない)

#### Pro 機能境界(A案 確定)

```
【完全無料】
✅ Builder ウィザード(F-01 全機能)
✅ Shuffle / Choose 両モード(F-01a)
✅ ウォームアップ/メイン/クールダウン(F-01b)
✅ Session 実行画面(F-03)+ Live Activity
✅ 同梱150種目 全部閲覧・検索
✅ 履歴(直近30日まで)
✅ 1RM計算
✅ プリセットテンプレート3種(PPL/上下分割/全身)
✅ ライト/ダークモード
✅ 日本語/英語
✅ App Store 標準の家族共有(購入後は家族にも適用)

【Pro 買い切り ¥980(Launch ¥600 / 最初の3か月)】
🔒 履歴 31日以前(全期間アクセス)
🔒 詳細チャート(週次/月次ボリューム、部位別ヒートマップ)
🔒 カスタムテンプレート無制限作成
🔒 CSV/JSON インポート(workout-cool データ取り込み)
🔒 履歴エクスポート(CSV)
🔒 手動ログ追加(F-04 Issue #88: アプリ外で実施した種目を記録)
🔒 種目のカスタム追加・編集
🔒 セッションへの写真・メモ添付
🔒 App Icon 変更(複数バリエーション)
🔒 Apple Watch 連携(v1.1+ で提供)
```

#### IAP 命名規約

|項目              |値                                    |
|----------------|-------------------------------------|
|Product ID      |`com.tomo.workoutkit.pro.unlock`     |
|Type            |Non-Consumable                       |
|Family Sharing  |Enabled                              |
|価格 Tier         |Tier 6(¥600 Launch) → Tier 9(¥980 通常)|
|Restore Purchase|必須実装(App Store審査 Guideline 3.1.1)    |

#### Paywall 表示タイミング(UX)

|トリガー           |Paywall 表示   |
|---------------|-------------|
|31日以前の履歴を見ようとした|✅(最も自然)      |
|CSVインポート機能を開いた |✅            |
|カスタム種目を作ろうとした  |✅            |
|手動ログ追加を開いた     |✅            |
|アプリ起動直後        |❌(嫌われる)      |
|Builder 完了時    |❌(コア体験を邪魔しない)|

#### Pro 機能フラグの実装

```swift
// Domain/Services/ProFeatureGate.swift
@Observable
@MainActor
final class ProFeatureGate {
    var isPro: Bool = false  // StoreKit 2 で更新

    func check(_ feature: ProFeature) -> Bool {
        return isPro || feature.isFreeTier
    }
}

enum ProFeature {
    case unlimitedHistory
    case advancedCharts
    case customTemplates
    case csvImport
    case csvExport
    case manualEntry
    case customExercise
    case sessionPhoto
    case appIconVariants
    case watchOSCompanion

    var isFreeTier: Bool { false }  // すべてPro機能
}
```

### -1.15 iPad 対応(初版から)

iPhone + iPad 両対応のため、レイアウトを以下の方針で設計:

|観点       |iPhone          |iPad                                 |
|---------|----------------|-------------------------------------|
|Root     |`TabView`       |**`NavigationSplitView`**(サイドバー + 詳細)|
|Builder  |フルスクリーン Sheet   |サイドバー固定 + メイン領域でステップ表示               |
|Session  |フルスクリーン         |Master(種目リスト)+ Detail(現在種目)          |
|Library  |NavigationStack |NavigationSplitView                  |
|向き       |Portrait のみ     |Portrait + Landscape                 |
|Min Width|iPhone SE(375pt)|iPad mini(744pt)                     |

**実装規約**:

- `@Environment(\.horizontalSizeClass)` で `.compact`(iPhone) / `.regular`(iPad)分岐
- `if sizeClass == .regular { NavigationSplitView { ... } } else { TabView { ... } }`
- iPad 専用 UI は `Features/<Feature>/iPad/` サブディレクトリに分離
- Slide Over / Stage Manager(マルチウィンドウ)対応は v1.1+

**コードサイン関連**:

- `UIDeviceFamily` = `[1, 2]`(iPhone + iPad)
- `UIRequiredDeviceCapabilities` から `armv7` を除外
- iPad の `UISupportedInterfaceOrientations~ipad` を Landscape も許可

### -1.16 Apple Developer Program 登録手順(P-1 で実施)

> **未登録のため、開発開始前に登録が必須**。本人確認に **2〜7営業日** かかる場合があるため、Phase P-1 の最初に着手。

#### 登録ステップ(個人アカウント)

1. **Apple ID 準備**: 既存の個人 Apple ID を使用(2FA有効化必須)
1. **支払い情報**: クレジットカード(VISA/Master 推奨、JCB は弾かれる場合あり)
1. **登録ページ**: <https://developer.apple.com/programs/enroll/>
1. **個人選択**: "Individual / Sole Proprietor"(個人事業主登録は不要)
1. **氏名入力**: **App Storeに表示される氏名となる**(変更困難)
- 推奨: 漢字氏名(例: 山田太郎)→ App Store では英字表記(例: Taro Yamada)で表示される
- ニックネーム/屋号で出したい場合は **個人事業主届出 → 法人扱いに切替** が必要
1. **電話確認**: Apple から登録電話に確認 SMS or 通話
1. **本人確認**: マイナンバーカード or 運転免許証の提示を求められる場合あり
1. **支払い**: ¥14,800/年(2026年5月時点、為替変動あり)
1. **承認**: 1〜7営業日後に "Welcome to the Apple Developer Program" メール到着

#### 注意事項

- **業務PC/メールでは絶対に登録しない**(NHKスプリングの所有権主張リスク)
- 登録時の Apple ID は **業務とは無関係の個人 Apple ID** を使用
- D-U-N-S Number は個人アカウントなら不要
- 法人化(株式会社/合同会社)した場合は **アカウント移管が必要**(地獄)
- **副業として申告する場合**: 課金収益は雑所得 or 事業所得。年間20万超で確定申告

#### 登録後にやること(P0前)

- [ ] Team ID をメモ(Member Center で確認)
- [ ] Xcode でサインイン → "Manual" 署名は使わず "Automatically manage signing"
- [ ] App ID を作成: `com.tomo.workoutkit`(Capabilities は P0 で順次追加)
- [ ] App Group を作成: `group.com.tomo.workoutkit`
- [ ] iCloud Container は v1.1+ で追加

-----

-----

## 0. プロジェクト概要

### 0.1 一行で言うと

ユーザーが「目的 → 部位 → 器具」の順に絞り込み、自動生成されたワークアウトメニューを実行・記録できる **完全オフライン・サブスク不要** のiOSフィットネスアプリ。

### 0.2 workout-cool との差分(なぜ純ネイティブか)

|観点      |workout-cool (Web)                                                    |WorkoutKit (iOS)                |
|--------|----------------------------------------------------------------------|--------------------------------|
|ランタイム   |Next.js 15 / App Router                                               |SwiftUI ネイティブ                   |
|アーキ     |Feature-Sliced Design (app/processes/widgets/features/entities/shared)|MV + Feature単位 (本書§4)           |
|データ     |PostgreSQL + Prisma + Docker                                          |**SwiftData (端末内のみ)**           |
|認証      |better-auth                                                           |**不要**(端末内完結)                   |
|動画      |YouTube埋込 / 外部CDN                                                     |**動画なし**(文字説明+ステップイラスト)         |
|i18n    |next-intl(独/西/仏/日/韓/葡/露/中の8言語)                                        |String Catalog(**日/英 のみ**, 将来拡張)|
|データインポート|CSV(`pnpm run import:exercises-full`)                                 |**CSV/JSON 両対応** + 同梱seed       |
|課金      |寄付ベース(Ko-fi)                                                          |**App Store(オプション、買い切り)**       |
|オフライン   |△                                                                     |**◎ フル動作**                      |

### 0.3 ターゲットユーザー

- 自宅トレ中心の初〜中級者
- ジム通いだが当日のメニューを5秒で組みたい人
- サブスクと広告に疲れた人

-----

(以降の §1〜§12, Appendix A, 改訂履歴 は元の指示書を参照。
本リポジトリでは仕様の根拠は §-1 Foundation Locks と §4 アーキテクチャの2セクションを最重要視する。)

-----

## 11. Claude Code への指示 (Operating Instructions、抜粋・再掲)

### 11.4 やってはいけないこと(NG リスト)

- ❌ UIKit(必要な時のみ可、`UIViewRepresentable` でラップする場合は理由を明記)
- ❌ Combine(代わりに `@Observable` + async/await)
- ❌ `print` 文の本番残し(`Logger` を使う)
- ❌ `force unwrap` (`!`) を新規コードで使う
- ❌ Singleton(`shared`) — 環境値 or DI で渡す
- ❌ ネットワーク通信(v1.0 は完全オフライン、ただし StoreKit 通信と YouTube アプリへのDeep Linkは例外)
- ❌ **§-1 Foundation Locks の値を勝手に変更する**(Bundle ID、App Group、SchemaV1、内部単位系、Pro価格など)
- ❌ **重量・距離・日付を表示用文字列で保存する**(常に内部単位 kg/m/UTC、表示は formatter で変換)
- ❌ **Exercise の主キーに UUID を使う**(`slug` を主キーにする §-1.2 規約)
- ❌ **Info.plist べた書き**(必ず xcconfig 経由)
- ❌ アナリティクスSDK/クラッシュレポートSDK 追加
- ❌ **動画ファイル(mp4等)の同梱**(§-1 確定でステップイラスト方針)
- ❌ Pro 機能フラグの ハードコード(`if userIsPro` などの直書き)— 必ず `ProFeatureGate.check(_:)` 経由
- ❌ Paywall をアプリ起動直後に表示する(必ず該当機能アクセス時のみ)

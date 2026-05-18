# WorkoutKit

> Fully offline iOS strength-training planner & logger.
> Three-step builder (goal → muscles → equipment), 345 bundled exercises,
> Live Activities, Apple Watch Smart Stack widget.

詳細仕様は [`CLAUDE.md`](./CLAUDE.md) を参照(Claude Code / Cursor / Xcode で本リポジトリを開くと自動で読まれる)。

## Status

**v1.0 リリース準備中**(2026-05-16 時点)。Xcode プロジェクト・ソース・テスト・
スクリーンショット・法務書類は揃い、`xcodebuild test -only-testing:WorkoutKitTests`
で **155/155 グリーン**。残作業は App Store Connect 側の手動入力(`docs/DISPATCH_v1.0.md` 参照)。

## Highlights

- **5 秒で当日メニュー生成** — Goal × Muscle × Equipment × Time の Builder ウィザード
- **345 種目** — 解剖図(前面・背面)つき、ja / en 両対応
- **完全オフライン** — ネットワーク通信は App Store / StoreKit のみ
- **Live Activities** — セッション進捗 + Rest Timer の 2 系統
- **Apple Watch Smart Stack ウィジェット** — 今日の状況を `accessoryRectangular` で
- **AI Coach**(iOS 26+)— Foundation Models のオンデバイス LLM で 3 行サマリ
- **解析 / クラッシュ / 広告 SDK ゼロ** — `PrivacyInfo.xcprivacy` で明示

## ディレクトリ構成

```
.
├── CLAUDE.md                           # 仕様 + Claude Code 用指示書(最重要)
├── Config/                             # xcconfig(Shared/Debug/Beta/Release/LiveActivity)
│   └── Secrets.template.xcconfig       # RevenueCat キーのテンプレ(本物は .gitignore)
├── WorkoutKit.xcodeproj                # Xcode プロジェクト
├── WorkoutKit/                         # iOS アプリ本体
│   ├── WorkoutKitApp.swift             # @main、ModelContainer 構築
│   ├── App/                            # RootView / AppDependency / TemplateSeeder
│   ├── Features/                       # Builder / Session / Library / History /
│   │                                   #   Templates / Paywall / DataIO / Settings /
│   │                                   #   AICoach / LiveActivity
│   ├── Domain/                         # Models / Schema / Enums / Services / Repository
│   ├── Shared/                         # Logging / AppError / WatchSummaryBridge /
│   │                                   #   AppSecrets / UnitsFormatter
│   ├── DesignSystem/                   # Colors / Typography / Components
│   └── Resources/                      # Assets / 種目 seed / PrivacyInfo /
│                                       #   Localizable.xcstrings / WorkoutKit.storekit
├── WorkoutKitLiveActivity/             # Widget Extension (Live Activity bundle)
├── WorkoutKitWatch/                    # watchOS Smart Stack ウィジェット
├── Tests/
│   ├── WorkoutKitTests/                # Swift Testing — 155 件
│   └── WorkoutKitUITests/              # スクリーンショット撮影含む
└── docs/                               # 法務 / App Store / ロードマップ / Dispatch
    ├── legal/                          # privacy-policy / terms-of-service (ja+en+html)
    ├── app-store/                      # metadata / screenshots / app-review-notes
    └── DISPATCH_v1.0.md                # M1-M10 マイルストーン
```

## 重要な確定事項(CLAUDE.md §-1 抜粋)

| 項目                | 値                                                                  |
|---------------------|---------------------------------------------------------------------|
| Bundle ID           | `com.tomo.workoutkit`                                                |
| App Group           | `group.com.tomo.workoutkit`                                          |
| Min iOS             | 18.0 (Live Activities + watchOS Smart Stack で 18 以上が必要)        |
| 対応デバイス        | iPhone (Portrait) + iPad (Portrait + Landscape) + Apple Watch       |
| 課金                | Freemium + Premium サブスク(月額 ¥980 / 年額 ¥4,900 / 7 日無料試用) |
| サブスク Group      | `workoutkit.premium`                                                 |
| Product ID(月額)  | `workoutkit_monthly_980`                                             |
| Product ID(年額)  | `workoutkit_yearly_4900`                                             |
| Entitlement         | `premium`(RevenueCat 経由)                                          |
| SwiftData Schema    | `SchemaV1`(1.0.0)から開始                                           |
| 内部単位            | kg / m / UTC(表示は View 層で変換)                                   |
| アナリティクス      | 入れない                                                              |
| 動画                | 同梱しない(解剖図 + ステップ説明)                                       |

これらを変更するときは CLAUDE.md と一緒に更新すること。

## Mac でのビルド手順

```bash
# 1. Secrets を配置(RevenueCat API キーはあとで埋めても OK)
cp Config/Secrets.template.xcconfig Config/Secrets.xcconfig

# 2. テスト(WorkoutKitTests のみ。UI test は P5 で別途)
xcodebuild test \
  -project WorkoutKit.xcodeproj \
  -scheme WorkoutKit \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:WorkoutKitTests \
  CODE_SIGNING_ALLOWED=NO
```

期待: **155/155 グリーン**。失敗時は [`docs/DISPATCH_v1.0.md`](docs/DISPATCH_v1.0.md) §1 のトラブルシューティングを参照。

CI も同じことをやる — `.github/workflows/test.yml`、macOS 15 runner、push 毎に自動。

## 開発フロー

- ブランチ: Trunk-Based(`main` 直 + feature ブランチ)
- 規約: Swift API Design Guidelines + Swift 6 strict concurrency
- コミット: Conventional Commits(`feat:` `fix:` `refactor:` `chore:` `docs:` `test:`)
- View に `@State` / `@Observable` を直接持たせる方針(ViewModel は作らない)。詳細は CLAUDE.md §11

## v1.0 リリース進捗

`docs/DISPATCH_v1.0.md` の §0.1 ステータスサマリを参照。要点:

- M1 (Mac build / tests) ✅
- M3 (RevenueCat dashboard) ✅
- M4 (ASC subscription products) ✅
- M5 (placeholders 置換) ✅
- M6 (スクリーンショット 50 枚) ✅(Apple Watch のみ実機未撮影)
- M7 (Privacy 申告) ✅
- M8 (ASC metadata 入力) ⚠ tomo 手動入力待ち
- M9 (TestFlight / Sandbox) 🔴 Apple Developer enrollment 後
- M10 (App Store 審査提出) 🔴 M9 後

## ライセンス

Proprietary(個人非公開、App Store のみ)。

同梱の解剖図 SVG は [Snouzy/workout-cool](https://github.com/Snouzy/workout-cool) (MIT) を改変。詳細は [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) を参照。

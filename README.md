# WorkoutKit

> 完全オフライン・サブスク不要の iOS フィットネスコーチングアプリ。
> 「目的 → 部位 → 器具」の3ステップでメニューを自動生成・実行・記録できる。

詳細仕様は [`CLAUDE.md`](./CLAUDE.md) を参照(Claude Code / Cursor / Xcode で本リポジトリを開くと自動で読まれる)。

## ステータス

Phase **P0**(P-1 完了、Xcode プロジェクト未作成)。
本リポジトリには Xcode プロジェクトファイル(`.xcodeproj`)は **まだ含まれていない**。下記「Mac でのプロジェクト作成手順」を参照。

## ディレクトリ構成

```
.
├── CLAUDE.md                       # 仕様 + Claude Code 用指示書(最重要)
├── Config/                         # xcconfig(Shared/Debug/Beta/Release)
├── WorkoutKit/                     # ソース本体
│   ├── WorkoutKitApp.swift         # @main、ModelContainer 構築
│   ├── App/                        # RootView / AppDependency
│   ├── Features/                   # Builder / Session / Library / History / Templates / Paywall / DataIO
│   ├── Domain/                     # Models / Schema / Enums / Services / Repository
│   ├── Shared/                     # Logging / AppError / UnitsFormatter
│   ├── DesignSystem/               # Colors / Typography / Components
│   └── Resources/                  # Assets / 種目seed / PrivacyInfo / ChatGPTプロンプト
└── Tests/
    ├── WorkoutKitTests/            # Swift Testing
    └── WorkoutKitUITests/
```

## 重要な確定事項(CLAUDE.md §-1 抜粋)

| 項目 | 値 |
|---|---|
| Bundle ID | `com.tomo.workoutkit` |
| App Group | `group.com.tomo.workoutkit` |
| Min iOS | 17.0 |
| 対応デバイス | iPhone + iPad |
| 課金 | Freemium + Pro 買い切り ¥980(Launch ¥600) |
| IAP Product ID | `com.tomo.workoutkit.pro.unlock` |
| Schema | `SchemaV1`(1.0.0)から開始 |
| 内部単位 | kg / m / UTC(表示は View 層で変換) |
| アナリティクス | 入れない |
| 動画 | 同梱しない(ステップイラスト方針) |

これらを変更するときは CLAUDE.md と一緒に更新すること。

## Mac でのプロジェクト作成手順

> Linux 環境ではビルドできない。下記は所有 Mac 上で実施する。

1. Xcode 16+ を起動 → File ▸ New ▸ Project ▸ iOS ▸ App
2. 入力値:
   - Product Name: `WorkoutKit`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
   - Include Tests: ✅
3. 既存ソースの取り込み:
   - 生成された `WorkoutKitApp.swift` / `ContentView.swift` を削除
   - 本リポジトリの `WorkoutKit/` 配下を Xcode プロジェクトに追加(Create groups)
   - `Config/*.xcconfig` を Project ▸ Info ▸ Configurations に割り当て
       - Debug → `Config/Debug.xcconfig`
       - Beta(Duplicate Release から作成) → `Config/Beta.xcconfig`
       - Release → `Config/Release.xcconfig`
4. Capabilities 追加:
   - App Groups: `group.com.tomo.workoutkit`
   - (P5)In-App Purchase
5. `WorkoutKit/Resources/exercises_seed.json` と `PrivacyInfo.xcprivacy` を Target Membership ✅ にする
6. ビルド実行:
   ```
   xcodebuild -project WorkoutKit.xcodeproj \
     -scheme WorkoutKit \
     -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
   ```

## 開発フロー

- ブランチ: Trunk-Based(`main` 直 + feature ブランチ)
- 規約: Swift API Design Guidelines + SwiftLint デフォルト
- コミット: Conventional Commits(`feat:` `fix:` `refactor:` `chore:` `docs:` `test:`)
- View に `@State`/`@Observable` を直接持たせる方針(ViewModel は作らない)。詳細は CLAUDE.md §11

## 画像生成ワークフロー(Stable Diffusion / ローカル)

種目フォーム解説のステップイラストは **Mac (Apple Silicon) 上の Stable Diffusion でローカル生成** する方針。サブスク・API 課金なし、生成済み画像は Asset Catalog (`ExercisePhotos` namespace) にコミットして配布する。

```bash
# 1) Draw Things(App Store 無料)を起動 → API 有効化(Settings ▸ Server)
# 2) 上位 50 種目を一括生成(M2 で約 10 分)
python3 tools/sd-batch/generate.py
# 3) Asset Catalog に統合
python3 tools/sd-batch/integrate.py
```

詳細(モデル DL / プロンプト規約 / トラブルシューティング)は [`tools/sd-batch/README.md`](./tools/sd-batch/README.md) を参照。

## ライセンス

Proprietary(個人非公開、App Store のみ)。

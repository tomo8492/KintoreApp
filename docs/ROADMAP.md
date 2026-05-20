# WorkoutKit — Roadmap

> Version snapshot: **v1.0** is ship-ready (HEAD `9480a7c` at the time of
> writing). Forward-looking items here are **intent only** — they ship when
> they ship and the order can shift based on user feedback after v1.0
> launch. Updated: 2026-05-20.
>
> See also:
> - `CHANGELOG.md` — released versions
> - `docs/DISPATCH_v1.0.md` — milestone history (M1–M10)
> - `docs/M9_PREFLIGHT_CHECKLIST.md` — what tomo needs to do to ship v1.0
> - `docs/release-notes/v1.0.0-rc1.md` — v1.0 release notes draft

---

## Timeline (intent)

```
2026 Q2 ─ v1.0  ── 🚀 ship  ──── Subscription pivot, AI Coach, Live Activities, Watch widget
2026 Q3 ─ v1.1  ──            ── Premium copy polish, en metadata tightening, ja Settings rebrand
2026 Q3 ─ v1.2  ──            ── Localisation expansion (zh-Hans / es / ko / de)
2026 Q4 ─ v1.3  ──            ── Custom Exercise (Pro), Sandbag/equipment metadata audit
2026 Q4 ─ v1.4  ──            ── Session Photo (Pro), App Icon Variants (Pro)
2027 Q1 ─ v1.5  ──            ── watchOS Companion (real watchOS app, beyond Smart Stack widget)
2027 Q2 ─ v2.0  ──            ── CloudKit sync, 600+ exercises, AI Coach v2, Apple Health integration
```

Quarters are wall-clock intent, not commitments. Each line in §Per-version
below carries individual risk + dependency notes.

---

## v1.0 (shipping)

Foundations + the full first-party feature set listed below. Everything in
this section corresponds to a working code path in this repository and is
mentioned in `docs/app-store/{ja,en}/description.txt`.

### Coverage
- 345 exercises bundled, all translated ja + en
- Anatomical body diagram, 2-row layout (Front / Back) with cue dots tagged
  by anatomical side
- Builder wizard (Goal → Muscle → Equipment → Time) with Shuffle and Choose
- Session execution (sets / reps / weight / RPE / rest), interval timer,
  Live Activity on lock screen + Dynamic Island
- History list + calendar + 30-day cutoff (free) / full history (Premium)
- Templates: 3 free presets (Push-Pull-Legs / Upper-Lower / Full-body) +
  unlimited custom templates (Premium)
- Library (search + 4-facet filter, exercise detail with steps + common
  mistakes + cautions + annotated body diagram)
- Settings (kg / lbs, theme, restore purchases, language deep link)
- Localizable.xcstrings 100 % ja + en (1,257 entries)
- Privacy: no tracking, no data collection, fully offline (StoreKit + RevenueCat only)
- watchOS Smart Stack widget (`accessoryRectangular` only, v1.0 minimum)

### Premium features shipping in v1.0

| Code case (`ProFeature`) | UX surface | Status |
|---|---|---|
| `unlimitedHistory` | History list / calendar past 30 days | ✅ |
| `advancedCharts`   | History → Charts (weekly / monthly / heat map) | ✅ |
| `customTemplates`  | Templates → Add / Duplicate / Delete custom | ✅ |
| `csvImport`        | Settings → Data → Import CSV / JSON | ✅ |
| `csvExport`        | Settings → Data → Export CSV | ✅ |
| `manualEntry`      | History → Add manual entry | ✅ |
| `videoLink`        | Library detail → YouTube reference | ✅ |

---

## Per-version planning

The `ProFeature` enum cases are kept stable so user-facing purchase
semantics don't shift across versions. New cases below already exist in
`WorkoutKit/Domain/Enums/ProFeature.swift` so a future paywall row just
needs `isShownInPaywallV1 → isShownInPaywallV*N* { return true }` plus the
actual UI.

### v1.1 — Polish & house-keeping (target 2026 Q3, ~2-3 weeks)

| Item | Notes | Dependency | Risk |
|---|---|---|---|
| Settings Premium rebrand 完遂 | `settings.purchase.status.title` / `settings.purchase.restore` 等 user-facing keys を Pro → Premium にリネーム(v1.0 で a11y 外残置分)| なし | 🟢 低 — xcstrings 編集のみ |
| en metadata tightening | `subtitle.txt` 0 headroom / `name` 3 / `promotional` 4 / `keywords` 3 を 5+ headroom に短縮 | なし | 🟢 低 — テキスト圧縮のみ |
| `videoLink` deep-link 動作確認 | YouTube アプリ未インストール端末でも universal link が安全に Safari に fall back するか実機検証 | 実機 | 🟢 低 |
| Generator equipment metadata audit | Bodyweight タグ付きの補助器具必要種目(サンドバッグキャリー等)を抽出 → equipment 配列補正、`WorkoutGenerator` 厳格性回帰テスト追加 | seed JSON 再ビルド | 🟡 中 — seed sweep + 回帰テスト |
| Screenshot-diff CI | 既存 UITest 撮影スイートを baseline と比較してドリフト検出 | macos-26 runner 安定化 | 🟡 中 — CI 時間 |

### v1.2 — Localisation expansion (target 2026 Q3 後半, ~1 ヶ月)

| Item | Notes | Dependency | Risk |
|---|---|---|---|
| zh-Hans / zh-Hant 追加 | 1,257 keys の翻訳。String Catalog 駆動なのでコード変更なし | 翻訳者 or LLM 検収 | 🟡 中 — 用語統一 |
| ko / es 追加 | 同上、aria の各国 keyboard variant 検証 | 翻訳 | 🟡 中 |
| de / fr / pt-BR | 同上(長い単語で UI 切れリスク、Dynamic Type 検証) | 翻訳 + 実機 | 🟡 中 |
| en 監査 round 2 | 米英別の表現差(weight units 等) | ネイティブレビュー | 🟢 低 |

### v1.3 — Custom Exercise (target 2026 Q4 前半, ~1 ヶ月)

| Item | Notes | Dependency | Risk |
|---|---|---|---|
| `customExercise` UI | Library "+" → ExerciseEditView (name ja/en, primary muscle, equipment, mechanics). Schema bit `Exercise.isUserCreated` 既存 | importers の dedup 拡張 | 🟡 中 — 345 bundled との衝突 |
| Dedup logic | bundled slug と user-created の slug collision 検出 + 警告 UI | なし | 🟡 中 |
| CSV/JSON import で isUserCreated を尊重 | 既存 CSVImporter / JSONImporter に `isUserCreated` 保護 flag 追加 | 既存 importer | 🟢 低 |
| Equipment metadata audit follow-up | v1.1 の audit 結果を踏まえた更新 | v1.1 完了 | 🟢 低 |

### v1.4 — Personalisation (target 2026 Q4 後半, ~3 週間)

| Item | Notes | Dependency | Risk |
|---|---|---|---|
| `sessionPhoto` | `WorkoutSession.attachments: [SessionAttachment]` (file URL + thumb + caption)、PhotosPicker integration | iOS PhotosUI、ストレージ容量配慮 | 🟡 中 — 写真容量 |
| `appIconVariants` | `AlternateAppIcon-*.appiconset` × 数種 + `CFBundleAlternateIcons` + Settings UI | App Icon デザイン素材 | 🟢 低 |
| Theme 拡張 | accent カラー × 3-5、システムに合わせる + 個別 override | デザイン | 🟢 低 |
| iCloud Drive backup | 「設定→データ→バックアップ」で `.workoutkitbackup` を Files へ吐く(import も) | UIDocumentPickerViewController | 🟡 中 |

### v1.5 — watchOS Companion app (target 2027 Q1, ~1.5 ヶ月)

v1.0 は **Smart Stack widget のみ**(`WorkoutKitWatch` target = widget extension)。v1.5 は **本格的な watchOS アプリ** を追加して以下を可能にする:

| Item | Notes | Dependency | Risk |
|---|---|---|---|
| watchOS app target 追加 | iPhone でビルド済セッションを Watch で実行 (sets / reps / rest) | WatchConnectivity | 🟡 中 — pairing 状態管理 |
| Watch Live Activity 連携 | iPhone Live Activity を Watch face にミラー | iOS 18 ActivityKit Watch 連携 | 🟡 中 |
| Watch UI 翻訳 | xcstrings の共有(共通 keys)+ Watch 専用 keys 追加 | 翻訳追加 | 🟢 低 |
| Watch Smart Stack 強化 | 進行中セッション中は live progress、終了後は今日のサマリ | 既存 widget data flow | 🟢 低 |

### v2.0 — Major leap (target 2027 Q2, ~2 ヶ月)

| Item | Notes | Dependency | Risk |
|---|---|---|---|
| CloudKit sync | App Group `group.com.tomo.workoutkit` 既存、SchemaV1 → SchemaV2 でモデルを CKRecord 対応 | iCloud 容量 + 衝突解決 | 🔴 高 — schema migration |
| 600+ exercises 追加 | 345 → 600 へ。同形式 JSON + body annotation pipeline | 翻訳 + イラスト | 🟡 中 — content review |
| AI Coach v2 | iOS 26+ Foundation Models の context 拡張、複数日トレンド分析、目的別アドバイス | Foundation Models SDK 進化 | 🟡 中 — Apple 依存 |
| Apple Health 統合 | HealthKit でセッション結果を書込 (HKWorkout)、過去のワークアウト読込 | HealthKit 使用説明書 + プライバシーポリシー改訂 | 🔴 高 — Review 5.1.1 |
| Apple Vision Pro | SwiftUI 既存実装の visionOS pass、Diagram の 3D 化検討 | visionOS SDK 進化 | 🟢 低 — opt-in |

---

## Out of scope (no plans)

Listed only to prevent re-discussion:

- Real-time multiplayer / social feed
- Built-in YouTube player (App Store guideline 4.0 — passing through to the
  YouTube app is intentional)
- Calorie tracking / nutrition database (different product)
- Ads. Ever. (Premium subscription is the only monetization channel)
- Web app, Android app, or any platform other than Apple's

---

## Quality / tech-debt carry-over

Items below cross-cut multiple versions:

| Item | Status | Target version |
|---|---|---|
| Swift 6 strict-concurrency 残 20 件(SwiftData `KeyPath<X, Y>` Sendable) | Apple SDK 修正待ち | 移行は v1.x 中、SDK 対応後 |
| `@preconcurrency import SwiftData` 採否再評価 | 副作用大で v1.0 不採用、SDK 進化次第 | v1.2 で再評価 |
| Test coverage 数値の正式測定 | `gatherCoverageData: true` 設定済、未集計 | v1.1 で baseline 取得 |
| ASan / TSan の Xcode IDE 経由起動を CI に組込 | 現状 manual | v1.1 |
| `RELEASE_AUDIT.md` の継続更新 | 各 release 直前で refresh | 毎 minor release |

---

## How this document evolves

- 各 minor release(v1.1, v1.2 …)直前で **当該バージョンの table を該当 §** に確定 + delete from
  later sections。release 後は `CHANGELOG.md` に Released として転記し、本 ROADMAP からは削除。
- 新規 feature が思いついた段階で **どの version 帯に置くか** を考えて 1 行追加。
  "Out of scope" になりそうなら、議論なしで OoS セクションに移す。
- 既存案件のリスク評価が変わったら risk 列を更新(🟢 / 🟡 / 🔴)。
- 個別 PR / commit と本ファイルの紐付けは git log で十分(commit message が
  "v1.1 polish" 等と version stamp する規律で十分追跡可能)。

---

参考: `docs/release-notes/v1.0.0-rc1.md`, `CHANGELOG.md`, `docs/DISPATCH_v1.0.md`,
       `docs/i18n-todo.md`, `docs/M9_PREFLIGHT_CHECKLIST.md`

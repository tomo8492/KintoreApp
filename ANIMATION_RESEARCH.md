# エクササイズアニメーション 品質向上 調査レポート

> **目的**: WorkoutKit の種目デモ表示を「プロが作った教育用イラスト」レベルに引き上げるための判断材料を集める。
>
> **背景**: SwiftUI procedural な棒人間試作 → 「品質が低すぎる」と却下。**動画 mp4 同梱は §-1 Foundation Locks で禁止**。Lottie / Rive / 静止画 / 3D は OK。
>
> **本書の射程**: 調査と推奨のみ。実装方針は tomo の確認後に別タスクで決定。
>
> **作成日**: 2026-05-05 / **ブランチ**: `research/exercise-animation-quality`

-----

## エグゼクティブサマリー

| 項目 | 結論 |
|---|---|
| 業界主流 | **実写動画**(13 アプリ中 9 が動画ベース) |
| WorkoutKit が採るべき軸 | **Lottie + プロのフラットイラスト**(Liftin' 路線) |
| 第一推奨 | **(A) LottieFiles Free + 必要時に Marketplace pack 1〜2 本買い足し** |
| 代替案 | **(F) 静止イラスト 2 枚カルーセル**(Fiverr 発注、最低限の動き) |
| 3D 路線 | **v1.1+ に温存**(Mixamo + SceneKit、初版に積むコスト過大) |
| 動画 | **不採用**(§-1 Lock + 容量・著作権リスク) |
| MVP プロト工数 | **5 種目 / 1〜2 日 / ¥0〜¥3,000** |
| 本番 50 種目 | **2〜3 週間 / ¥15,000〜¥40,000**(Marketplace pack 購入想定) |
| 全 345 種目 | **段階拡張 + Pack ベース調達**で半年〜1 年計画(下記 Phase 4) |

-----

## Phase 1: 競合フィットネスアプリ調査

### 1. workout-cool iOS (App Store id 6749820499)
- **方式**: 実写動画(YouTube / 外部 CDN 埋め込み)+ 文字ステップ説明
- **品質**: mid(動画ロード失敗のレビューあり)
- **特徴**: Web 版 (Next.js/Prisma) の延長で、エクササイズ DB と "videos and step-by-step guidance" が売り。独自録画ではなく外部依存埋め込みと推定。
- **出典**: [App Store](https://apps.apple.com/us/app/workout-cool/id6749820499) / [GitHub](https://github.com/Snouzy/workout-cool)

### 2. StrongLifts 5×5
- **方式**: 実写動画(プロが正面 / 側面で実演)
- **品質**: high
- **特徴**: 100+ 種目すべてに動画 + 文字。`Start workout → tap exercise` のオンデマンド呼び出し。"proper form" を前面に押し出す教育動画。
- **出典**: [stronglifts.com/app](https://stronglifts.com/app/) / [App Store](https://apps.apple.com/us/app/stronglifts-5x5-workout/id488580022)

### 3. Nike Training Club (NTC)
- **方式**: 実写動画(プロインストラクター主演のフォローアロング)
- **品質**: high(Nike 制作、スタジオ品質)
- **特徴**: 種目単発のデモではなく**ワークアウト全体をクラス動画として提供**。Akin Akman / Eva Redpath 等の Master Trainer。Netflix にも配信実績あり。
- **出典**: [nike.com/ntc-app](https://www.nike.com/ntc-app) / [Time](https://time.com/6245768/netflix-nike-training-club-review/)

### 4. Fitbod
- **方式**: HD 実写動画 + オフライン用 GIF(複数アングル)
- **品質**: high
- **特徴**: 1,000+ 種目。**世間では 3D アバター誤認されがちだが実態は実写ビデオ + GIF**。公式 FB が "HD exercise demonstration videos and offline Gifs!" と明言。
- **出典**: [fitbod.me](https://fitbod.me/) / [Fitbod 公式 FB](https://www.facebook.com/fitbodapp/videos/1870630739823707/) / [TechRadar review](https://www.techradar.com/health-fitness/fitbod-app-review)

### 5. Centr (Chris Hemsworth)
- **方式**: 実写動画(ハリウッド級制作、コーチ主演)
- **品質**: high(業界最高クラス)
- **特徴**: Luke Zocchi、Ingrid Clay 等の専門コーチ。Hemsworth 出演 15 分 HIIT もあり。NTC 同様クラス型コンテンツ中心。
- **出典**: [centr.com](https://centr.com/) / [App Store](https://apps.apple.com/us/app/centr-strength-fitness-app/id1382530817)

### 6. Sworkit
- **方式**: 実写モデル動画(短尺ループ)+ 音声キュー
- **品質**: mid〜high
- **特徴**: 1 種目 = 1 ループ動画。"there's never any question about how to do the exercise" が売り文句。BGM とカウントダウン音声が動画と同期。
- **出典**: [App Store](https://apps.apple.com/us/app/sworkit-personalized-workouts/id527219710) / [DesignRush 解説](https://www.designrush.com/best-designs/apps/sworkit)

### 7. Caliber
- **方式**: 実写動画(500+ 種目)+ フェーズ分割テキスト
- **品質**: high
- **特徴**: 動画 + ステップ別テキスト + フォームチェック用ユーザー動画アップロード(Premium)。1on1 コーチ向けに動画ベースのフィードバックループ。
- **出典**: [caliberstrong.com](https://caliberstrong.com/workout-app/) / [BarBend review](https://barbend.com/caliber-fitness-app-review/)

### 8. JEFIT
- **方式**: GIF アニメ(2D シルエットキャラ)+ 一部 HD 動画
- **品質**: mid(GIF はやや古めかしいが情報量は十分)
- **特徴**: 1,400+ 種目。「JEFIT 風 GIF」=「2D シルエットキャラが正面で動く」が業界デファクトとして認知。
- **出典**: [jefit.com](https://www.jefit.com/) / [App Store](https://apps.apple.com/us/app/jefit-workout-planner-gym-log/id449810000)

### 9. Hevy
- **方式**: **3D アニメーションキャラ**(動的レンダリング)+ 文字説明
- **品質**: mid〜high(多角度で動きを見せられるが「専用ビデオほどの詳細感はない」と評)
- **特徴**: 400+ 種目に "demo animation"。レビューで "3D animated model demonstrating the Squat" と明示。**フィットネス トラッカーカテゴリでの 3D 採用例として最も知られている**。Hevy Coach (B2B) にはビデオライブラリも併設。
- **出典**: [hevyapp.com/features/exercise-library](https://www.hevyapp.com/features/exercise-library/) / [App Store](https://apps.apple.com/us/app/hevy-workout-tracker-gym-log/id1458862350)

### 10. Strong (workout tracker)
- **方式**: アニメーション動画 + 解剖図("diagrams and animated examples")
- **品質**: mid
- **特徴**: 抽象的なアニメ + 筋肉図中心。トラッカー用途のためデモは補助的位置づけ。
- **出典**: [strong.app](https://www.strong.app/) / [App Store](https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577)

### 11. Liftin' ★ WorkoutKit に最も近い参考例
- **方式**: **Lottie アニメーション**(ループ静止イラスト、After Effects → Lottie 書き出し、Jamoora Studio 制作)
- **品質**: mid("subtle loop animations"、ファイルサイズと品質のバランス重視)
- **特徴**: **動画を同梱せず Lottie で軽量に動きを表現**という戦略を商業的に成立させている数少ない例。デザインスタジオが手で作画 → 微小ループで質感。**WorkoutKit が真似すべき第一参考**。
- **出典**: [Jamoora Studio case study](https://jamoorastudio.com/project/liftin/) / [App Store](https://apps.apple.com/us/app/liftin-gym-workout-tracker/id1445041669)

### 12. FitNotes X
- **方式**: 実写動画(男女別、750+ 種目)+ YouTube フォールバック
- **品質**: mid〜high
- **出典**: [fitnotesx.com](https://fitnotesx.com/) / [App Store](https://apps.apple.com/us/app/fitnotes-2-gym-workout-log/id1538896016)

### 13. Ladder(Apple 2025 App of the Year Finalist)
- **方式**: コーチ主演の実写動画(フォローアロング)
- **品質**: high
- **特徴**: 「種目デモ」より「コーチが横にいる体験」。動画 + 音声キュー + プログレスバー。
- **出典**: [joinladder.com](https://www.joinladder.com/) / [App Store](https://apps.apple.com/us/app/ladder-strength-training-plans/id1502936453)

### Phase 1 サマリー表

| アプリ | 方式 | 品質 | WorkoutKit 流用可? |
|---|---|---|---|
| workout-cool iOS | 実写動画(埋込) | mid | ❌ 動画禁止 |
| StrongLifts 5×5 | 実写動画 | high | ❌ |
| Nike Training Club | 実写クラス動画 | high | ❌ |
| Fitbod | HD 動画 + GIF | high | △ GIF 部分のみ参考 |
| Centr | 実写動画 | high | ❌ |
| Sworkit | 実写ループ | mid〜high | ❌ |
| Caliber | 実写動画 | high | ❌ |
| JEFIT | GIF アニメ | mid | △ Lottie 化で再解釈可 |
| Hevy | **3D アニメ** | mid〜high | △ v1.1+ 候補 |
| Strong | アニメ + 解剖図 | mid | △ |
| **Liftin'** | **Lottie ループ** | **mid** | **◎ 第一参考** |
| FitNotes X | 実写動画 | mid〜high | ❌ |
| Ladder | 実写動画 | high | ❌ |

### Phase 1 から得られた示唆

- **業界スタンダードは実写動画**。WorkoutKit が「動画同梱禁止」を貫く以上、同じ土俵で勝負しても負ける。**差別化方向で考えるべき**。
- **3D 採用は実は少数派**(Hevy が代表)。3D は「質感」より「軽量で角度切替できる」というメタ価値で選ばれている。WorkoutKit が 3D に行くなら Hevy 級の差別化(部位ハイライト連動など)が必要。
- **Lottie で軽く済ませた商業前例 = Liftin'**。Jamoora Studio に After Effects → Lottie で発注する構図は WorkoutKit にとって最も現実的なテンプレート。「品質低くない」評価を取れている。
- **GIF(JEFIT 型)は 2026 年現在「枯れた / 古い」印象**になりつつあるが情報伝達効率は依然高い。「JEFIT 風を Lottie で再実装、現代的なフラットイラストに刷新」は十分ありうる戦略。
- **進むべき方向**: 動画各社と真っ向勝負を避け、「**読みやすい教科書イラスト**」というニッチで戦う。プロイラストレーター発注 → Lottie で微小ループ。

-----

## Phase 2: ライセンス互換素材の調査

### 2.1 LottieFiles ★ 本命
- **検索結果数**: "fitness" / "exercise" / "workout" / "yoga" / "gym" 各カテゴリで Free 数百件 + Marketplace 有料 packs 数十件
- **代表的有料 pack**:
  - [Men Fitness Bodyweight Exercises Animation Pack](https://lottiefiles.com/marketplace/men-fitness-bodyweight-exercises-2)(65 Lotties)
  - Women Bodyweight Exercises Animation Pack(30 Lotties)
  - Man Doing Exercise Animation Pack(24 Lotties)
- **ライセンス**: [Lottie Simple License](https://lottiefiles.com/page/license)。原文要約引用:
  > "permission, free of charge, to download, reproduce, modify, publish, distribute, publicly display, and publicly digitally perform files, **including for commercial purposes**"
  > "**Attribution is not required**, but giving credit is always appreciated"
  > "Modifications ... are deemed derivative works and must also be expressly distributed under the same terms"
  > "does not include the right to **collect or compile files** ... to replicate or develop a similar or competing service"
- **注意点**: Marketplace 有料アセットは個別ライセンス、Simple License 対象外。Free 表示でも作者が独自ライセンスを上書きしている可能性あるため、DL 時に各ページのライセンス表示を必ず確認(公式 Free 領域は Simple License 既定)。
- **主要 5 種目該当**: push-up=**○** / squat=**○** / plank=**○** / lunge=**△**(Side Lunge は有料 Marketplace 中心) / burpee=**○**
- **高品質無料サンプル URL**:
  1. [Pushup / saagar shrestha](https://lottiefiles.com/22917-pushup) — Free
  2. [Squat / Daniel Bogdanov](https://lottiefiles.com/free-animation/squat-vSgVOYiNCJ) — Free
  3. [Plank コレクション(複数作者)](https://lottiefiles.com/free-animations/plank) — Free 含む
  4. [Burpee and Jump / Dinh Bui Xuan](https://lottiefiles.com/free-animation/burpee-and-jump-exercise-gCOcxxnr1X) — Free
  5. [Yoga Pose / Patchpo](https://lottiefiles.com/15156-yoga-pose) — Free
  6. [Home Workout / Sant Rojas](https://lottiefiles.com/23724-home-workout) — Free
  7. [Fitness / SIMPOOLI](https://lottiefiles.com/61723-fitness) — Free
  8. [Workout](https://lottiefiles.com/33897-workout) — Free
- **価格感覚**: Free $0、Marketplace pack は概ね **$15–$60 / pack**(1 パック 20–65 種目)。単品有料は稀。
- **Free / Premium 比率**: 検索結果は Free 約 7 割、Premium pack 約 3 割。

### 2.2 Rive
- **Marketplace**: [rive.app/marketplace](https://rive.app/marketplace/) に Featured / Latest / For Hire セクション。fitness 専用カテゴリ無し、`Rive Exercise` (ookotigo) など散発的に存在。**セット販売の運動アニメパックは見当たらない**。
- **ライセンス**: Marketplace アセットは作者ごとに無料 / 有料が混在。Rive 自体は **アプリ組込み (Runtime) は無料**、Editor のみ Pro $14/月。WorkoutKit は閲覧側なのでアプリ組込みコストはゼロ。
- **iOS SDK**: [rive-app/rive-ios](https://github.com/rive-app/rive-ios)、**SwiftPM 公式対応**、`import RiveRuntime`、Min iOS 14.0 で問題なし。
- **評価**: 既製品で 50 種目即時調達には不向き。**自作する場合の Player 基盤としては最有力**。

### 2.3 OpenGameArt
- **検索結果**: `CC0 Modular Animated Vector Characters 2D`、`CC0 Walk Cycles` など汎用キャラ素材は豊富(idle/walk/run/jump)。**fitness/squat/push-up 特化スプライトは無い**。
- **ライセンス**: CC0 / CC-BY フィルタ可。CC0 は帰属不要・商用 OK。
- **評価**: 直接の運動アニメ無し。汎用キャラに自前モーション付けする前提なら使えるがコスト過大。

### 2.4 Mixamo
- **ライセンス**(Adobe アカウント必須):
  > "characters and animations royalty free for personal, **commercial**, and non-profit projects"
  > "**No credit is required** to Adobe, Mixamo, or Fuse"
  > **重要制約**: "Characters and animations **cannot be redistributed as standalone assets** — they must be incorporated into a project"
  > "must have Mixamo content in an **'embedded', non-editable** format"
- **App Store 配布**: OK(アプリ内焼き込みなら問題なし)
- **種目数**: squat / pushup / sit-up / lunge / burpee / jumping-jack / plank / yoga / dance など **fitness 寄せ公式アニメ多数(数百本)**。
- **出力形式**: FBX / DAE。iOS 取り込みは SceneKit + DAE が最短。RealityKit は FBX → USDZ 変換が必要で工数高。
- **評価**: 3D 路線を採るなら最強だが、3D ランタイムを iOS に積むコスト大。**v1.1+ の 3D オプションとして温存**。

### 2.5 Sketchfab
- **検索**: `tags/cc0`、`tags/cc-by` で fitness 系該当あり。`fitness animation` (amir.poorazima)、`Gym 5 exercises animated` (luismi93、有料 Sketchfab Store) 等。
- **ライセンス**:
  > "CC BY Attribution (default, always on) requires that someone who uses your work must give you credit"
  > "CC license and attribution **must follow the asset everywhere it is used**"
- **評価**: CC-BY が大半で帰属表示の運用が必要(App 内 Credits 画面)。CC0 で fitness 動作付きはほぼ無い。

### 2.6 Freepik / Vecteezy / IconScout / Storyset
- **IconScout**: "Use of Files in your product or project **without attributing the creator(s) of the Files is permitted** under this license" — Free Lottie pack あり、個別アニメごとに Free Commercial License 表示確認必須。
- **Storyset (Freepik 系)**: "you must **always include the attribution to Storyset** every time you use our free illustrations" — **Free は帰属必須**。
- **Vecteezy**: Free は帰属必須、Pro は帰属不要。
- **Freepik**: 同様に Free は帰属必須、Premium ($15/月程度) で帰属不要。
- **評価**: **個人開発 Pro アプリで毎ファイル帰属表示は管理コスト大**。IconScout の Free Commercial License (帰属任意) で絞り込めば現実的。

### 2.7 その他
- **Adobe Stock / Envato Elements / Motion Array**: $14.5–$33/月。150 種目集中 DL する月だけ加入する戦略は有効。
- **GitHub CC0 fitness Lottie コレクション**: 直接該当する公開リポジトリは検索範囲では発見できず。
- **gym-animations.com / exerciseanimatic.com**: fitness 専門のストックも存在するが、いずれも Pay-per-use または高額サブスク。

### 2.x ライセンス互換性まとめ表

| ソース | 商用利用 | 帰属表示 | 改変 | App Store 配布 OK | 件数感 |
|---|---|---|---|---|---|
| **LottieFiles (Free)** | ○ | **不要** | ○ (派生物は同ライセンス) | ○ | fitness Free 数百件 |
| LottieFiles (Marketplace) | ○ (個別) | 個別 | 個別 | ○ (purchase 後) | pack 数十 |
| Rive Marketplace | 作者次第 | 作者次第 | ○ | ○ | fitness 専用は希少 |
| OpenGameArt (CC0) | ○ | 不要 | ○ | ○ | fitness 特化なし |
| **Mixamo** | ○ | **不要** | ○ | ○ (要 embed) | exercise 多数 |
| Sketchfab CC0 | ○ | 不要 | ○ | ○ | fitness 特化少 |
| Sketchfab CC-BY | ○ | **必須・追従** | ○ (派生物表示) | ○ (要 Credits 画面) | fitness 数十 |
| IconScout Free | ○ | 不要 (Simple License) | ○ (再販不可) | ○ | fitness pack 数件 |
| Storyset Free | ○ | **必須** | ○ | ○ (要 Credits 画面) | 運動シーン 中 |
| Vecteezy / Freepik Free | ○ | **必須** | ○ | ○ (要 Credits 画面) | 中 |
| Adobe Stock / Envato (有料) | ○ | 不要 | ○ | ○ | 大量 (サブスク中限定) |

### Phase 2 から得られた示唆

- **本命は LottieFiles の Free + 不足分のみ Marketplace pack 単発購入**。Lottie Simple License は帰属不要・商用 OK・改変可。SwiftUI 組込みも `lottie-ios` (Airbnb 公式 SPM) で容易。150 種目を 100% Free だけで揃えるのは難しいので、`Men Fitness Bodyweight Exercises Animation Pack` (65 Lotties) を 1〜2 本買うと一気に埋まる。
- **地雷は Storyset / Vecteezy / Freepik の Free**。「Free 商用 OK」と書いてあっても **帰属表示が必須**で、Pro 課金アプリで個別アセット帰属を Settings に列挙する運用負荷は予想以上。採用するなら Pro 機能化で帰属解除する前提。
- **Mixamo は技術バンプが大きい**。3D ランタイム (SceneKit/RealityKit) を初版に積むのはアプリサイズと開発工数が跳ねる。CLAUDE.md §0.2 の「動画なし・ステップイラスト方針」と整合的なのは **v1.0 は 2D Lottie 一本化**。
- **ライセンス追跡は初日から仕組み化**。`Resources/Animations/<slug>.lottie` と並走して `Resources/Animations/LICENSES.json` を持ち、各 slug の `source` / `author` / `license` / `licenseURL` / `requiresAttribution` を必ず記録。CC-BY 系を 1 件でも混ぜたら App の Credits 画面 (Settings タブ内) に自動列挙する仕組みを最初から入れる。**後付け改修は地獄**。
- **LottieFiles "compile/replicate" 条項に注意**。Simple License は「LottieFiles の Free アニメをまとめて競合サービスを作る」ことを禁じる。WorkoutKit は集約サービスではなく fitness アプリ内部利用なので問題ないが、将来「カスタムテンプレート共有」のような機能で他ユーザに Lottie 配布するなら再確認必要。

-----

## Phase 3: 技術的選択肢の整理

### 3.1 比較表

| 方式 | 1 体ファイルサイズ | 視覚品質 | 実装工数 | 50 体総容量 | ライセンス | iOS native 性 | §-1 Lock 抵触 |
|---|---|---|---|---|---|---|---|
| **(A) Lottie JSON** | 50–200 KB | **高**(プロイラスト次第) | **中**(SPM `lottie-ios` 追加 + JSON 読込) | 5–10 MB | source 次第(LottieFiles Simple OK) | ◎(Airbnb 公式) | ❌ 無し |
| (B) APNG / WebP | 200–500 KB | 中-高 | 中(`UIImage(named:)` ループ or 自前 decoder) | 20–25 MB | source 次第 | ○(WebP は SDWebImage 等) | ❌ 無し |
| (C) Mixamo 3D + RealityKit/SceneKit | 1–5 MB | 高(角度自在) | **高**(3D ランタイム + bone 制御) | 100–250 MB | Adobe FAQ 商用 OK | ○(SceneKit native) | ❌ 無し(動画ではない) |
| (D) 動画 mp4 ループ | 1–5 MB | 高 | 中 | 100–250 MB | source 次第 | ◎(`AVPlayer`) | **❌ §-1 Lock 違反** |
| (E) SwiftUI procedural | 0 KB | **低-中**(却下済) | 高(ボーン関節を全種目分定義) | 0 MB | ライセンスフリー | ◎ | ❌ 無し(却下済) |
| (F) 静止イラストカルーセル | 100–500 KB | 中(動きはない) | **低**(`Image` + `TabView`) | 5–25 MB | source 次第 | ◎ | ❌ 無し |
| (G) Rive | 50–300 KB | 高 | 中-高(SPM `rive-ios` + `.riv` 制作) | 5–15 MB | 作者次第 | ○ | ❌ 無し |

### 3.2 補足

- **(A) Lottie**: 業界デファクト。デザイナー → After Effects → Bodymovin プラグインで `.json` 書き出し → アプリ同梱。Airbnb の `lottie-ios` (BSD-3) は SwiftUI 対応済 (`LottieView`)。**WorkoutKit の精神(オフライン・軽量・OSS 寄り)と相性最高**。
- **(B) APNG/WebP**: GIF の上位互換。Lottie より画像感が強い(写真ベースの中間表現が可能)。SDWebImage (MIT) が SPM 対応。サイズが Lottie の 2-3 倍重い。
- **(C) Mixamo 3D**: Hevy 路線。1 つのキャラ + 多数のアニメ → 角度切替・部位ハイライト連動が可能。**v1.1+ で 3D オプションとして提供**するのが筋。初版に積むと開発が止まる。
- **(D) 動画**: §-1.10 同梱基準と Bundle 容量制約から **絶対不可**。
- **(E) procedural**: 既に却下済。プロイラストの代替にはなり得ない。
- **(F) 静止画 2 枚カルーセル**: 「開始姿勢 / 終了姿勢」の 2 枚を交互表示で「動きを示唆」。最低限の品質保証ライン。Fiverr で 1 枚 $5–$15、150 種目で $1,500–$4,500。**Lottie が見つからない種目のフォールバック**として有用。
- **(G) Rive**: Lottie より柔軟(state machine、インタラクション)だが、運動アニメパックの市場が薄い。**自作前提なら最強、買い物用途なら不向き**。

### 3.3 推奨ハイブリッド

純粋に「全種目を Lottie で揃える」のは現実的でない。**(A) + (F) + (将来 C) のハイブリッド**を推奨:

| Tier | 方式 | 対象種目 | 数 |
|---|---|---|---|
| Tier 1 | (A) Lottie 高品質 | 主要 50 種目(BIG 6 系、頻出種目) | 50 |
| Tier 2 | (A) Lottie pack 流用 | 中位 100 種目 | 100 |
| Tier 3 | **(F) 静止画 2 枚カルーセル** | 残り 195 種目(マイナー種目) | 195 |
| 将来 | (C) Mixamo 3D | Pro 限定の高品質モード | 全種目相当 |

-----

## Phase 4: 推奨案

### 4.1 第一推奨

> **(A) LottieFiles Free + Marketplace Pack 1〜2 本を主軸に、(F) 静止イラストカルーセルでフォールバック**。
> 3D は v1.1+ の Pro 機能として温存。

**理由**:
- §-1 Lock(動画禁止、オフライン、軽量)と整合
- ライセンス管理コストが最も低い(Lottie Simple License は帰属不要)
- iOS 側の実装が `lottie-ios` SPM 追加だけで済む
- 個人開発 1 名で 1 ヶ月以内に 50 種目を本番品質に上げられる
- Liftin' という商業前例がある(stick figure 却下のリスクが既に検証されている)

### 4.2 代替案(プラン B)

第一推奨が破綻するのは以下のケース:
1. LottieFiles Free / Marketplace の **品質が試作で期待以下**だった
2. ライセンス文言の解釈で揉めて使えなくなった
3. 50 種目相当が揃わない種目カバレッジ問題が顕在化した

**プラン B**:
- **Fiverr / CrowdSpring でプロイラストレーターに直発注**
- 「開始姿勢 + 終了姿勢」2 枚 / 種目 = 100 枚 を $500–$1,500 で発注(50 種目分)
- アプリ側は SwiftUI `TimelineView` で 1.5 秒ごとに切替 → Lottie 風の動きを擬似表現
- ライセンスは「買い切り、商用利用 OK」を契約に明記
- 後で同じイラストレーターに After Effects アニメ化を追加発注すれば Lottie 化も可能

### 4.3 Phase 1(MVP プロト)作業計画 — 5 種目

**目的**: 「Lottie アプローチが UX 上 OK か」を tomo に判定してもらうための最小実証

| ステップ | 内容 | 工数 | コスト |
|---|---|---|---|
| 1 | LottieFiles から 5 種目の Free Lottie を手動 DL(push-up / squat / plank / lunge / burpee) | 30 分 | ¥0 |
| 2 | `Package.swift` に `lottie-ios` (https://github.com/airbnb/lottie-ios) を SPM 追加 | 15 分 | ¥0 |
| 3 | `Resources/Animations/<slug>.json` 配置 + `Resources/Animations/LICENSES.json` を雛形作成 | 30 分 | ¥0 |
| 4 | `Features/Session/Views/ExerciseAnimationView.swift` を新設、`LottieView(animation: .named("push-up"))` で表示 | 1 時間 | ¥0 |
| 5 | Session 実行画面に組込み、5 種目で実機確認(60 fps、ダーク/ライト) | 1 時間 | ¥0 |
| 6 | tomo 確認 → 「品質 OK」なら Phase 2 へ進む / 「NG」ならプラン B 検証 | — | — |

**合計: 1〜2 日 / ¥0〜¥3,000**(pack 1 本買う場合 +$15〜$30)

**成功判定**:
- ファイルサイズ 50–200 KB / 体に収まる
- 60 fps で滑らかに動く(iPhone 15 Pro 実機)
- tomo が「もう棒人間ではない、教育用イラストだ」と納得する

### 4.4 Phase 2(本番、50 種目)作業計画

**目的**: v1.0 出荷条件を満たす(§-1.10 STRENGTH compound 30 + isolation 一部)

| ステップ | 内容 | 工数 | コスト |
|---|---|---|---|
| 1 | LottieFiles Free から「直接該当する」種目を最大 30 個 DL(WARMUP / 主要種目) | 4 時間 | ¥0 |
| 2 | 不足分用に `Men Fitness Bodyweight Exercises Animation Pack` ($30 程度) と Women 版 ($20–30) を購入 | 30 分 | ¥4,500–¥9,000 |
| 3 | Pack 内アニメと種目マッピング、命名規約 (`<slug>.json`) に変換 | 4 時間 | ¥0 |
| 4 | `LICENSES.json` 自動生成スクリプト + Settings の Credits 画面 | 1 日 | ¥0 |
| 5 | Lottie が見つからない 10–15 種目について Fiverr で静止画 2 枚 / 種目を発注 | 1 日(待ち時間別) | ¥7,500–¥22,500 |
| 6 | 静止画カルーセルコンポーネント `StillImageCarouselView` 実装 | 半日 | ¥0 |
| 7 | バンドルサイズ確認(50 種目 → 5–15 MB 目標) | 1 時間 | ¥0 |
| 8 | TestFlight 配布 + 知人 5 人にレビュー依頼 | 2 時間 + 待ち | ¥0 |

**合計: 2〜3 週間 / ¥15,000–¥40,000**

### 4.5 Phase 3(全種目、345 種目)戦略

> 345 種目すべてに Lottie を用意するのは個人開発で非現実的。**段階的拡張 + コミュニティ寄稿モデル**で攻める。

#### 戦略 A: 段階配信(リソースの「重さ」を分散)
- v1.0: 50 種目に Lottie、残りは静止画カルーセル → アプリサイズ 30 MB 程度
- v1.1: +50 種目を Lottie 化 → 60 MB
- v1.2: +50 種目 → 90 MB
- v2.0: 全 345 種目を Lottie 化 → 200 MB(Lottie 平均 100 KB × 345 + その他)
- **§-1.5 ODR (On-Demand Resources)** を活用すれば初回 DL 容量を抑えられる(`videos.<muscle>` タグ規約は既存)

#### 戦略 B: Pack 大量購入(時間で買う)
- Adobe Stock / Envato Elements を 1〜2 ヶ月だけ加入(¥3,000–¥6,000/月)
- "exercise" "fitness" 検索で 200–300 体を一括 DL
- 解約してプロジェクト永久利用(Envato は Lifetime License)
- **半年以内に 200 体到達可能、コスト ¥10,000–¥20,000**

#### 戦略 C: コミュニティ寄稿(workout-cool 型)
- GitHub Discussions で「アニメ寄稿募集」を立ち上げ
- 寄稿条件: Lottie Simple License or CC0 で同梱可
- 寄稿者は Settings の Credits 画面に名前掲載(Pro 機能で帰属解除)
- workout-cool が GitHub で CSV 寄稿を募るのと同じモデル
- **タダだが時間と運営コストがかかる、v2.0+ で検討**

#### 戦略 D: 3D 切替オプション(Pro 限定)
- v1.1+ で Mixamo 3D + SceneKit プレビューを Pro 機能として追加
- 1 つの 3D キャラ + ボーンアニメで全種目をカバー(rigging が共通なら)
- アプリサイズ +50–100 MB を Pro ユーザーのみに ODR で配信
- **2D Lottie が「教科書イラスト」、3D が「ジムトレーナー視点」と差別化**

#### 推奨優先順位
1. **戦略 A**(段階配信)を必ず採る
2. **戦略 B**(Pack 大量購入)を v1.0 直前に 1 ヶ月実施
3. **戦略 D**(3D Pro オプション)を v1.1+ で実装
4. **戦略 C**(コミュニティ)は v2.0+ の長期戦略

### 4.6 リスクと回避策

| リスク | 確率 | 影響 | 回避策 |
|---|---|---|---|
| LottieFiles の品質が試作で期待以下 | 中 | 高 | プラン B(Fiverr 静止画)へ即切替 |
| Marketplace pack の作風がバラつく | 高 | 中 | 同じ作者の pack で統一、不揃いなら静止画化 |
| `lottie-ios` の SwiftUI API が iOS 17 で挙動変 | 低 | 低 | Airbnb 公式メンテ、issue 多数で発覚しやすい |
| アプリサイズが App Store 4 GB 上限超え | 低 | 高 | ODR で muscle 別配信(§-1.8 規約) |
| ライセンス追跡漏れで App Store リジェクト | 中 | 高 | `LICENSES.json` を CI で検証、コミット時必須化 |
| Lottie が部位ハイライト等の高度要件と合わない | 中 | 中 | v1.1+ で Rive または 3D に部分置換 |

### 4.7 必要な決定事項(tomo の判断待ち)

1. **Phase 1 MVP プロトを着手して良いか?**(1〜2 日、¥0〜¥3,000)
2. v1.0 で **50 種目 Lottie + 残り静止画**で出荷する方針を承認するか?
3. 月額サブスク(Adobe Stock / Envato Elements)を 1〜2 ヶ月利用する予算 ¥6,000–¥12,000 を許可するか?
4. 3D 路線(Mixamo)は v1.1+ Pro 機能で確定で良いか?
5. ライセンス管理(`LICENSES.json` + Credits 画面)を §-1 Foundation Lock に追記するか?

-----

## Appendix A: 参考リンク全集

### 競合アプリ App Store / 公式
- [workout-cool iOS](https://apps.apple.com/us/app/workout-cool/id6749820499)
- [StrongLifts 5×5](https://apps.apple.com/us/app/stronglifts-5x5-workout/id488580022) / [stronglifts.com](https://stronglifts.com/app/)
- [Nike Training Club](https://www.nike.com/ntc-app)
- [Fitbod](https://fitbod.me/) / [TechRadar review](https://www.techradar.com/health-fitness/fitbod-app-review)
- [Centr](https://centr.com/)
- [Sworkit](https://apps.apple.com/us/app/sworkit-personalized-workouts/id527219710)
- [Caliber](https://caliberstrong.com/workout-app/)
- [JEFIT](https://www.jefit.com/)
- [Hevy exercise library](https://www.hevyapp.com/features/exercise-library/)
- [Strong](https://www.strong.app/)
- [Liftin' / Jamoora Studio case study](https://jamoorastudio.com/project/liftin/) ★
- [FitNotes X](https://fitnotesx.com/)
- [Ladder](https://www.joinladder.com/)

### ライセンス・素材ソース
- [Lottie Simple License](https://lottiefiles.com/page/license) ★
- [LottieFiles Commercial Use FAQ](https://help.lottiefiles.com/hc/en-us/articles/45243303062681-Commercial-Use-Attribution)
- [LottieFiles Free Fitness](https://lottiefiles.com/free-animations/fitness)
- [LottieFiles Marketplace - Men Fitness Pack](https://lottiefiles.com/marketplace/men-fitness-bodyweight-exercises-2)
- [Rive Marketplace](https://rive.app/marketplace/)
- [rive-app/rive-ios](https://github.com/rive-app/rive-ios)
- [Mixamo FAQ - Adobe](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)
- [Sketchfab Licenses](https://sketchfab.com/licenses)
- [IconScout Licenses](https://iconscout.com/licenses)
- [Storyset FAQs](https://storyset.com/faqs)
- [Vecteezy Licensing](https://www.vecteezy.com/licensing)
- [OpenGameArt CC0 collection](https://opengameart.org/content/cc0-resources)
- [airbnb/lottie-ios (SPM)](https://github.com/airbnb/lottie-ios)

### 主要 5 種目候補(LottieFiles Free)
1. [Pushup / saagar shrestha](https://lottiefiles.com/22917-pushup)
2. [Squat / Daniel Bogdanov](https://lottiefiles.com/free-animation/squat-vSgVOYiNCJ)
3. [Plank コレクション](https://lottiefiles.com/free-animations/plank)
4. [Burpee and Jump / Dinh Bui Xuan](https://lottiefiles.com/free-animation/burpee-and-jump-exercise-gCOcxxnr1X)
5. [Yoga Pose / Patchpo](https://lottiefiles.com/15156-yoga-pose)

### サンプル DL について
LottieFiles の CDN は curl/WebFetch を 403 でブロックする(anti-scrape)。本タスクでは直接 DL に失敗したため、URL 一覧を `/tmp/anim-samples/SAMPLE_URLS.md` に保存。**ブラウザで lottiefiles.com にログイン → "Lottie JSON" ボタンで手動 DL** する必要あり(MVP プロト着手時に tomo 自身で実行推奨、または別タスクで Chrome MCP 使って自動化)。

-----

## 改訂履歴

| Date | Author | Note |
|---|---|---|
| 2026-05-05 | Claude (research/exercise-animation-quality) | 初版。Phase 1〜4 + Appendix。実装着手前の判断材料として作成。 |

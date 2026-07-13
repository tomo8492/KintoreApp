# フォームイラスト生成仕様書(Phase 2-1 コンテンツ準備)

> CLAUDE.md §5-1「機能一覧とフェーズ」には無い補助タスク。
> `StepsCardView`(`WorkoutKit/Features/Library/StepsCardView.swift`)は本タスクで
> 画像描画インフラを実装済み。**アセットを `Assets.xcassets/ExerciseSteps/` に
> 追加するだけ**で本番に反映される(コード変更不要)。
>
> 対象読者: イラスト生成を担当する人間 / 生成 AI ワークフロー。

---

## 1. 実装済みインフラの前提(読者への注記)

`StepsCardView` は各ステップに対応する画像を次の優先順位で探す。

1. `Exercise.stepImagesRaw`(JSON 配列)で明示された名前
   例: `["barbell-back-squat-step-1.png", "barbell-back-squat-step-2.png"]`
   (`.png` 等の拡張子は自動的に取り除いてアセット名として解決する)
2. 上記が無ければ命名規約 `<slug>-step-<n>`(1-based)でアセットカタログを検索

どちらの経路でも `UIImage(named:)` でアセットの実在を確認してから使用するため、
**アセットが無いステップは今まで通りテキストのみのカードになる**(見た目の破壊なし)。
そのため本仕様書に従って `<slug>-step-1` / `<slug>-step-2` の imageset を追加するだけで、
`exercises_seed.json` の `stepImagesRaw` を書き換えなくても画像が有効化される。

---

## 2. 対象種目:高リスク 62 種目

**選定基準**: `WorkoutKit/Resources/exercises_seed.json`(345 種目)のうち、
`cautionsJa` を改行区切りで分割した際の項目数が **3 個以上** の種目。
「注意点が多い = フォームを誤ると怪我のリスクが高い」種目を優先してイラスト化する。

抽出コマンド(参考、Python):

```python
import json
with open("WorkoutKit/Resources/exercises_seed.json", encoding="utf-8") as f:
    data = json.load(f)

def items(s):
    return [x.strip() for x in s.split("\n") if x.strip()]

high_risk = [ex for ex in data if len(items(ex.get("cautionsJa", ""))) >= 3]
print(len(high_risk))  # => 62
```

### 2-1. 部位別内訳(primaryMuscleRaw)

| 部位 | 件数 |
|---|---|
| quadriceps(大腿四頭筋) | 20 |
| hamstrings(ハムストリングス) | 9 |
| deltoids(三角筋) | 6 |
| fullBody(全身) | 6 |
| glutes(お尻) | 5 |
| lats(広背筋) | 5 |
| chest(胸) | 4 |
| lowerBack(腰・脊柱起立筋) | 3 |
| traps(僧帽筋) | 2 |
| triceps(上腕三頭筋) | 1 |
| obliques(腹斜筋) | 1 |
| **合計** | **62** |

> スクワット・デッドリフト系(quadriceps / hamstrings / glutes / lowerBack)だけで
> 62 種目中 37 種目(約6割)を占める。下半身の可動域の大きい複合種目ほど
> `cautionsJa` の項目数が多く、優先度が高いことが分かる。

### 2-2. 全リスト(slug / nameJa / primaryMuscleRaw / equipment)

| # | slug | 種目名(Ja) | 主働筋 | 器具 |
|---|---|---|---|---|
| 1 | `barbell-back-squat` | バーベルバックスクワット | quadriceps | barbell |
| 2 | `barbell-bench-press` | バーベルベンチプレス | chest | barbell,bench |
| 3 | `decline-barbell-press` | デクラインバーベルプレス | chest | barbell,bench |
| 4 | `dumbbell-shoulder-press` | ダンベルショルダープレス | deltoids | dumbbell,bench |
| 5 | `seated-barbell-shoulder-press` | シーテッドバーベルショルダープレス | deltoids | barbell,bench |
| 6 | `arnold-press` | アーノルドプレス | deltoids | dumbbell,bench |
| 7 | `push-press` | プッシュプレス | deltoids | barbell |
| 8 | `barbell-deadlift` | バーベルデッドリフト | lowerBack | barbell |
| 9 | `romanian-deadlift` | ルーマニアンデッドリフト | hamstrings | barbell |
| 10 | `sumo-deadlift` | スモウデッドリフト | glutes | barbell |
| 11 | `trap-bar-deadlift` | トラップバーデッドリフト | hamstrings | barbell |
| 12 | `front-squat` | フロントスクワット | quadriceps | barbell |
| 13 | `goblet-squat` | ゴブレットスクワット | quadriceps | dumbbell,kettlebell |
| 14 | `bulgarian-split-squat` | ブルガリアンスプリットスクワット | quadriceps | dumbbell,bench |
| 15 | `dumbbell-walking-lunge` | ダンベルウォーキングランジ | quadriceps | dumbbell |
| 16 | `barbell-walking-lunge` | バーベルウォーキングランジ | quadriceps | barbell |
| 17 | `step-up` | ステップアップ | quadriceps | dumbbell,bench |
| 18 | `barbell-hip-thrust` | バーベルヒップスラスト | glutes | barbell,bench |
| 19 | `dumbbell-hip-thrust` | ダンベルヒップスラスト | glutes | dumbbell,bench |
| 20 | `barbell-row` | バーベルロー | lats | barbell |
| 21 | `t-bar-row` | Tバーロー | lats | barbell,machine |
| 22 | `clean-and-press` | クリーン&プレス | fullBody | barbell |
| 23 | `dumbbell-thruster` | ダンベルスラスター | fullBody | dumbbell |
| 24 | `kettlebell-swing` | ケトルベルスイング | glutes | kettlebell |
| 25 | `barbell-shrug` | バーベルシュラッグ | traps | barbell |
| 26 | `sissy-squat` | シシースクワット | quadriceps | bodyweight |
| 27 | `dumbbell-farmer-walk` | ダンベルファーマーウォーク | fullBody | dumbbell |
| 28 | `dip` | ディップ | chest | bodyweight |
| 29 | `pistol-squat` | ピストルスクワット | quadriceps | bodyweight |
| 30 | `handstand-push-up` | 倒立腕立て伏せ | deltoids | bodyweight |
| 31 | `low-bar-squat` | ローバースクワット | quadriceps | barbell |
| 32 | `high-bar-squat` | ハイバースクワット | quadriceps | barbell |
| 33 | `zercher-squat` | ザーチャースクワット | quadriceps | barbell |
| 34 | `box-squat` | ボックススクワット | quadriceps | barbell,bench |
| 35 | `hack-squat-machine` | ハックスクワットマシン | quadriceps | machine |
| 36 | `overhead-squat` | オーバーヘッドスクワット | quadriceps | barbell |
| 37 | `landmine-squat` | ランドマインスクワット | quadriceps | barbell |
| 38 | `snatch-grip-deadlift` | スナッチグリップデッドリフト | traps | barbell |
| 39 | `rack-pull` | ラックプル | lowerBack | barbell |
| 40 | `deficit-deadlift` | デフィシットデッドリフト | hamstrings | barbell |
| 41 | `single-leg-rdl` | 片脚ルーマニアンデッドリフト | hamstrings | dumbbell |
| 42 | `dumbbell-romanian-deadlift` | ダンベルRDL | hamstrings | dumbbell |
| 43 | `close-grip-bench-press` | クローズグリップベンチプレス | triceps | barbell,bench |
| 44 | `behind-neck-press` | ビハインドネックプレス | deltoids | barbell |
| 45 | `pendlay-row` | ペンドレイロー | lats | barbell |
| 46 | `reverse-lunge` | リバースランジ | quadriceps | dumbbell |
| 47 | `weighted-pull-up` | ウエイテッドプルアップ | lats | pullupBar |
| 48 | `power-clean` | パワークリーン | fullBody | barbell |
| 49 | `hang-clean` | ハングクリーン | fullBody | barbell |
| 50 | `cable-pull-through` | ケーブルプルスルー | glutes | cable |
| 51 | `suitcase-deadlift` | スーツケースデッドリフト | obliques | dumbbell |
| 52 | `jefferson-curl` | ジェファーソンカール | lowerBack | dumbbell |
| 53 | `smith-machine-squat` | スミスマシンスクワット | quadriceps | machine |
| 54 | `cyclist-squat` | サイクリストスクワット | quadriceps | dumbbell |
| 55 | `spanish-squat` | スパニッシュスクワット | quadriceps | band |
| 56 | `nordic-hamstring-curl` | ノルディックハムストリングカール | hamstrings | bodyweight |
| 57 | `machine-rdl` | マシンRDL | hamstrings | machine |
| 58 | `kettlebell-rdl` | ケトルベルRDL | hamstrings | kettlebell |
| 59 | `good-morning` | グッドモーニング | hamstrings | barbell |
| 60 | `sandbag-carry` | サンドバッグキャリー | fullBody | bodyweight |
| 61 | `archer-pull-up` | アーチャープルアップ | lats | pullupBar |
| 62 | `clap-push-up` | クラッププッシュアップ | chest | bodyweight |

---

## 3. 優先着手 20 種目:2 フレーム構成(開始ポーズ / 終了ポーズ)

62 種目のうち、スクワット・デッドリフト・プレス・クリーン系という
最も検索頻度・怪我リスクが高い「ビッグリフト系」ファミリーを最優先とする。
各種目 2 フレーム(`-step-1` = 開始ポーズ、`-step-2` = 終了ポーズ)。
説明文は `exercises_seed.json` の `stepTextJaRaw` を要約したもの(生成 AI へのプロンプトの下敷きとして使う)。

### スクワット系(6)

| slug | 開始ポーズ(-step-1) | 終了ポーズ(-step-2) |
|---|---|---|
| `barbell-back-squat` | 足を肩幅に開き、つま先はやや外向き。バーを僧帽筋上部に担いで直立。 | 股関節と膝を曲げ、太ももが床と平行になるまでしゃがんだボトム姿勢。 |
| `front-squat` | バーを鎖骨の上に乗せ、肘を高く保って直立。 | 上体を立てたまま太ももが床と平行になるまでしゃがんだボトム姿勢。 |
| `low-bar-squat` | バーを肩甲骨のやや下(後部三角筋上)に担ぎ、足を肩幅よりやや広めに開いて直立。 | やや前傾姿勢で股関節を後ろに引き、太ももが床と平行になるボトム姿勢。 |
| `overhead-squat` | バーを頭上で肩幅よりやや広く握り、腕をロックして直立。 | バーを頭上に保ったまま太ももが床と平行になるまで深くしゃがんだ姿勢。 |
| `box-squat` | ボックスを後ろに置き、足を肩幅に開いてバーを担いだ直立姿勢。 | 股関節を後ろに引きながらボックスに座り、力を抜かずに一瞬静止した姿勢。 |
| `goblet-squat` | ダンベルまたはケトルベルを胸の前に抱え、足を肩幅よりやや広めに開いた直立姿勢。 | 肘が膝の内側に触れる位置まで沈んだしゃがみ姿勢。 |

### デッドリフト系(5)

| slug | 開始ポーズ(-step-1) | 終了ポーズ(-step-2) |
|---|---|---|
| `barbell-deadlift` | バーの前に立ち、股関節を折って胸を張ったままバーを握った前傾姿勢。 | 床を押すように立ち上がりきった直立姿勢。 |
| `romanian-deadlift` | バーを腿の前で握り、膝を軽く緩めて固定した直立姿勢。 | お尻を後ろに引き(ヒンジ)、すねの中ほどまでバーを下ろした姿勢。 |
| `sumo-deadlift` | 足を肩幅の倍程度に開き、つま先を45度外に向けてバーを握った前傾姿勢。 | 背中を丸めずに立ち上がりきった直立姿勢。 |
| `trap-bar-deadlift` | トラップバー中央に足を腰幅で立ち、ハンドルを握った前傾姿勢。 | 胸を張ったまま真上に立ち上がりきった直立姿勢。 |
| `deficit-deadlift` | 台の上に立ち、バーを腿の前で握った前傾姿勢。 | 背中が丸まる手前まで下ろし、姿勢を確認するボトム姿勢。 |

### プレス系(6)

| slug | 開始ポーズ(-step-1) | 終了ポーズ(-step-2) |
|---|---|---|
| `barbell-bench-press` | ベンチに仰向けになり、バーを肩幅よりやや広く握って肩甲骨を寄せた構え。 | バーを胸の中央まで下ろしたボトム姿勢。 |
| `seated-barbell-shoulder-press` | シートを直立に立て、バーを鎖骨の高さに構えた姿勢。 | バーをまっすぐ頭上に押し上げきった姿勢。 |
| `push-press` | バーを鎖骨の高さのラック位置に構えた直立姿勢。 | 脚の反動を使ってバーを頭上に押し上げきった姿勢。 |
| `arnold-press` | ダンベルを掌が自分側を向く形で胸の前に構えた姿勢。 | 手首を回転させ、頭上で掌が前を向く押し上げきった姿勢。 |
| `behind-neck-press` | バーを首の後ろ、僧帽筋の上に構えた姿勢。 | バーをまっすぐ頭上に押し上げきった姿勢。 |
| `close-grip-bench-press` | ベンチに仰向けになり、肩幅程度の幅でバーを握った構え。 | 肘を体側に近づけたまま胸まで下ろしたボトム姿勢。 |

### クリーン系(3)

| slug | 開始ポーズ(-step-1) | 終了ポーズ(-step-2) |
|---|---|---|
| `power-clean` | バーの前に足を腰幅に開き、膝と股関節を曲げたスタート姿勢。 | 肘を素早く回し込み、バーを鎖骨の上にキャッチして膝を伸ばした直立姿勢。 |
| `hang-clean` | バーを太ももの中央あたりの高さで構え、膝を軽く曲げた姿勢。 | バーを鎖骨の上にキャッチし、膝を伸ばして立ち上がった姿勢。 |
| `clean-and-press` | バーの前に足を腰幅に開き、膝と股関節を曲げたスタート姿勢。 | バーを頭上までまっすぐ押し上げきった姿勢。 |

> 残り 42 種目(表 2-2 参照)は Phase 2-2 以降で同じ 2 フレーム形式に展開する。
> 各種目の `stepTextJaRaw` / `stepTextEnRaw`(3〜6ステップ)から、
> 「最初のステップ = 開始ポーズ」「動作の底/頂点を表すステップ = 終了ポーズ」を
> 抽出すれば同様のプロンプトが作れる。

---

## 4. スタイルガイド

- **統一キャラクター**: 性別中立のシルエット調(顔の特徴を描かない、体型も中立的)。
  全 62 種目・全アプリ内で同一の描画スタイル・同一の体型プロポーションを維持すること。
- **背景**: 透過(アルファチャンネルあり)。カード側の背景色(`AppColor.secondaryBackground`)に
  乗せて表示されるため、白背景の矩形画像にしない。
- **描画技法**: 線画(アウトライン) + 単色塗り。写実的な陰影・グラデーションは避ける
  (ライト/ダークモード両方で視認性を保つため)。
- **差し色**: アプリの accent カラー `#FF6B35` をワンポイントで使う
  (例: 稼働中の関節・注目してほしい部位の強調ラインのみ)。地の塗りは
  ニュートラルなグレー/黒系の線画のみとし、差し色は 1 箇所程度に絞る。
- **解像度**: 1024×1024px で生成。
  実装側は 3x 密度で 400pt 相当(= 1200px 目安)を想定しているため、
  1024px 生成 → 必要に応じて 1200px 前後にアップスケールしても破綻しない
  シンプルな線画にすること。
- **書き出しフォーマット**: HEIC 化してバンドルサイズ増を抑える
  (PNG のまま Assets.xcassets に入れると 62 種目 × 2 枚でサイズが膨らむため、
  Xcode の Asset Catalog Compiler が自動で圧縮する設定、または事前 HEIC 変換のどちらかで対応)。

### アセット命名規約

- imageset 名: `<slug>-step-1` / `<slug>-step-2`
  例: `barbell-back-squat-step-1`, `barbell-back-squat-step-2`
- `<slug>` は `exercises_seed.json` の `slug` フィールドと完全一致させること
  (`StepsCardView` の命名規約フォールバックはこの一致を前提にしている)。
- 3 フレーム以上必要な種目(クリーン系など動作が複雑なもの)は
  `<slug>-step-3` まで拡張可能(`StepsCardView` は `stepTextJaRaw` の
  ステップ数に応じて任意の番号を探索する)。

---

## 5. ワークフロー

1. **生成**: 本仕様書のポーズ説明 + スタイルガイドをプロンプトとして画像生成
   (種目ごとに開始/終了の 2 枚、必要なら中間フレームを追加)。
2. **人間のフォーム正誤 QA(必須)**: 生成画像は AI が誤ったフォーム
   (例: 膝が内側に入る、背中が丸まる)を描いてしまうリスクがあるため、
   トレーニング経験者によるレビューを必ず挟む。特に本仕様書 §2 の 62 種目は
   「注意点が多い = 誤ったフォームで怪我をしやすい」種目なので、
   誤ったフォームを描いた画像をそのまま採用しないこと。
3. **アセット追加**: 承認された画像を
   `WorkoutKit/Resources/Assets.xcassets/ExerciseSteps/<slug>-step-<n>.imageset/`
   に追加(Contents.json は既存 imageset をコピーしてファイル名だけ差し替え)。
4. **xcodegen で自動取込**: `project.yml` のリソースパスは
   `Assets.xcassets` を丸ごと参照しているため、追加の設定変更は不要。
   `xcodegen generate` を実行してプロジェクトファイルを再生成すれば、
   次回ビルドから `StepsCardView` が自動的に画像を描画する
   (`Exercise.stepImagesRaw` の JSON も、`exercises_seed.json` の書き換えも不要)。

---

*本ドキュメントは Phase 2-1(UI インフラ実装)の一部として作成。
実際の画像生成・QA・アセット追加は別タスクで行う。*

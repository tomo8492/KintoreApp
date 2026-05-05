# プロンプトスタイルガイド

50 種目を **同一のキャラクター・同一のスタジオ・同一のスタイル** で揃えるためのプロンプト規約。
`generate.py` はここで定義した規則を機械的に適用するので、変更する場合は **このファイルを正とする**。

---

## 1. 構成

最終プロンプトは 4 ブロックを連結する:

```
[STYLE_PREFIX] , [CHARACTER] , [POSE] , [QUALITY_TAGS]
Negative: [NEGATIVE_TAGS]
```

このうち `[POSE]` のみ種目ごとに `exercises_top50.json` の `pose` フィールドから供給する。残り 3 ブロックは全種目共通。

---

## 2. STYLE_PREFIX(全種目共通)

```
clean isometric illustration, flat shading, athletic instruction diagram,
neutral pure-white studio background, soft directional lighting from upper left,
single subject, full body in frame, centered composition,
no text, no logo, no branding, no UI elements, no captions
```

**意図**:
- *isometric illustration* — 写実より図解寄り。指/顔のディテール破綻が目立ちにくい
- *flat shading + neutral background* — 後段の Asset Catalog で背景を抜かなくてもダーク/ライト両モードで馴染む
- *single subject* — 人物の重複(SD で頻出)を抑止
- *no text / logo / branding* — 文字混入を負側 + 正側の両方で抑制

---

## 3. CHARACTER(全種目共通)

```
athletic Asian male, age 28, lean muscular build,
short black hair, clean-shaven, neutral expression,
plain white short-sleeve t-shirt, plain black athletic shorts, white gym shoes,
no accessories, no jewelry, no tattoos
```

**意図**:
- 国籍 / 性別 / 服装を完全固定 — `seed` 固定 + キャラ固定で 50 枚通しの「同じ人」感を出す
- *plain* / *no accessories* — モデルが勝手にロゴ T シャツを着せる癖を抑止
- 体型は「lean muscular」で固定 — `bulky bodybuilder` も `slim` も避ける(人物変動の原因になる)

> **将来の拡張**: 女性版 / 体格別を追加する場合は `exercises_top50.json` にキャラ ID を持たせ、ここに辞書を増やす。今は YAGNI。

---

## 4. POSE(種目ごと)

`exercises_top50.json` の各 entry の `pose` をそのまま `[POSE]` に流し込む。
記述ルール:

- **視点を最初に**(`side view`, `front view`, `three-quarter view`)
- **動作のフェーズ**を 1 つに絞る(`bottom of squat`, `mid-stride lunge` など)
- **接触面 / 関節角度** を 1〜2 個明記(`thighs parallel to floor`, `elbows bent 90 degrees`)
- 数値は形容詞より具体度を優先(`90 degrees` > `bent`)

`pose` の隣の `equipment` フィールドは負側で「これ以外の器具は描くな」を効かせるためのヒント(後述)。

---

## 5. QUALITY_TAGS(全種目共通)

```
high detail, anatomically correct, professional fitness instruction style,
clear silhouette, balanced composition,
sharp focus, even lighting
```

`8k` / `masterpiece` 系の魔法ワードは **入れない**。
- SDXL 以降では効果が薄く、むしろ過剰彩度を招く
- `professional fitness instruction style` のように **目的を直接書く** ほうが効く

---

## 6. NEGATIVE_TAGS(全種目共通)

```
extra limbs, extra fingers, missing fingers, fused fingers,
mutated hands, malformed limbs, distorted anatomy,
multiple people, two heads, duplicate body,
blurry, low quality, low resolution, jpeg artifacts, noise,
watermark, signature, text overlay, caption, logo, brand name,
nsfw, suggestive, lingerie,
photo, photograph, photorealistic skin pores,
weird shadow, harsh contrast, oversaturated
```

**意図**:
- *肢体破綻系* — SD で最も頻出する破壊
- *multiple people / duplicate body* — シングル被写体を強制
- *photo / photograph* — フラットイラスト方針との混同を避ける(SDXL は放置するとフォトリアルに寄る)
- *nsfw* — Tシャツ + ショーツの服装ブレを抑える(モデルが裸体に寄ることがある)

---

## 7. シードと再現性

| パラメタ | 値 |
|---|---|
| Sampler | `DPM++ 2M Karras` |
| Steps | `28` |
| CFG | `6.5` |
| Width / Height | `1024 x 1024`(SDXL 既定) |
| **Seed (全種目共通)** | `42`(`SD_SEED_BASE` 環境変数で上書き可) |
| Refiner | 有効なら `denoising_strength=0.25` で SDXL Refiner 通す |

**全種目 同一 seed** にする理由: イラスト調 + キャラ固定 + 同 seed の 3 段重ねで「同じ人」一貫性を最大化。
ポーズが seed と相性悪く失敗する種目だけ `--seed` を上書きしてリトライする(`generate.py` が自動で 3 回まで `seed += 1` する)。

---

## 8. 種目ごとの上書き例(参考)

通常はテンプレートのみで足りるが、以下のような特殊ケースは `exercises_top50.json` の `pose` 文を厚めに書く:

| ケース | 書き方の例 |
|---|---|
| 器具を 1 つに限定したい | `holding a single dumbbell vertically against chest` のように個数 + 持ち方を明記 |
| 足/手の位置をはっきりさせたい | `palms shoulder-width on the floor`, `feet shoulder-width apart` |
| 体勢の方向を強制したい | `lying supine`(仰向け)/ `lying prone`(うつ伏せ)/ `kneeling`(膝立ち) |
| 顔が前を向くと変になりがち | `face turned away from camera, focus on body` |

複雑なポーズ(`burpee` の跳躍フェーズなど)は AI が破綻しやすい。**1 フェーズに絞る** のが鉄則。

---

## 9. 採否ガイドライン(後段の人手レビュー用)

50 枚生成後、以下に該当するものは破棄して `--only-failed` で再生成する:

- 指 / 手のいずれかが 6 本以上 or 形が破綻
- 人物が 2 人以上写っている
- 服が T シャツ + 黒ショーツ以外(タンクトップ / 上半身裸 / 長ズボン)
- 器具がポーズと矛盾(`pull-up` なのに地面に立っている等)
- 文字 / ロゴ / 透かしが映り込み
- 顔が極端なクローズアップ or 逆に小さすぎる

**閾値**: 50 枚中 7 枚以下なら成功とみなしてリトライで埋める。10 枚以上失敗するならプロンプト全体を見直す合図(seed か LoRA を変える)。

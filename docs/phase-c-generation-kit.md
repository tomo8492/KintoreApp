# Phase C 実行キット — 動き表現と unfindable 種目の AI 図解生成

> 対象読者: Mac(Apple Silicon, GPU あり)で作業する開発者本人。
> このファイル 1 枚で完結するように書いてある。他のドキュメントを別途参照しなくても着手できる。
> 元ネタ: `docs/form-guide-improvement-plan.md` §Phase C(動き表現と unfindable の解消)、
> `WorkoutKit/Resources/exercises_seed.json`(22 種目分の `stepTextJaRaw` / `cautionsJa` を全件読み込んで本書に反映済み)、
> `tools/sd-batch/`(既存の Top-50 SDXL バッチ生成ツール — プロンプト構造とライセンス知見を流用)。

---

## 0. 前提・スコープ

- **対象 22 種目**(Pexels に存在しないことが確認済み、または存在しても構図がフォーム説明に不向き):
  `preacher-curl` / `skull-crusher` / `face-pull` / `t-bar-row` / `arnold-press` / `reverse-crunch` /
  `hollow-body-hold` / `inverted-row` / `thread-the-needle` / `runners-stretch` / `bulgarian-split-squat` /
  `barbell-hip-thrust` / `lying-leg-curl` / `wrist-flexor-stretch` / `v-up` / `dead-bug` / `diamond-push-up` /
  `figure-four-stretch` / `happy-baby-pose` / `superman` / `dumbbell-shrug` / `stair-climber`
- **成果物**: 種目ごとに 1 枚(1200px JPEG)+ 注釈 JSON + メタ情報。§-1 Lock(動画 mp4 禁止)は継続遵守 — 静止画のみ。
- **既存資産との関係**: `tools/sd-batch/`(Top-50, txt2img のみ・ポーズ固定なし)とは別トラックとして扱う。
  Phase C は「ポーズの正確性が命」の種目(関節角度が細かい・Pexels に存在しない特殊姿勢)なので、
  3D ポーズ参照 → ControlNet でポーズを固定してから生成する、より精度重視のパイプラインを使う。
  プロンプトの共通ブロック(スタイル / 品質 / ネガティブ)の設計思想は `tools/sd-batch/style-guide.md` を踏襲しつつ、
  §2 でキャラクター設定のみ Phase C 専用に変更する(理由は §2 参照)。

---

## 1. パイプライン手順(Mac 前提・step-by-step)

### 1-0. 環境準備(1 回だけ)

| 項目 | 内容 |
|---|---|
| OS | macOS 14 Sonoma 以降(15 Sequoia 以降推奨) |
| チップ | Apple Silicon 必須(M1 以降)。ComfyUI + SDXL は 16GB 以上推奨 |
| ComfyUI | [ComfyUI](https://github.com/comfyanonymous/ComfyUI) を `git clone` → `pip install -r requirements.txt`。Apple Silicon は `--force-fp16` オプションで起動すると安定しやすい |
| モデル | SDXL Base 1.0(`stabilityai/stable-diffusion-xl-base-1.0`)または FLUX.1-schnell(`black-forest-labs/FLUX.1-schnell`)。`ComfyUI/models/checkpoints/` に配置 |
| ControlNet | SDXL 用 Depth ControlNet(`diffusers/controlnet-depth-sdxl-1.0` など)。FLUX を使う場合は `InstantX/FLUX.1-dev-Controlnet-Union` 系は **dev 系のため商用不可**(§1-6 参照)、FLUX + ControlNet は現状 schnell 対応版が限られるため、**FLUX を使う場合は ControlNet なしで PoseMy.Art のスクリーンショットをそのまま構図参考(img2img 下絵)にする**のが現実的な代替策 |
| ComfyUI Manager | ノード検索・依存解決を楽にするため導入推奨(`ComfyUI-Manager` custom node) |

### 1-1. PoseMy.Art でポーズ作成

1. ブラウザで [PoseMy.Art](https://posemy.art/) を開く(無料・アカウント登録不要、Flash 不要の Web 版)。
2. 3D マネキン(性別ニュートラルなベースモデルを選択)を配置し、§3 の各種目の「関節角度の要点」に従って関節を動かす。
   - 数値が明記されている箇所(例: 「膝を90度に曲げる」)は角度をできるだけ正確に合わせる。
   - カメラは §3 で指定した「推奨カメラアングル」に固定する(ポーズ作成後にアングルを変えると ControlNet 用の投影が崩れるため、最初に決める)。
3. 器具(バー・ベンチ・ケーブル等)は PoseMy.Art の Prop 機能で置けるものは置く。置けない器具(バーベルシャフトの正確な太さ等)は無理をせず省略し、生成プロンプト側の POSE 記述で言葉で補う(§1-4)。
4. ポーズが決まったら **同一シーンから 2 種類の画像を書き出す**:
   - a) 通常のレンダリング(構図確認用、生成には使わない)
   - b) **OpenPose 用スケルトン**(関節点のみの棒人間)— PoseMy.Art の Export 機能、または画面キャプチャ後に `controlnet_aux` の `OpenposeDetector` で骨格抽出
   - c) **Depth マップ**(グレースケール、カメラに近いほど白)— PoseMy.Art に深度書き出し機能がなければ、b) のスクリーンショットを [MiDaS](https://github.com/isl-org/MiDaS)(`controlnet_aux` の `MiDaS-DepthMapPreprocessor` ノードで代替可、ComfyUI 内で完結)にかけて生成する

> リグ資産(一度作った姿勢データ)は種目間で使い回せる場合がある(例: `bulgarian-split-squat` の後ろ足の姿勢は `runners-stretch` の後ろ脚と近い)。保存しておくと 2 種目目以降が速くなる。

### 1-2. ComfyUI ワークフロー構成

最小構成のノードグラフ(SDXL + Depth ControlNet):

```
[LoadImage: depth-map.png]
        │
        ▼
[ControlNetLoader: control-depth-sdxl] ── strength 0.8〜0.9 ──▶ [ControlNetApply]
        │                                                            │
[CLIPTextEncode: positive prompt] ─────────────────────────────────▶│
[CLIPTextEncode: negative prompt] ─────────────────────────────────▶│
        │                                                            ▼
[CheckpointLoader: sd_xl_base_1.0.safetensors] ──────────────▶ [KSampler]
        │                                                            │
        ▼                                                            ▼
[EmptyLatentImage: 1024x1024]                              [VAEDecode] → [SaveImage]
```

- OpenPose スケルトンも使いたい場合は `ControlNetApply` をもう 1 段挟んで **Multi-ControlNet**(Depth: strength 0.85 / OpenPose: strength 0.6)にする。Depth を主、OpenPose を関節精度の補助として使うのが安定する。
- FLUX.1-schnell を使う場合は KSampler の代わりに `KSamplerSelect`(Euler)+ `BasicScheduler`(simple)を使う ComfyUI 公式の Flux ワークフローをベースにする。Flux は distilled(蒸留)モデルのため SDXL 用の CFG 6.5 をそのまま当てはめない(§1-5 参照)。

### 1-3. プロンプトテンプレート — ベース(全 22 種目共通)

`tools/sd-batch/style-guide.md` の 4 ブロック構成を継承しつつ、Phase C 専用にキャラクターを変更したものを使う(理由は §2)。

```
[STYLE_PREFIX_C] , [CHARACTER_C] , [POSE(種目ごと・§3)] , [QUALITY_TAGS_C]
Negative: [NEGATIVE_TAGS_C]
```

**STYLE_PREFIX_C**(全種目共通):
```
clean flat-shading illustration, simplified diagram-style rendering,
soft ambient shadow (not photorealistic), single solid flat mid-gray studio
background, no gradient, no props in background, single subject,
full body in frame, centered composition,
no text, no logo, no branding, no UI elements, no captions
```

**CHARACTER_C**(全種目共通、詳細は §2):
```
gender-neutral athletic adult, age-neutral build, short neutral hairstyle,
calm neutral facial expression, plain solid heather-gray athletic tank top,
plain solid dark-gray athletic shorts, plain training shoes,
no accessories, no jewelry, no visible tattoos, no gender-signaling props
```

**QUALITY_TAGS_C**(全種目共通):
```
high detail, anatomically correct, professional fitness instruction diagram,
clear silhouette, balanced composition, sharp focus, even soft lighting
```

**NEGATIVE_TAGS_C**(全種目共通 — `tools/sd-batch/style-guide.md` のネガティブ規約を継承 + 写実化防止を強化):
```
extra limbs, extra fingers, missing fingers, fused fingers,
mutated hands, malformed limbs, distorted anatomy, broken joints,
elbow bending backward, knee bending backward,
multiple people, two heads, duplicate body,
blurry, low quality, low resolution, jpeg artifacts, noise,
watermark, signature, text overlay, caption, logo, brand name,
nsfw, suggestive, lingerie, gendered props, high heels, dress, skirt,
photo, photograph, photorealistic, DSLR, film grain, skin pores,
weird shadow, harsh contrast, oversaturated, cluttered background, gym equipment in background
```

`[POSE]` は §3 の各種目「推奨カメラアングル」+「関節角度の要点」+「器具と接点の注意」を 1〜2 文の英語プロンプトに凝縮したものを差し込む(`tools/sd-batch/style-guide.md` §4 のルール — 視点を最初に、フェーズを 1 つに絞る、接触面/関節角度を具体的な数値で書く — をそのまま適用)。

### 1-4. 推奨パラメータ

| パラメータ | SDXL + Depth ControlNet | FLUX.1-schnell(ControlNet 非対応時の代替) |
|---|---|---|
| Sampler | `DPM++ 2M Karras` | `Euler`(ComfyUI: `KSamplerSelect`) |
| Scheduler | `karras` | `simple` |
| Steps | 28 | 4(schnell は蒸留モデルのため steps を増やしても改善しない) |
| CFG | 6.5 | 1.0 前後(schnell は guidance-distilled。SDXL の CFG 感覚を持ち込まない) |
| 解像度 | 1024×1024 | 1024×1024 |
| **ControlNet strength(Depth)** | **0.8〜0.9**(ポーズ固定を最優先。0.9 超だとイラストらしさが崩れやすいので上限とする) | ControlNet 非対応の場合は img2img の `denoise 0.55〜0.65` で PoseMy.Art スクリーンショットを下絵にする |
| ControlNet strength(OpenPose, 併用時) | 0.5〜0.6(Depth の補助として弱めに) | — |
| Seed | 種目間で共通シード基準値を 1 つ決めて固定(例: `4200`)。ポーズと相性が悪く破綻する種目だけ `+1` して 3 回までリトライ | 同左 |

### 1-5. 手・器具接点の検品

自動生成では **手が握る箇所(バー・ハンドル・パッド・自分の足首など)** が最も破綻しやすい。各種目の生成後、§3「器具と接点の注意」に列挙した接点を目視で確認する:

1. 指の本数が両手とも 5 本か(拡大表示で確認)
2. 握っている器具にめり込んでいないか / 逆に浮いていないか
3. 器具の形状が種目と矛盾していないか(例: `t-bar-row` で V ハンドルの代わりに直バーが生えている、等)

破綻していたら、まず ControlNet strength を 0.05 刻みで上げて再生成 → それでも直らなければ該当箇所だけ Inpaint(ComfyUI の `VAEEncodeForInpaint` + マスク)で部分修正する。

### 1-6. 1200px JPEG 書き出し

```bash
# ComfyUI の SaveImage は PNG 出力なので、統合前に JPEG 化 + リサイズする
sips -s format jpeg -Z 1200 "<slug>-raw.png" --out "<slug>-1.jpeg"
```

- 長辺 1200px に統一(既存の Pexels 由来アセットと解像度感を揃える)。
- JPEG 品質はデフォルト(sips 既定 ≒ 80%相当)で十分。ファイルサイズ目安 150〜400KB。
- 背景がフラット単色のため圧縮効率が良く、写真ソースよりファイルサイズは小さくなりやすい。

### 1-7. ライセンス注意(必読)

| モデル | ライセンス | 商用利用 |
|---|---|---|
| **SDXL Base 1.0** | CreativeML Open RAIL++-M | **可**(有害コンテンツ生成等の利用制限あり、通常のフィットネスイラストには抵触しない) |
| **FLUX.1-schnell** | Apache License 2.0 | **可**(制限なし、生成物の商用利用も明示的に許可) |
| **FLUX.1-dev** | FLUX.1 [dev] Non-Commercial License | **禁止** — 本アプリのような有料サブスクアプリへの同梱は不可。**絶対に dev 版を使わないこと**。ComfyUI のモデルファイル名に `dev` が入っていないか毎回確認する |
| ControlNet モデル(Depth / OpenPose, diffusers 配布) | 概ね OpenRAIL 系 | 可。導入前に配布元の LICENSE ファイルを確認する |

**LoRA を追加導入する場合**は個別にライセンスを確認する(`tools/sd-batch/README.md` §7 と同じ注意 — SD 本体が商用 OK でも LoRA が NG なケースが多発する)。

---

## 2. キャラクター一貫性の方針

**22 種目すべてで同一シード + 同一キャラクター記述文(§1-3 の `CHARACTER_C`)を使い、統一されたひとつの「人物」に見えるようにする。**

### なぜ Top-50 パック(`tools/sd-batch`)のキャラクターをそのまま流用しないか

`tools/sd-batch/style-guide.md` の既存キャラクターは `athletic Asian male` 固定だが、Phase C は以下の理由で別キャラクターセットを新設する:

1. Phase C は **ストレッチ・自重系が多く(ハッピーベイビー、4の字ストレッチ等)、性別を問わず使えるフォーム説明であるべき** — 性別ニュートラルな見た目にすることで、特定の性別像を押し付けない
2. Top-50 パックと Phase C パックは **同じ種目で同時表示されることがない**(1 種目1 枚が基本方針、`docs/form-guide-improvement-plan.md` の「2 フレーム種目」拡張時のみ同一種目内で 2 枚出る)ため、パック間でキャラクターが違っても UI 上の矛盾は生じない
3. Phase C は「実写と区別できるイラスト」であることが要件であり(下記)、Top-50 パックの `isometric illustration` テイストよりもさらに図解寄り・柔らかい陰影に振る必要がある

### キャラクター記述文(固定・変更禁止)

§1-3 の `CHARACTER_C` ブロックをそのまま使う。ポイント:

- **性別ニュートラル**: `gender-neutral`, `age-neutral build`, `no gender-signaling props` を明記し、体型もヒョロ型/マッチョ型どちらにも寄せない
- **ジム服**: 上下とも単色(heather-gray トップス + dark-gray ショーツ)で固定。柄・ロゴ・タンクトップ以外のバリエーションを許さない
- **単色背景**: `flat mid-gray` で固定。写真パックの `pure-white` とも意図的に差別化する(実写との混同防止に加え、Phase C パックだと一目でわかるようにするため)

### スタイル面での「実写との区別」

- `photo`, `photograph`, `photorealistic`, `DSLR`, `film grain`, `skin pores` をネガティブプロンプトに必ず含める(§1-3 済み)
- `flat-shading` + `soft ambient shadow` を明示し、SDXL / FLUX がデフォルトで寄りがちな写実表現を抑える
- 生成後のレビューで「一見して AI 図解だとわかるか」を検品項目に加える(§4)

### シード運用ルール

- 全 22 種目で同じベースシード(例 `4200`)を使う。`tools/sd-batch/style-guide.md` §7 と同じ理由 — イラスト調 + キャラ固定 + 同シードの三重固定で「同じ人」感を最大化する
- ControlNet でポーズを外部から強制するため、Top-50 パックよりも **シードが人物の見た目に与える影響は小さい**(ポーズは ControlNet が握るため)。それでも同シード運用は継続し、破綻時のみ `+1` してリトライする

---

## 3. 22 種目の個別ポーズ仕様書

> 各項目の「関節角度の要点」は `WorkoutKit/Resources/exercises_seed.json` の `stepTextJaRaw` / `cautionsJa` を実際に読み込んで抽出したもの(要約や創作を避け、seed の記述に基づく)。
> 「注釈キュー案」は既存の `form.<slug>.annotation.<id>` 命名規則に従う。文字数上限は **ja ≤ 10 全角 / en ≤ 18 文字**(吹き出しカードの折り返し崩れを防ぐための本書独自ルール。既存 87 種目の一部はこれより長いが、新規追加分はこの上限を守ること)。
> `position` / `labelAnchor` の座標(0.0〜1.0)は **実際に生成された画像を見てから**決める(§4-2 参照)ため、本書では確定させていない。ここでは `id` / `ja` / `en` / `color` の 4 点を提案する。

### 3-1. preacher-curl(プリーチャーカール)

- **推奨カメラアングル**: 側面 90°(肘の曲げ伸ばしの軌道が最もよく見える)
- **関節角度の要点**(seed 由来): 肘の裏をプリーチャーベンチのパッドに固定 → 肩は動かさず肘だけを屈曲。トップでは力こぶを絞るように収縮、ボトムは「完全に伸ばしきる手前」で止める(`cautionsJa`: 肘を完全に伸ばしきらない)
- **器具と接点の注意**: 肘裏とパッドの接触面(浮いていると反動を使っているように見える)、EZバー/バーベルを握る両手(肩幅、指の本数)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `elbow-pad` | 肘裏をパッド固定 | Elbows on the pad | neutral |
| `grip-width` | 肩幅で握る | Grip at shoulder | info |
| `full-extend` | 伸ばしきらない | No full lockout | warning |
| `squeeze-top` | 二頭筋を絞る | Squeeze at the top | primary |

### 3-2. skull-crusher(スカルクラッシャー)

- **推奨カメラアングル**: 側面 90°
- **関節角度の要点**: 仰向けでバーを胸の上に構え、肘だけを曲げて額の上方までゆっくり(2秒)下ろす。肘の位置(前後)は動かさない(`cautionsJa`: 額にバーをぶつけない)
- **器具と接点の注意**: バーを握る両手の位置(顔の真上に来ないよう、額のやや上方向)、頭とバーの距離感(近すぎ/遠すぎに破綻しやすい)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `elbow-fixed` | 肘の位置を固定 | Keep elbows still | neutral |
| `stop-above-brow` | 額の上方で止める | Stop above brow | warning |
| `press-tricep` | 三頭筋で押し戻す | Press with triceps | primary |
| `slow-lower` | 2秒かけて下ろす | Lower over 2 sec | info |

### 3-3. face-pull(フェイスプル)

- **推奨カメラアングル**: 斜め45°(引き手とロープの角度が両方見える)
- **関節角度の要点**: ケーブルを目線の高さに設定、肘を高く保ったまま顔の高さまで引きつける。肩甲骨を寄せて一瞬止める(`cautionsJa`: 肘を高く保つ / 首を前に出さない)
- **器具と接点の注意**: ロープの2グリップを握る両手(左右対称に握れているか)、ケーブルのラインが不自然に曲がっていないか
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `elbow-high` | 肘を高く保つ | Keep elbows high | primary |
| `pull-to-face` | 顔の高さまで引く | Pull to face level | info |
| `squeeze-blade` | 肩甲骨を寄せる | Squeeze blades in | neutral |
| `no-forward-neck` | 首を前に出さない | Keep neck neutral | warning |

### 3-4. t-bar-row(Tバーロー)

- **推奨カメラアングル**: 側面 90°
- **関節角度の要点**: 膝を軽く曲げ上体を前傾、Vハンドルをみぞおち付近に引きつける。背中の中央が縮む感覚(`cautionsJa`: 腰の反動で引かない / 背中を丸めない)
- **器具と接点の注意**: Vハンドルを握る両手、バー先端とプレート/床の接地点(浮遊しやすい)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `hinge-torso` | 上体を前傾させる | Hinge forward | neutral |
| `pull-to-torso` | みぞおちへ引く | Pull to your torso | primary |
| `no-back-swing` | 腰の反動を使わない | No low-back swing | warning |
| `squeeze-back` | 背中の収縮を意識 | Squeeze your back | info |

### 3-5. arnold-press(アーノルドプレス)

- **推奨カメラアングル**: 正面〜斜め45°(手首の回転軌道を見せる)
- **関節角度の要点**: 掌を自分側に向けて胸の前からスタート → 押し上げながら手首を回転させ、頭上で掌が前を向く。肘を伸ばし切る手前で止める(`cautionsJa`: 回転はゆっくり / 肩をすくめない)
- **器具と接点の注意**: ダンベルを握る両手(回転中の手首の向き)、肘の軌道が左右対称か
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `rotate-slow` | 回転はゆっくりと | Rotate slowly | primary |
| `palm-start-in` | 掌を自分に向け開始 | Palms face you | info |
| `no-shrug` | 肩をすくめない | No shoulder shrug | warning |
| `stop-before-lockout` | 伸ばし切らない | Avoid full lockout | neutral |

### 3-6. reverse-crunch(リバースクランチ)

- **推奨カメラアングル**: 側面 90°
- **関節角度の要点**: 仰向けで膝を90度に曲げ、膝を胸に引き寄せながら骨盤を床から持ち上げる。お腹の下側が丸まる感覚(`cautionsJa`: 反動を使わない）
- **器具と接点の注意**: 自重のみ。マットとの接地(肩甲骨は床につけたまま)が不自然に浮いていないか
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `lift-pelvis` | 骨盤を引き上げる | Lift your pelvis | primary |
| `knees-90` | 膝を90度に曲げる | Bend knees to 90° | info |
| `no-momentum` | 反動を使わない | Don't use momentum | warning |
| `curl-lower-abs` | 下腹部を丸める | Curl lower abs | neutral |

### 3-7. hollow-body-hold(ホロウボディホールド)

- **推奨カメラアングル**: 側面 90°
- **関節角度の要点**: 仰向けで腰を床にしっかり押しつけ、両肩と両脚を浮かせる。お腹全体が硬くなる感覚(`cautionsJa`: 腰が床から離れない範囲でキープ）
- **器具と接点の注意**: 自重のみ。肩と脚が浮いている高さの左右対称性、腰が浮いて見えないか
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `press-low-back` | 腰を床に押す | Press back down | primary |
| `lift-limbs` | 肩と脚を浮かせる | Lift arms & legs | neutral |
| `breathe-steady` | 呼吸を止めない | Breathe steadily | info |
| `hold-10s` | まず10秒キープ | Hold ten seconds | neutral |

### 3-8. inverted-row(インバーテッドロー)

- **推奨カメラアングル**: 側面 90°
- **関節角度の要点**: 低く固定したバーの下に仰向けで入り、肩幅より広く握る。踵を床につけ体を一直線にし、胸をバーに引き寄せる(`cautionsJa`: お尻を落とさず一直線 / 首を前に突き出さない）
- **器具と接点の注意**: バーを握る両手、体とバーの距離(浮いて見えないよう)、踵と床の接地
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `straight-body` | 体を一直線に | Keep a rigid body | neutral |
| `pull-chest` | 胸をバーに引く | Pull chest to bar | primary |
| `no-hip-sag` | お尻を落とさない | Don't let hips sag | warning |
| `heels-down` | かかとを床につける | Plant your heels | info |

### 3-9. thread-the-needle(スレッドザニードル)

- **推奨カメラアングル**: 斜め45°(後方寄り。腕を通す動作と肩が下がる動作の両方が見える角度)
- **関節角度の要点**: 四つん這いから片腕を反対の腋の下に通し、肩を床に近づける(`cautionsJa`: 腰だけで無理に捻らない / 首を強く圧迫しない）
- **器具と接点の注意**: 自重のみ。四つん這いの支持手と床の接地点、通した腕が体幹を貫通していないか
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `all-fours` | 四つん這いになる | Start on all fours | info |
| `thread-arm` | 腕を脇の下に通す | Thread arm under | primary |
| `shoulder-down` | 肩を床に近づける | Lower the shoulder | neutral |
| `no-neck-crush` | 首を圧迫しない | Protect your neck | warning |

### 3-10. runners-stretch(ランナーズストレッチ)

- **推奨カメラアングル**: 側面 90°
- **関節角度の要点**: 前足の踵を床につけ、後ろ脚の膝を曲げて体を沈める。前膝は伸ばしきらず軽く緩める(`cautionsJa`: 前膝を伸ばしきらない）
- **器具と接点の注意**: 自重のみ。前足踵と床の接地、後ろ膝と床の距離感
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `front-heel-down` | 前足の踵をつける | Front heel down | info |
| `sit-back` | 体を後ろに沈める | Sink hips back | primary |
| `flat-back` | 背中をまっすぐ保つ | Keep a flat back | neutral |
| `soft-knee` | 前膝は軽く緩める | Soften front knee | warning |

### 3-11. bulgarian-split-squat(ブルガリアンスプリットスクワット)

- **推奨カメラアングル**: 側面90°をメイン、膝の内側崩れ確認用に正面/45°の予備カットも検討
- **関節角度の要点**: 後ろ足の甲をベンチに乗せ、前脚を1歩分前に出す。前膝がつま先と同じ方向を向くよう真下へ沈み、後ろ膝が床につく直前で止める(`cautionsJa`: 前膝が内側に入らない / 上体を前に倒しすぎない）
- **器具と接点の注意**: 後ろ足の甲とベンチの接触点(貫通しやすい最重要ポイント)、ダンベルを握る両手
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `foot-on-bench` | 後ろ足をベンチへ | Foot up on bench | info |
| `knee-track` | 前膝はつま先方向に | Knee over toes | primary |
| `keep-torso-tall` | 上体を倒しすぎない | Keep torso tall | warning |
| `drive-heel` | 前足かかとで押す | Push through heel | neutral |

### 3-12. barbell-hip-thrust(バーベルヒップスラスト)

- **推奨カメラアングル**: 側面90°
- **関節角度の要点**: 肩甲骨の下あたりをベンチに乗せ、バーを腰の付け根にセット。足は膝が90度になる位置に置き、踵で床を押して股関節を伸ばす(`cautionsJa`: 腰を反らせて高さを出さない）
- **器具と接点の注意**: バーが腰の付け根に乗る接触点(貫通/浮遊しやすい最重要ポイント。パッド付きバーであることを明示すると破綻しにくい)、肩甲骨とベンチの接触
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `bench-shoulder` | 肩甲骨をベンチに | Back on the bench | neutral |
| `knee-90` | 膝は90度の位置 | Knees bent to 90° | info |
| `drive-heels` | 踵で床を押す | Push with heels | primary |
| `no-back-arch` | 腰を反らせない | Don't overarch | warning |

### 3-13. lying-leg-curl(ライイングレッグカール)

- **推奨カメラアングル**: 側面90°
- **関節角度の要点**: うつ伏せでパッドを踵のすぐ上に合わせ、骨盤をベンチに軽く押しつけて固定。膝を曲げてパッドを引きつけ頂点で1秒キープ(`cautionsJa`: 腰を浮かさずベンチに密着）
- **器具と接点の注意**: パッドと踵の接触点、うつ伏せの体とベンチの接地(腰が浮いて見えないか)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `pad-above-heel` | パッドは踵の上に | Pad above heels | info |
| `pelvis-down` | 骨盤をベンチに押す | Press pelvis down | neutral |
| `hold-top` | 頂点で1秒キープ | Hold for 1 second | primary |
| `control-tempo` | 反動を使わない | Control the tempo | warning |

### 3-14. wrist-flexor-stretch(リストフレクサーストレッチ)

- **推奨カメラアングル**: 側面90°
- **関節角度の要点**: 片腕を前に伸ばし掌を上に向け、もう片方の手で指をゆっくり手前に引く(`cautionsJa`: 痛みを感じるところまで無理に伸ばさない / 肘を曲げずまっすぐ伸ばす）
- **器具と接点の注意**: 自重のみ。引く手と指の接触(指の本数が破綻しやすい)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `arm-extended` | 腕をまっすぐ伸ばす | Extend arm fully | neutral |
| `pull-fingers-back` | 指を手前に引く | Pull fingers back | primary |
| `breathe-natural` | 自然に呼吸を続ける | Breathe naturally | info |
| `no-overstretch` | 痛みまで伸ばさない | Stop before pain | warning |

### 3-15. v-up(Vアップ)

- **推奨カメラアングル**: 側面90°
- **関節角度の要点**: 仰向けで腕を頭上、脚をまっすぐ伸ばしてスタート。腕と脚を同時に持ち上げてV字を作り、つま先に手を近づける(`cautionsJa`: 反動を使わない）
- **器具と接点の注意**: 自重のみ。手と足が近づく距離感(近すぎ/届いていない、の破綻に注意)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `lift-both` | 腕と脚を同時に上げる | Lift arms & legs | primary |
| `form-v-shape` | V字を作るように | Make a V shape | neutral |
| `stay-controlled` | 反動をつけない | Stay controlled | warning |
| `straight-legs` | 膝を曲げない | Keep legs straight | info |

### 3-16. dead-bug(デッドバグ)

- **推奨カメラアングル**: 側面90°
- **関節角度の要点**: 仰向けで股関節と膝を90度に曲げ両腕を天井へ。腰を床に軽く押しつけたまま右腕と左脚を床近くまで伸ばす(左右交互)(`cautionsJa`: 腰が床から浮かない範囲で）
- **器具と接点の注意**: 自重のみ。伸ばした腕と脚の左右対称性、腰と床の接地
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `flat-low-back` | 腰を床に押す | Flat low back | primary |
| `arm-leg-extend` | 逆の腕と脚を伸ばす | Arm & leg extend | neutral |
| `keep-breathing` | 呼吸を止めない | Keep breathing | info |
| `no-back-arching` | 腰を反らせない | No back arching | warning |

### 3-17. diamond-push-up(ダイヤモンドプッシュアップ)

- **推奨カメラアングル**: 斜め45°(頭上寄り。ひし形に組んだ手の形が見える角度)
- **関節角度の要点**: 両手の親指と人差し指でひし形を作り胸の下あたりに置く。体を一直線に保ち胸をひし形の上に近づける(`cautionsJa`: 肘を外に開かない / 腰を反らせない）
- **器具と接点の注意**: 両手のひし形接触(親指と人差し指の形が破綻しやすい最重要ポイント)、床との接地
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `diamond-hands` | 手でひし形を作る | Form a diamond | info |
| `tuck-elbows` | 肘を外に開かない | Tuck elbows in | warning |
| `rigid-body` | 体を一直線に保つ | Body stays rigid | neutral |
| `chest-near-hands` | 胸をひし形へ近づける | Chest near hands | primary |

### 3-18. figure-four-stretch(4の字ストレッチ)

- **推奨カメラアングル**: 側面90°(足首の交差が分かる角度に体をわずかに傾ける)
- **関節角度の要点**: 仰向けで両膝を立て、片方の足首を反対の太ももに乗せて4の字を作る。下側の太もも裏を両手で抱え胸へ引き寄せる(`cautionsJa`: 首をすくめず腰は床に）
- **器具と接点の注意**: 自重のみ。足首と反対の太ももの接触点、両手で太もも裏を抱える接触(指の貫通に注意)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `ankle-over-thigh` | 足首を腿に乗せる | Ankle over thigh | info |
| `pull-to-chest` | 太もも裏を胸に引く | Pull leg to chest | primary |
| `back-on-floor` | 腰は床につけたまま | Back stays down | neutral |
| `relax-shoulders` | 肩をすくめない | Relax shoulders | warning |

### 3-19. happy-baby-pose(ハッピーベイビー)

- **推奨カメラアングル**: 側面90°(脚組みが見える角度に体をわずかに傾ける)
- **関節角度の要点**: 仰向けで両膝を胸に引き寄せ、両足の外側を手でつかむ。膝を脇に近づける(`cautionsJa`: 肩を床から浮かせない / 首をすくめない）
- **器具と接点の注意**: 自重のみ。両手で足の外側をつかむ接触点(指の貫通に注意)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `grab-outer-feet` | 足の外側をつかむ | Grab outer feet | primary |
| `knees-to-armpits` | 膝を脇に近づける | Knees to armpits | neutral |
| `shoulders-down` | 肩は床につけたまま | Shoulders down | warning |
| `relax-neck` | 首をすくめない | Relax your neck | info |

### 3-20. superman(スーパーマン)

- **推奨カメラアングル**: 側面90°
- **関節角度の要点**: うつ伏せで両手両脚をまっすぐ伸ばし、手脚を同時にゆっくり持ち上げて1秒キープ(`cautionsJa`: 反動を使わずゆっくり動かす）
- **器具と接点の注意**: 自重のみ。持ち上げた手脚の高さの左右対称性
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `lift-limbs-together` | 手脚を同時に上げる | Lift arms & legs | primary |
| `hold-1s` | 1秒キープする | Hold for 1 second | info |
| `neck-neutral` | 首を反らしすぎない | Keep neck neutral | warning |
| `move-controlled` | ゆっくり動かす | Move with control | neutral |

### 3-21. dumbbell-shrug(ダンベルシュラッグ)

- **推奨カメラアングル**: 正面(両肩の高さの左右対称性を見せる)
- **関節角度の要点**: 両手にダンベルを持ち腕を体の横に伸ばして直立。肩を耳に近づけるように真上へすくめ、1秒キープ(`cautionsJa`: 肩を回さず真上に持ち上げる動きだけ / 首を一緒に動かさない）
- **器具と接点の注意**: ダンベルを握る両手、肩の高さの左右対称性(片側だけ上がっていないか)
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `arms-hang-loose` | 腕は伸ばしたまま | Arms hang loose | info |
| `shrug-straight-up` | 肩を耳に近づける | Shrug straight up | primary |
| `no-shoulder-roll` | 肩を回さない | Up and down only | warning |
| `pause-at-top` | 頂点で1秒キープ | Pause at the top | neutral |

### 3-22. stair-climber(ステアクライマー)

- **推奨カメラアングル**: 側面90°(踏み込み動作が見える角度)
- **関節角度の要点**: ハンドルに軽く手を添え、姿勢をまっすぐ保つ。足全体でステップを踏み込み体重を乗せる(`cautionsJa`: ハンドルにもたれ過ぎない / 前傾しすぎない）
- **器具と接点の注意**: ハンドルに添える手(体重を預けすぎていないか)、足裏とステップの接地点
- **注釈キュー案**:

| id | ja | en | color |
|---|---|---|---|
| `stay-upright` | 姿勢をまっすぐ保つ | Stay upright | primary |
| `full-foot-step` | 足全体で踏み込む | Full foot on step | info |
| `dont-lean-on-rail` | ハンドルに頼らない | Don't lean on it | warning |
| `steady-pace` | 無理のないペースで | Keep steady pace | neutral |

---

## 4. 検品チェックリスト & photo-wave 統合手順

### 4-1. 検品チェックリスト(生成画像 1 枚ごとに実施)

- [ ] **指の本数**: 両手とも5本(6本以上/欠損/癒着がないか拡大確認)
- [ ] **器具の貫通**: バー・ベンチ・パッド・ハンドル等に体がめり込んでいないか、逆に不自然に浮いていないか
- [ ] **関節の逆曲がり**: 肘・膝が生理的に不可能な方向に曲がっていないか(§3 の「関節角度の要点」と矛盾していないか)
- [ ] **左右対称性**: 自重種目(dead-bug, superman, v-up 等)で左右の手脚の長さ・高さが不自然に違わないか
- [ ] **キャラクター一貫性**: §2 の `CHARACTER_C` 通りか(服装の色/柄が他種目とズレていないか)
- [ ] **実写との区別**: 一見して「AI 図解」だとわかるか(写実に寄りすぎていないか)
- [ ] **背景**: 単色フラットで、余計な小物・テキスト・ロゴが映り込んでいないか

### 4-2. photo-wave 形式への落とし込み

各種目につき `photo.jpg` + `annotations.json` + `meta.json` の3点セットを作る(既存の写真パイプラインと同じ最終形にする)。

**Step 1: JPEG を用意**
```bash
mkdir -p /tmp/phase-c-staging/<slug>
sips -s format jpeg -Z 1200 "<slug>-raw.png" --out /tmp/phase-c-staging/<slug>/photo.jpg
```

**Step 2: 画像を開いて実座標を決める**

Preview.app 等で `photo.jpg` を開き、§3 で提案した各注釈キューの `id` について、実際に体のどこを指すかを目視で決め、正規化座標(0.0〜1.0, 原点は左上)を割り出す。`position` はドット位置(体の該当部位)、`labelAnchor` は吹き出しカードを置く位置(既存 JSON と同様、写真の空いた領域=四隅寄りに置く)。

**Step 3: `annotations.json` を作成**(既存スキーマ、`WorkoutKit/Resources/FormAnnotations/<slug>-annotations.json` と同一形式)

```json
{
  "slug": "preacher-curl",
  "frames": [
    {
      "id": "start",
      "phaseLabelKey": "form.phase.start",
      "assetName": "preacher-curl-1",
      "aspect": 0.75,
      "annotations": [
        {
          "id": "elbow-pad",
          "position": { "x": 0.40, "y": 0.55 },
          "labelAnchor": { "x": 0.12, "y": 0.75 },
          "labelKey": "form.preacher-curl.annotation.elbow-pad",
          "color": "neutral"
        },
        {
          "id": "grip-width",
          "position": { "x": 0.52, "y": 0.30 },
          "labelAnchor": { "x": 0.85, "y": 0.12 },
          "labelKey": "form.preacher-curl.annotation.grip-width",
          "color": "info"
        }
      ]
    }
  ]
}
```

`color` は既存 `FormPhotoAnnotationColor` の4値(`primary` / `info` / `warning` / `neutral`)のみ使用可(`WorkoutKit/Features/Library/AnnotatedFormView.swift` 参照)。`aspect` は実際に書き出した JPEG の幅÷高さ。

**Step 4: `Localizable.xcstrings` にキーを追加**

§3 の各テーブルの `id` から `labelKey = form.<slug>.annotation.<id>` を組み立て、`ja` / `en` の文言を登録する(Xcode の String Catalog エディタで追加するのが確実。手動で JSON を触る場合は既存エントリの構造をコピーする)。

**Step 5: `meta.json` を作成**(このステージング専用。Pexels 由来と区別するための記録)

```json
{
  "slug": "preacher-curl",
  "assetName": "preacher-curl-1",
  "pexelsId": 0,
  "photographer": "AI-generated (SDXL)",
  "generationModel": "SDXL Base 1.0 + Depth ControlNet",
  "controlnetStrength": 0.85,
  "seed": 4200,
  "generatedDate": "2026-07-16",
  "reviewedBy": "Tomo"
}
```

> `generationModel` / `photographer` は実際に使用したモデルに合わせて書き換える(例: FLUX.1-schnell を使った場合は `"AI-generated (FLUX.1-schnell)"`)。**FLUX.1-dev は使用禁止のため photographer 欄に登場してはならない**(§1-7)。

**Step 6: Asset Catalog へ統合**

Pexels 由来アセットと同じ「1 スケールのみ・`universal` idiom」形式で配置する(`tools/sd-batch/integrate.py` は Top-50 パック専用の PNG 3スケール形式なので Phase C にはそのまま使わない。以下は手動コピー手順):

```bash
SLUG=preacher-curl
DEST="WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/${SLUG}-1.imageset"
mkdir -p "$DEST"
cp "/tmp/phase-c-staging/${SLUG}/photo.jpg" "${DEST}/${SLUG}-1.jpeg"
cat > "${DEST}/Contents.json" <<'EOF'
{
  "images" : [
    {
      "filename" : "preacher-curl-1.jpeg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
cp "/tmp/phase-c-staging/${SLUG}/annotations.json" \
   "WorkoutKit/Resources/FormAnnotations/${SLUG}-annotations.json"
```

**Step 7: 検査ツールを通す**

```bash
python3 tools/check_form_annotations.py preacher-curl
```

`OK: 重なり・見切れなし` が出るまで `position` / `labelAnchor` を調整する。0件になるまでは統合完了と見なさない(既存 Phase A/B と同じ品質ゲート — `docs/form-guide-improvement-plan.md` の「検査ツール0違反維持」を継承)。

**Step 8: `THIRD_PARTY_NOTICES.md` に AI 生成の旨を追記**

`THIRD_PARTY_NOTICES.md` に新しいセクションを追加する(既存の「Pexels — Exercise Demonstration Photos」セクションとは別立てにする。これは実写でないことを明示するため):

```markdown
## AI-Generated Illustrations (Phase C) — SDXL / FLUX.1-schnell

- **Source**: Locally generated via ComfyUI on Apple Silicon (this repository's `docs/phase-c-generation-kit.md` pipeline).
- **Models used**: Stable Diffusion XL Base 1.0 (CreativeML Open RAIL++-M, commercial use permitted) and/or FLUX.1-schnell (Apache License 2.0, commercial use permitted). **FLUX.1-dev was NOT used** (its non-commercial license would prohibit inclusion in this paid app).
- **Pose reference**: 3D poses authored in PoseMy.Art (free, browser-based), converted to OpenPose/Depth control maps, applied via ControlNet (Depth, strength 0.8–0.9) to lock joint angles to the real exercise form described in `WorkoutKit/Resources/exercises_seed.json`.
- **Used for**: N exercise demonstration illustrations bundled under `WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/<slug>-1.imageset/`, displayed the same way as the Pexels photo set (see `WorkoutKit/Resources/FormAnnotations/<slug>-annotations.json`).
- **Attribution**: Not a photograph of a real person; no photographer credit applies. Per-exercise generation metadata (model, ControlNet strength, seed) is tracked in this repo's Phase C staging `meta.json` files (not shipped in the app bundle).

| Asset | Model | Seed | Notes |
| --- | --- | --- | --- |
| `preacher-curl-1` | SDXL Base 1.0 + Depth ControlNet | 4200 | — |
```

種目を1つ統合するたびに表の行を1行追加する。`N exercise demonstration illustrations` の `N` も都度更新する。

---

## 5. 品質ゲート

### 5-1. 最初の3種目で合否判定

**対象**: `preacher-curl`, `skull-crusher`, `bulgarian-split-squat`(単関節・複合関節・ベンチ接触ありの3タイプを横断してカバーするために選定)。

1. §1〜§4 のフルパイプラインをこの3種目だけ通しで実行する(ポーズ作成 → ControlNet 生成 → 検品 → photo-wave 統合 → `check_form_annotations.py` グリーン → `THIRD_PARTY_NOTICES.md` 追記)。
2. §4-1 の検品チェックリスト7項目を3種目 × 7項目 = 21項目で採点する。

**合格基準**(残り19種目の量産に進めるかどうかの判断):

- 21項目中 **18項目以上(85%以上)** がチェック済みであること
- 3種目とも「実写との区別」項目(一見してAI図解とわかる)が✅であること(これが✗だと量産しても実写パックと混同するリスクがあるため、他項目が満点でも量産不可と判断する)
- `check_form_annotations.py` が3種目とも `OK` を返すこと(座標配置の技術的失敗は別問題であり必ずクリアできるはずなので、これが✗なら再検品)

### 5-2. NG 時のフォールバック — 有償ストックへの切り替え

上記合格基準を満たさない場合(スタイル崩壊・破綻多発・ControlNet でも直らない等)、**残り19種目分は量産せず**、その種目だけ以下の手順で有償ストック写真に切り替える:

1. **購入元**: iStock または Adobe Stock(Pexels に候補がなかった種目のため、有償ストックで再探索する)
2. **検索クエリ**: 種目の英語名 + `form` / `exercise demonstration` / `gym` で検索。人物が特定できる写真は **モデルリリース付きの Royalty-Free ライセンス**であることを確認する(Editorial ライセンスは商用アプリ同梱に使えないため除外)
3. **枚数と予算**: 1種目につき2枚(スタート/ボトム相当、取れない場合は1枚)、目安 **¥3,000〜6,000/種目**
4. **ライセンス確認**: iStock の Standard License / Adobe Stock の Standard License が「モバイルアプリへの組み込み・再配布」を許可する範囲か、購入前に規約を確認する(Pexels ライセンスと違い、無条件の再配布不可の場合があるため注意)
5. **統合**: 通常の Pexels 由来アセットと同じ手順で `photo.jpg` / `annotations.json` / `meta.json` を作る。`meta.json` の `pexelsId` は該当ストックの ID(iStock なら `istockId` フィールドを追加)、`photographer` は実際の撮影者名を記載する(AI生成ではないため `"AI-generated (SDXL)"` は使わない)
6. **`THIRD_PARTY_NOTICES.md`**: 既存の「Pexels — Exercise Demonstration Photos」とは別に「iStock — Exercise Demonstration Photos」セクションを新設し、ライセンス条項を明記した上で写真を追加する

### 5-3. 量産フェーズ

3種目が合格基準を満たした場合、残り19種目を同一パイプラインで生成する。§2 のキャラクター一貫性(同一シード・同一キャラ記述文)を19種目全てで維持し、§4 の photo-wave 統合 + 検査ツールを種目ごとに必ず通す。全22種目が揃った時点で `docs/form-guide-improvement-plan.md` のPhase Cゴール(写真カバレッジ65%+、2フレーム種目40+ の一部として)の進捗を更新する。

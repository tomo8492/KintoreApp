# Stable Diffusion バッチ生成ツール

WorkoutKit の **上位 50 種目** のフォーム解説イラストを Mac (Apple Silicon) ローカルで一括生成するためのツール群。

- 費用 **¥0**(オープンソース + 無料アプリのみ使用、サブスクなし)
- セットアップ目標 **30 分以内**
- 生成時間目安 **8〜15 分**(M2/M3 で 50 枚)

> **方針**: CLAUDE.md §-1 確定で「動画は同梱しない、ステップイラストのみ」。本ツールはその「ステップイラスト」(代表 1 枚 / 種目)を生成する。

---

## 1. 推奨環境

| 項目 | 必須 / 推奨 |
|---|---|
| OS | macOS 14 Sonoma 以降(15 Sequoia 以降推奨) |
| チップ | Apple Silicon(M1 / M2 / M3 / M4)。Intel Mac は非推奨 |
| メモリ | 16 GB 以上(8 GB は SDXL では厳しい。SD 1.5 にダウングレードを検討) |
| 空きディスク | 20 GB(SDXL Base + Refiner + LoRA + 出力) |
| Python | 3.10+(`integrate.py` で必要。生成自体は不要) |

生成時間の参考:

| チップ | SDXL 1024×1024 1 枚 | 50 枚 合計 |
|---|---|---|
| M1 8GB | 25〜40 秒 | 約 25 分 |
| M2 16GB | 10〜15 秒 | 約 10 分 |
| M3 Pro 18GB | 6〜10 秒 | 約 7 分 |
| M4 Max | 3〜5 秒 | 約 4 分 |

---

## 2. 推奨スタック: Draw Things(無料 / App Store)

**Draw Things** が現状の最有力候補。理由:

- App Store 配布 = 完全無料 / 公証済み / アンチウイルス警告なし
- Apple Silicon 専用最適化(Core ML / Metal)で他より高速
- **ローカル HTTP API**(`/sdapi/v1/txt2img` を実装、A1111 風の JSON 入出力)を内蔵 → スクリプトから直叩き可能
- モデル/ LoRA / ControlNet を GUI で導入可能
- 生成画像のメタデータに seed と prompt が自動埋め込み

### 2.1 インストール

1. App Store で「Draw Things」を検索 → インストール(無料、約 200 MB)
2. 起動後、初回はモデル未インストール状態。`Settings ▸ Models` から下記を DL:
   - **SDXL Base 1.0**(約 6.5 GB)— 既定の高品質ベース
   - **SDXL Refiner 1.0**(約 6.0 GB)— 任意、最終品質 +5%
3. 推奨 LoRA(イラストスタイル統一用):
   - 「Isometric Future」または「Flat Illustration XL」(検索 → DL)
   - ※ ライセンスは商用 OK のものを必ず選ぶ(Creative ML OpenRAIL-M / Apache-2.0 など)
4. 左サイドバー **Advanced ▸ API Server** を開いて **API Server を有効化**
   - Protocol: `HTTP` / Port: `7860` / IP: `localhost` のまま(セキュリティ上重要)
   - 旧バージョンでは `Settings ▸ Server` だが現行は Advanced タブ配下

### 2.2 動作確認

Draw Things のメイン画面で以下を生成 → 数秒〜数十秒でプレビューが出れば成功:

```
Prompt:  isometric illustration of a cube on a white background
Steps:   25
Sampler: DPM++ 2M Karras
CFG:     7.0
Size:    1024x1024
Seed:    42
```

### 2.3 API 動作確認

Draw Things の API は **A1111 完全互換ではない**。`/sdapi/v1/sd-models` などは
未実装(404)で、現行設定の取得は `/` か `/sdapi/v1/options` を使う:

```bash
# 起動確認: 現在のモデル名・解像度などが JSON で返れば OK
curl -s http://127.0.0.1:7860/sdapi/v1/options | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('model=',d.get('model'),'size=',d.get('width'),'x',d.get('height'))"

# 生成確認: 1024×1024 / 28 steps で 1〜4 分かかる(M2 16GB の実測 251s)
curl -s -m 600 -X POST http://127.0.0.1:7860/sdapi/v1/txt2img \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"isometric cube","steps":4,"width":256,"height":256,"seed":1}' \
  -o /tmp/dt.json && python3 -c \
  "import json,base64; d=json.load(open('/tmp/dt.json')); open('/tmp/dt.png','wb').write(base64.b64decode(d['images'][0]))"
```

txt2img の payload は A1111 風(`prompt` / `negative_prompt` / `sampler_name` /
`steps` / `cfg_scale` / `width` / `height` / `seed`)。`sampler_name` に無効値
を渡すと 422 と一緒に有効値の一覧が返る。

---

## 3. 代替スタック(Draw Things が合わない場合のみ)

| 候補 | 利点 | 欠点 |
|---|---|---|
| **DiffusionBee** | App Store 不経由、完全 GUI | API なし → スクリプト連携不可、本ツールでは使えない |
| **Mochi Diffusion** | OSS、Core ML 最適化 | API なし、UI から 1 枚ずつ生成 |
| **Hugging Face Diffusers (Python)** | 最も柔軟、CI 対応可 | `torch + accelerate + diffusers` セットアップが重い、初回 DL も別途必要 |
| **Automatic1111 / ComfyUI** | エコシステム最大 | Apple Silicon 最適化が後追い、Draw Things より遅いことが多い |

### 3.1 Diffusers (Python) で代替する場合

`generate.py` は **Draw Things API** をデフォルトに、`--backend diffusers` で Diffusers にも切替可能。Diffusers を使う場合のみ追加で:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install --upgrade pip
pip install "diffusers[torch]" transformers accelerate safetensors pillow
# 初回モデル DL(約 7 GB、HuggingFace アカウント不要)
python -c "from diffusers import StableDiffusionXLPipeline; \
StableDiffusionXLPipeline.from_pretrained('stabilityai/stable-diffusion-xl-base-1.0')"
```

`mps`(Metal)で動作。M1 8GB だと OOM することがあるので、その場合は SD 1.5(`runwayml/stable-diffusion-v1-5`)にフォールバック。

---

## 4. 使い方(ターンキー手順)

```bash
cd <repo-root>/tools/sd-batch

# 1) 設定(任意。既定で動く)
export SD_API_URL="http://127.0.0.1:7860"   # Draw Things が listen している URL
export SD_OUTPUT_DIR="./output"             # 生成画像の保存先(既定: ./output)
export SD_SEED_BASE=42                      # 全種目の seed のベース値

# 2) Draw Things を起動 → API 有効化を確認

# 3) 生成バッチを実行
python3 generate.py
# → ./output/<slug>.png が 50 枚生成される
# → ./output/report.json に成否ログが残る

# 4) 失敗種目があったらリトライ
python3 generate.py --only-failed

# 5) Asset Catalog に統合
python3 integrate.py
# → WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/<slug>.imageset/ に配置
# → 既存ファイルがあれば差分プレビュー → y/n 確認
```

**全プロセス通しで人手操作はステップ 2(Draw Things 起動)とステップ 5 のマージ確認のみ。**

---

## 5. ファイル構成

```
tools/sd-batch/
├── README.md                # この文書
├── style-guide.md           # プロンプトテンプレートの根拠と使い分け
├── exercises_top50.json     # 生成対象 50 種目 + ポーズ情報(信頼源)
├── generate.py              # 生成バッチ本体(Draw Things API or Diffusers)
├── integrate.py             # Asset Catalog 統合スクリプト
└── output/                  # 生成画像の保存先(.gitignore 対象)
    ├── <slug>.png
    └── report.json          # 生成ログ(成否、retry 回数、所要時間)
```

---

## 6. トラブルシューティング

| 症状 | 原因 / 対処 |
|---|---|
| `connection refused` | Draw Things が起動していない / API が無効 |
| healthcheck で 404 | `/sdapi/v1/sd-models` を叩いていないか確認(Draw Things 未実装)。`generate.py` は `/sdapi/v1/options` を使用 |
| 422 + `Invalid value for sampler_name` | レスポンスの `detail` に有効サンプラー一覧がある。先頭の `DPM++ 2M Karras` が無難 |
| 生成時間が極端に遅い(M2 で 1 分超) | モデルが SD 1.5 / FP32 になっていないか確認(SDXL FP16 推奨) |
| 同一 seed なのに毎回違う絵 | サンプラーが `Karras` 系か再確認、CFG / Steps を固定 |
| 体型がバラバラ | `style-guide.md` のキャラクター設定をプロンプト先頭に固定 |
| 指が 6 本になる | `negative` に `extra fingers, mutated hands, malformed limbs` を追加(generate.py で適用済) |
| ロゴ / 文字が映り込む | `negative` に `text, watermark, logo, signature` 追加(同上) |
| CFG 上げすぎで彩度爆発 | CFG は 5.5〜7.0 に収める |
| OOM(M1 8GB) | SDXL → SD 1.5 にダウングレード、または `--backend diffusers --resolution 768` |

---

## 7. ライセンスと商用利用

- **SDXL Base 1.0**: CreativeML Open RAIL++-M(商用 OK)
- **Draw Things**: 商用利用可(App Store 標準ライセンス)
- **生成物の権利**: 米国の現行解釈では「人間の創作的寄与がない純 AI 生成物は著作権なし」。本アプリ同梱画像としては問題なく使える(改変・採用判断はあなたが行うため)。
- LoRA を導入する場合は **必ずライセンス**(Creative ML / Apache-2.0 / CC-BY 等)を確認。`SD は商用 OK でも LoRA が NG` というケースが頻出する。

`THIRD_PARTY_NOTICES.md` への追記が必要なら、採用したモデル / LoRA を **採用後に** 追記する(本ツール時点ではまだ追記しない)。

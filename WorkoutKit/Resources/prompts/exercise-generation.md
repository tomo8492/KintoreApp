# 種目データ生成プロンプト

> CLAUDE.md §-1.10 / F-02 / §4.2 準拠。
> ChatGPT 等に貼って種目データを量産し、生成された JSON を `Resources/exercises_seed.json` にマージする運用。

## 使い方

1. 下の「プロンプト本文」を ChatGPT(GPT-4 以上推奨)にコピペ
2. 「対象カテゴリ」に欲しい種目群を入れる(例: `STRENGTH × chest × barbell` を10種目)
3. 出力された JSON 配列を `Resources/exercises_seed.json` の配列内にマージ
4. アプリを起動すると `ExerciseSeeder.seedIfNeeded` が新規 slug だけ追加挿入する

## 同梱目標(v1.0 出荷条件)

| カテゴリ | 種目数 |
|---|---|
| WARMUP | 10 |
| STRENGTH (compound) | 30 |
| STRENGTH (isolation) | 50 |
| CALISTHENICS | 20 |
| STRETCHING | 30 |
| CARDIO | 10 |
| **合計** | **150以上** |

---

## プロンプト本文

```
あなたはフィットネスインストラクターであり、JSON 出力に厳格な技術ライターです。
これから WorkoutKit という iOS アプリ向けの種目データを生成します。

【出力フォーマット】
JSON 配列で出力してください。コードブロックの外には何も書かないでください。
各要素は以下のキーを持つオブジェクトです(キー順は固定、欠けは null か空文字)。

{
  "slug": "kebab-case-english-slug",          // 必須、英語、世界で一意
  "slugJa": "カタカナ表記",                    // 必須、検索補助
  "legacyCsvId": null,                         // workout-cool 由来 ID があれば数値、無ければ null
  "nameJa": "種目名(日本語)",
  "nameEn": "Exercise Name (English)",
  "descriptionJa": "<p>HTMLリッチテキスト</p>",
  "descriptionEn": "<p>HTML rich text</p>",
  "introductionJa": "短い導入文(50字程度)",
  "introductionEn": "Short intro (~80 chars)",
  "typeRaw": "STRENGTH",                       // STRENGTH / CARDIO / STRETCHING / CALISTHENICS / WARMUP / PLYOMETRICS
  "mechanicsTypeRaw": "COMPOUND",              // COMPOUND / ISOLATION、STRETCHING/WARMUP は null
  "primaryMuscleRaw": "chest",                 // 主働筋(後述の Muscle 列挙から1つ)
  "secondaryMusclesRaw": "triceps,deltoids",   // カンマ区切り、なければ空文字
  "equipmentRaw": "barbell,bench",             // カンマ区切り
  "stepImagesRaw": "[]",                       // 後でアートワーク追加、当面は "[]"
  "stepTextJaRaw": "[\"手順1\",\"手順2\",\"手順3\"]",  // JSON 文字列(配列を文字列で持つ)
  "stepTextEnRaw": "[\"Step 1\",\"Step 2\",\"Step 3\"]",
  "cautionsJa": "注意1\n注意2",                // 改行区切り
  "cautionsEn": "Caution 1\nCaution 2",
  "youtubeSearchQuery": "search query",        // YouTube アプリへのDeep Link用、英語推奨
  "thumbnailFileName": null
}

【列挙値の正書】
- typeRaw: STRENGTH / CARDIO / STRETCHING / CALISTHENICS / WARMUP / PLYOMETRICS
- mechanicsTypeRaw: COMPOUND / ISOLATION（STRETCHING・WARMUP は null）
- Muscle: chest, lats, traps, deltoids, biceps, triceps, forearms,
          abs, obliques, lowerBack,
          quadriceps, hamstrings, glutes, calves,
          fullBody
- Equipment: bodyweight, dumbbell, barbell, kettlebell, machine,
             cable, band, pullupBar, bench, trx, foamRoller, yogaMat

【書き方の基準】
- slug は世界で1つだけのIDになるので、形容詞を含め具体的に
  例: "barbell-back-squat", "dumbbell-incline-press", "cable-tricep-rope-pushdown"
- stepTextJaRaw / stepTextEnRaw は 3〜6 ステップ
- cautions は 2〜4 行
- description はマシン名・グリップ・足幅などのバリエーションに触れる
- 重量や回数の指示は書かない(Generator が決める)
- 医療助言は書かない(App Store Guideline 1.4.1)

【今回の対象】
- 対象カテゴリ: <ここを差し替え。例: STRENGTH × chest × barbell を10種目>
- 既出 slug(重複禁止): <ここに既存 slug を貼る>
```

---

## マージ手順(手作業)

ChatGPT が返す JSON 配列を、既存 `exercises_seed.json` の `[]` の中に追記する。

```bash
# Linux / macOS の例(jq があれば)
jq -s '.[0] + .[1]' WorkoutKit/Resources/exercises_seed.json /tmp/new_exercises.json \
    > /tmp/merged.json && mv /tmp/merged.json WorkoutKit/Resources/exercises_seed.json
```

slug が衝突しないかは ExerciseSeeder が起動時にスキップするので壊れない。
ただし「明らかに別種目なのに slug が被った」ケースは新しい slug にリネームすること。

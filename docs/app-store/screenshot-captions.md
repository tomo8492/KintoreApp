# Screenshot captions (ja + en)

App Store Connect supports a short caption per screenshot (App Store calls it
"app preview text"; for static screenshots the marketing copy is overlaid in
the image itself). Keep each caption to **2–4 short lines** and load the
strongest hook on the first line.

The list below pairs the screenshot slug we plan to capture (Phase P-5
screenshot batch) with the marketing caption in both locales. Order matches
the order they should appear in App Store Connect (slot 1 = hero).

---

## iPhone — 6.7" (1290 × 2796)

### 1. today-hero
- **ja**: 5秒で今日のメニュー\n目的・部位・器具を選ぶだけ
- **en**: Today's workout in 5 seconds\nPick goal, muscles, equipment

### 2. builder-result
- **ja**: ウォームアップから整って一発生成\n気分が乗らない日もShuffleで\n最適な構成へ即座に切替
- **en**: Warm-up to cool-down, planned\nShuffle when you need a change\nPicks the best split for you

### 3. session-running
- **ja**: 重量・レップ・RPEを軽快に記録\n休憩タイマー付き
- **en**: Log weight, reps, RPE in seconds\nRest timer is built in

### 4. session-rest-timer-live-activity
- **ja**: ロック画面でも休憩タイマー\nDynamic Island対応\n毎秒 push なしの省電力描画
- **en**: Rest timer on the lock screen\nDynamic Island ready\nBattery-friendly local rendering

### 5. session-summary-aicoach
- **ja**: 終了直後にAIコーチが3行で要約\n完全オンデバイス推論(iOS 26+)\nデータは端末から出ない
- **en**: AI coach summarises in 3 lines\nFully on-device (iOS 26 and later)\nNothing leaves your device

### 6. library-detail-annotated
- **ja**: 全345種目に解剖学イラスト\n前面・後面のフォームポイントを\n番号付きでひと目で
- **en**: 345 exercises, anatomy view\nNumbered form cues on front and back\nLearn lifts at a glance

### 7. library-list-search
- **ja**: タイプ × 部位 × 器具で素早く検索\n日本語・英語どちらでも
- **en**: Filter by type, muscle, equipment\nSearch in Japanese or English

### 8. history-calendar
- **ja**: カレンダーで継続を可視化\n抜けた日もひと目で
- **en**: See your streak at a glance\nGaps are obvious too

### 9. templates-presets
- **ja**: PPL・上下分割・全身\n3つのプリセットは無料
- **en**: PPL, Upper-Lower, Full-body\nThree free presets

### 10. paywall
- **ja**: 月額 ¥980 / 年額 ¥4,900\n7日間の無料トライアル付き\nファミリー共有対応・いつでも解約可
- **en**: ¥980/month or ¥4,900/year\n7-day free trial\nCancel any time, Family Sharing

---

## iPad — 12.9" (2048 × 2732 portrait)

### 1. ipad-library-split
- **ja**: iPadではサイドバー + 詳細の2画面表示
- **en**: Side-by-side library on iPad

### 2. ipad-builder-result
- **ja**: 大きい画面でメニューを一覧
- **en**: Plan reviewed at full size

### 3. ipad-session
- **ja**: 入力欄も広く、片手でも快適
- **en**: Roomy controls, single-hand friendly

---

## Apple Watch — 45mm (368 × 448)

### 1. watch-smart-stack
- **ja**: 今日のセッションをひと目で\nSmart Stack ウィジェット
- **en**: Today's session at a glance\nSmart Stack widget

> Captured by running the WorkoutKitWatch widget in the watchOS simulator
> Smart Stack preview, with a sample `TodaySessionSummary` (isCompleted=true,
> totalSets=12, exerciseCount=5) written to the App Group UserDefaults.

---

## Caption guidelines

- Avoid superlatives ("best", "world's #1") — Apple may reject.
- No medical claims. Frame benefits as self-management or learning support.
- No competitor names.
- Lead with the user benefit, not the feature name.
- Match the language tone in `description.txt` (ja: polite-but-friendly,
  en: concise and motivational).
- 1–2 emojis maximum across the whole gallery (none required).

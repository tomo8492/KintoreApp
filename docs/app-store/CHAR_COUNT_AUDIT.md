# App Store metadata character-count audit

> Generated 2026-05-18 by Mac-side agents (task `task/docs-audit-v1`).
> Method: `len(text.rstrip("\n").encode("utf-16-le")) // 2` to mirror
> Apple's NSString length (the metric ASC enforces). Unicode codepoint
> count is also shown for sanity — the two values diverge only for
> characters outside the BMP (e.g. emoji in the U+1F000 range).

## Limits per Apple

| Field            | Limit |
|------------------|-------|
| Name             | 30    |
| Subtitle         | 30    |
| Promotional text | 170   |
| Description      | 4 000 |
| Keywords         | 100   |
| What's new       | 4 000 |

## Results

| File                                       | Unicode | UTF-16 | Limit | Status       | Headroom |
|--------------------------------------------|--------:|-------:|------:|--------------|---------:|
| `docs/app-store/ja/name.txt`               | 22      | 22     | 30    | ✅ OK         | 8        |
| `docs/app-store/ja/subtitle.txt`           | 20      | 20     | 30    | ✅ OK         | 10       |
| `docs/app-store/ja/promotional-text.txt`   | 134     | 134    | 170   | ✅ OK         | 36       |
| `docs/app-store/ja/description.txt`        | 1 999   | 1 999  | 4 000 | ✅ OK         | 2 001    |
| `docs/app-store/ja/keywords.txt`           | 62      | 62     | 100   | ✅ OK         | 38       |
| `docs/app-store/ja/whats-new.txt`          | 465     | 465    | 4 000 | ✅ OK         | 3 535    |
| `docs/app-store/en/name.txt`               | 27      | 27     | 30    | ⚠ Tight      | 3        |
| `docs/app-store/en/subtitle.txt`           | 30      | 30     | 30    | ⚠ At limit   | 0        |
| `docs/app-store/en/promotional-text.txt`   | 166     | 166    | 170   | ⚠ Tight      | 4        |
| `docs/app-store/en/description.txt`        | 3 881   | 3 881  | 4 000 | ✅ OK         | 119      |
| `docs/app-store/en/keywords.txt`           | 97      | 97     | 100   | ⚠ Tight      | 3        |
| `docs/app-store/en/whats-new.txt`          | 812     | 812    | 4 000 | ✅ OK         | 3 188    |

**Outcome: zero overflows. No file edits required.**

## Notes for tomo

- The English **subtitle** is at exactly 30 — any future tweak to it must
  not add a single character. Current value: `5-second smart workout planner`.
- English **name** (27 / 30), **promotional-text** (166 / 170) and
  **keywords** (97 / 100) are within 5 characters of the cap. If a future
  edit feels safer with more headroom, the standard shorteners are:
  - name: drop "WorkoutKit – " prefix in promotional copy variants (kept
    here as full brand spelling per ASC convention)
  - promotional-text: contract "rest timer Live Activity" → "rest timer LA"
    saves 13 characters but loses discoverability — not recommended
  - keywords: drop the lowest-volume term (`abs` currently last) to free 4
- Japanese fields all have generous headroom; safe to expand if needed
  during a future content pass.

## 2026-07-17 update — name / subtitle repositioning (AI-first, form-guide differentiator)

> CLAUDE.md v1.2 ASO 改訂に合わせて `name.txt` / `subtitle.txt` (ja + en) を更新。
> **この節が name.txt / subtitle.txt に関する最新の値。上の「Results」表の
> 該当 4 行(`ja/name.txt`, `ja/subtitle.txt`, `en/name.txt`, `en/subtitle.txt`)は
> この節が発行された時点で superseded(古い値のまま残しているのは履歴参照用)。**

| File                              | New value                            | Unicode | UTF-16 | Limit | Status |
|------------------------------------|---------------------------------------|--------:|-------:|------:|--------|
| `docs/app-store/ja/name.txt`       | `WorkoutKit - AI筋トレ記録`           | 20      | 20     | 30    | ✅ OK  |
| `docs/app-store/ja/subtitle.txt`   | `フォームが分かるAI筋トレ記録`         | 15      | 15     | 30    | ✅ OK  |
| `docs/app-store/en/name.txt`       | `WorkoutKit - AI Workout Log`         | 27      | 27     | 30    | ✅ OK  |
| `docs/app-store/en/subtitle.txt`   | `Form-guided AI workout log`          | 26      | 26     | 30    | ✅ OK  |

Previous values (now retired):
- `ja/name.txt`: `WorkoutKit - シンプル筋トレ記録`
- `ja/subtitle.txt`: `目的×部位×器具で5秒生成・全345種目`
- `en/name.txt`: `WorkoutKit - Simple Tracker`
- `en/subtitle.txt`: `5-second smart workout planner`

All four new strings verified ≤ 30 chars (both Unicode codepoint count and
UTF-16 length, computed with the same method as the section below).

## Audit method (reproducible)

```bash
python3 <<'EOF'
import os
limits = {
    "name.txt": 30, "subtitle.txt": 30, "promotional-text.txt": 170,
    "description.txt": 4000, "keywords.txt": 100, "whats-new.txt": 4000,
}
for locale in ("ja", "en"):
    for fname, limit in limits.items():
        path = f"docs/app-store/{locale}/{fname}"
        with open(path, encoding="utf-8") as fh:
            data = fh.read().rstrip("\n")
        utf16_len = len(data.encode("utf-16-le")) // 2
        flag = "OK" if utf16_len <= limit else f"OVER+{utf16_len - limit}"
        print(f"{path}: {utf16_len}/{limit} {flag}")
EOF
```

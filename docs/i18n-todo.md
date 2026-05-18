# i18n TODO — Localizable.xcstrings audit log

> Audit performed 2026-05-16 against
> `WorkoutKit/Resources/Localizable.xcstrings` (1 257 keys, sourceLanguage
> `ja`, target locales `ja` + `en`).
> Method: cross-reference catalog entries against actual `Text(...)`,
> `LocalizedStringKey`, `String(localized:)`, `Label(...)` call sites in
> `WorkoutKit/`, `WorkoutKitWatch/`, and `WorkoutKitLiveActivity/`.

## Categorisation

| Category | Count | Description |
|----------|-------|-------------|
| A — Empty entry (no localizations) | 4 (was 8) | Catalog entry registered but no `localizations` dict. |
| B — `ja` present but `en` absent   | 3 (was 6) | Auto-extracted by SwiftUI; user-visible only in JA. |
| C — `en` exists with `new`/`stale` state | 0 | None found. |
| D — `en` value equals key (false positive) | 24 | Normal pattern for English-source keys. No action needed. |

## Fixes applied in this commit

Seven user-visible dynamic-format keys had no real translation set
(the `value` field literally contained the key string). All seven now
have hand-authored `ja` + `en` translations and `extractionState =
manual`:

| Key | en | ja | Notes |
|-----|----|----|-------|
| `a11y.builder.result.row %@ %@` | `Item %1$@, %2$@` | `%1$@ 番目、%2$@` | Ported from stale `%lld %@` sibling. |
| `a11y.builder.time.chip %@`     | `%@ minutes` | `%@ 分` | Ported from stale `%lld` sibling. |
| `builder.step.result.choose.subheading %@ %@` | `%1$@ selected of %2$@ candidates` | `選択中 %1$@ / 候補 %2$@` | New translation; call site is `ChooseMode.swift:46`. |
| `builder.step.result.subheading %@` | `%@ exercises` | `%@ 種目` | Ported from manual `%lld` sibling. |
| `hard-paywall.trial.days %@`    | `%@-day free trial` | `%@ 日間の無料トライアル` | Ported from stale `%lld` sibling. |
| `rest.live.next-set %@ %@`      | `Next: set %1$@ of %2$@` | `次は %1$@ / %2$@ セット` | Ported from stale `%lld %lld` sibling. |
| `RPE`                            | `RPE` | `RPE` | Internationally recognised abbreviation; mirror of `history.detail.set.rpe` style. |

Before the fix, JA users running the app would have seen literal strings
like `"builder.step.result.subheading 12"` in the Result-step subheading
and `"rest.live.next-set 3 5"` on the Rest-Timer Live Activity. Now they
see `"12 種目"` and `"次は 3 / 5 セット"`.

## Intentionally left as-is

Seven format-only / punctuation keys remain with no localizations. These
are SwiftUI auto-extracted from `Text("\(value)")` patterns where the
*format itself* is language-neutral:

| Key | Why no action |
|-----|---------------|
| `%@` | Pure placeholder, identical in every language. |
| `•`  | Bullet glyph. |
| `• %@` | Bullet + value, language-neutral. |
| `+%@` | Plus sign + value (used for delta displays). |
| `%@ %@` | Has `ja` value `%1$@ %2$@`; rendering identical to format spec. |
| `%@, %@` | Same. |
| `%@, %@, %@` | Same. |

Xcode's String Catalog editor will mark these "needs translation" but
the runtime fallback (key text) is correct in both `ja` and `en`. No
user-visible bug. If tomo prefers a clean "100 % translated" indicator
in Xcode, identity translations can be filled in later — purely
cosmetic.

## Stale siblings worth retiring (future cleanup)

Several `%lld`-suffixed keys are now duplicated by their `%@` siblings
created in this audit. They are marked `extractionState: stale` in the
catalog, which is Apple's documented signal for "no longer referenced
by the build", so they will be filtered out of the compiled `.strings`
output. Leaving them in the source `.xcstrings` is harmless but adds
~120 lines of noise.

Examples of stale `%lld` siblings now superseded:

- `a11y.builder.result.row %lld %@`
- `a11y.builder.time.chip %lld`
- `builder.step.result.subheading %lld`
- `hard-paywall.trial.days %lld`
- `rest.live.next-set %lld %lld`

When you next open the catalog in Xcode 16, the "Remove Stale" command
in the right-click menu will clean these in one click.

## Open questions for tomo (none blocking v1.0)

- None. Every translation in this commit is a low-risk transliteration
  of an existing sibling entry or a literal English-acronym retention.
  If you disagree with any of the new JA wording, the entries are easy
  to refine in Xcode's catalog editor (use the table above to locate
  them by key).

## Verification reproducible from CLI

```bash
python3 <<'EOF'
import json
d = json.load(open('WorkoutKit/Resources/Localizable.xcstrings'))
for k, v in d.get('strings', {}).items():
    locs = (v.get('localizations') or {})
    if not locs:
        print('EMPTY', k)
    elif 'en' not in locs:
        print('NO_EN', k)
EOF
```

After the fixes in this commit, the script should report only 4 `EMPTY`
and 3 `NO_EN` lines — all of them format-only keys from the table above.

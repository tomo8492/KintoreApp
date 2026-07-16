# App Store metadata — master index

> Authored 2026-05-07 for **WorkoutKit v1.0** App Store Connect submission.
> Source-of-truth files live in this directory; copy-paste into App Store
> Connect at submission time. Localised pairs are kept in `ja/` and `en/`.

## Files

| Field                | ja                                | en                                | App Store limit |
|---|---|---|---|
| Name                 | [`ja/name.txt`](ja/name.txt)                       | [`en/name.txt`](en/name.txt)                       | 30 chars |
| Subtitle             | [`ja/subtitle.txt`](ja/subtitle.txt)               | [`en/subtitle.txt`](en/subtitle.txt)               | 30 chars |
| Promotional text     | [`ja/promotional-text.txt`](ja/promotional-text.txt) | [`en/promotional-text.txt`](en/promotional-text.txt) | 170 chars |
| Description          | [`ja/description.txt`](ja/description.txt)         | [`en/description.txt`](en/description.txt)         | 4 000 chars |
| Keywords             | [`ja/keywords.txt`](ja/keywords.txt)               | [`en/keywords.txt`](en/keywords.txt)               | 100 chars |
| What's new (v1.0)    | [`ja/whats-new.txt`](ja/whats-new.txt)             | [`en/whats-new.txt`](en/whats-new.txt)             | 4 000 chars |

Plus:

- [`urls.md`](urls.md) — Support / Marketing / Privacy / Terms URLs and the
  rename ritual once they are finalised.
- [`screenshot-captions.md`](screenshot-captions.md) — captions for the
  Phase P-5 screenshot batch (10 iPhone slots + 3 iPad slots).

---

## Field-by-field summary

### Name (30)
- **ja**: `WorkoutKit - シンプル筋トレ記録`
- **en**: `WorkoutKit - Simple Tracker`

Includes the brand for App Store search. Avoids medical / superlative phrases.

### Subtitle (30)
- **ja**: `目的×部位×器具で5秒生成・全345種目`
- **en**: `5-second smart workout planner`

The 5-second hook + the catalogue size are our strongest differentiators
under the brand.

### Promotional text (170, editable post-release)
Used as the launch banner / for ASO experiments. Both locales repeat:
"v1.0", "5-second", "345 exercises", "rest timer Live Activity",
"Apple Watch widget", "Premium ¥680/月 or ¥4,900/年", "7-day free trial",
"Family Sharing".

### Description (4 000)
Headline → Highlights → Builder wizard → Library detail → Premium feature
list (11 items shipping in v1.0 incl. rest-timer Live Activity, Apple Watch
Smart Stack widget, AI workout summary; the 3 unimplemented `ProFeature`
cases — `customExercise`, `sessionPhoto`, `appIconVariants` — are deferred
to `docs/ROADMAP.md` and not advertised here, per Apple guideline 2.3) →
Principles (no ads, no tracking) → Free presets → Requirements →
Subscription disclosure block (Apple guideline 3.1.2) → Medical disclaimer
(Apple guideline 1.4.1) → Contact placeholders.

The body uses single-byte half-width separators for App Store readability
and avoids heavy emoji clusters per Apple's review patterns.

### Keywords (100, no spaces after commas)
- **ja**: `筋トレ,フィットネス,ワークアウト,トレーニング,記録,ログ,ジム,自宅トレ,自重,ダンベル,バーベル,広告なし,オフライン`
- **en**: `workout,fitness,gym,training,exercise,tracker,log,routine,bodyweight,barbell,dumbbell,planner,offline`

Brand "WorkoutKit" is **not** repeated here — App Store already searches
the app name. Keywords cover four categories: activity (workout / fitness),
context (gym / 自宅トレ), equipment (barbell / dumbbell / bodyweight),
positioning (offline / 広告なし).

No competitor names, no medical claims, no trademark phrases.

### What's new (v1.0)
Bullet list of the headline features. v1.0 doubles as a "first release"
note, so we lead with that line; future releases will replace this with
their changelog.

---

## Tone & voice — recap

- **ja**: 丁寧体だが堅すぎない。フィットネス愛好家に「自分ごと」として響く語感。
- **en**: Concise, motivational, professional but friendly.
- 絵文字は控えめ。Promo / What's new 以外には基本入れない。
- 競合製品(workout-cool / Strong / Hevy 等)には一切言及しない。

## Apple guideline check

- **1.4.1 (medical claims)**: Description ja / en explicitly call out
  "WorkoutKit is not medical advice / 医療助言ではありません" and recommend
  consulting a doctor.
- **2.3 (accurate metadata)**: Every claim in description / promo / what's
  new maps to a shipping feature in `RELEASE_AUDIT.md`.
- **3.1.2 (subscriptions)**: Description includes the required disclosure
  block — auto-renewal terms, 7-day trial, ¥680/month and ¥4,900/year
  prices, "Subscription Group: WorkoutKit Premium", cancel-anytime via
  iOS Settings, and Restore Purchases path. Matches the StoreKit
  configuration `WorkoutKit.storekit` and `LICENSE_FOOTER` strings in
  `Localizable.xcstrings`.
- **5.1.1 (data collection)**: Description states "no tracking, no data
  collection" — matches `PrivacyInfo.xcprivacy`.

---

## Submission checklist

- [ ] Final URLs from `urls.md` substituted into `description.txt` and
      Info.plist.
- [ ] `[YOUR_EMAIL]` and `[YOUR_NAME]` replaced everywhere
      (`grep -rn "\[YOUR_EMAIL\]\|\[YOUR_NAME\]" docs/app-store/` should
      return zero hits).
- [ ] Screenshot batch captured per `screenshot-captions.md` and uploaded.
- [ ] App Store age rating filled in (12+ recommended for fitness apps).
- [ ] Localizable.xcstrings completeness re-confirmed (RELEASE_AUDIT.md §5).
- [ ] EULA: standard Apple EULA accepted unless we ship a custom Terms URL.
- [ ] Build uploaded from Xcode Organizer with the production xcconfig
      (Release.xcconfig, not Beta).

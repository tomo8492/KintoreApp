# WorkoutKit — Roadmap

> Version snapshot: v1.0 (about to ship). Forward-looking items here are
> intent only — they ship when they ship and the order is not a commitment.
> Updated: 2026-05-07.

## v1.0 (shipping)

Foundations + the full first-party feature set listed below. Everything in
this section corresponds to a working code path in this repository and is
mentioned in `docs/app-store/{ja,en}/description.txt`.

### Coverage
- 345 exercises bundled, all translated ja + en
- Anatomical body diagram, 2-row layout (Front / Back) with cue dots tagged
  by anatomical side (`ProFeature` is unrelated; this is core)
- Builder wizard (Goal → Muscle → Equipment → Time) with Shuffle and Choose
- Session execution (sets / reps / weight / RPE / rest), interval timer,
  Live Activity on lock screen + Dynamic Island
- History list + calendar + 30-day cutoff (free) / full history (Pro)
- Templates: 3 free presets (Push-Pull-Legs / Upper-Lower / Full-body) +
  unlimited custom templates (Pro)
- Library (search + 4-facet filter, exercise detail with steps + common
  mistakes + cautions)
- Settings (kg / lbs, theme, restore purchases, language deep link)
- Localizable.xcstrings 100 % ja + en
- Privacy: no tracking, no data collection, fully offline (StoreKit only)

### Pro features shipping in v1.0
| Code case (`ProFeature`) | UX surface | Status |
|---|---|---|
| `unlimitedHistory` | History list / calendar past 30 days | ✅ |
| `advancedCharts`   | History → Charts (weekly / monthly / heat map) | ✅ |
| `customTemplates`  | Templates → Add / Duplicate / Delete custom | ✅ |
| `csvImport`        | Settings → Data → Import CSV / JSON | ✅ |
| `csvExport`        | Settings → Data → Export CSV | ✅ |
| `manualEntry`      | History → Add manual entry | ✅ |
| `videoLink`        | Library detail → YouTube reference | ✅ |

---

## v1.1+ Roadmap

The intent here is to keep `ProFeature` enum cases stable so user-facing
purchase semantics don't shift across versions. The cases below already
exist in `WorkoutKit/Domain/Enums/ProFeature.swift` so a future paywall row
just needs `isShownInPaywallV1 → isShownInPaywallV*N* { return true }` plus
the actual UI.

### Pro feature rollouts

| Code case | What ships | Notes |
|---|---|---|
| `customExercise`    | User-created exercises in Library (Add / Edit / soft-delete) | Schema bit `Exercise.isUserCreated` already exists; importers protect it from CSV overwrite. Needs Library "+" entry, ExerciseEditView, and dedup logic against the 345 bundled slugs. |
| `sessionPhoto`      | Attach photos + structured notes to a session | Needs new `WorkoutSession.attachments: [SessionAttachment]` (file URL + thumbnail + caption). PhotosPicker integration. iCloud-friendly when sync arrives. |
| `appIconVariants`   | Settings → choose alternate App Icon | Needs `AlternateAppIcon-*.appiconset` entries + Info.plist `CFBundleAlternateIcons` + a Settings UI calling `UIApplication.setAlternateIconName`. |
| `watchOSCompanion`  | Apple Watch companion app | Needs new `WorkoutKitWatch` target, WatchConnectivity bridge, Live Activity bridge to watch. Already flagged "(v1.1+)" in v1.0 description. |

### Localisation

- Additional bundled languages once the catalogue stabilises:
  zh-Hans / zh-Hant / ko / fr / es / de / pt-BR. App architecture is already
  String-Catalog driven so adding a locale is a translation job, not a code
  job.

### Content

- Grow the bundled exercise database from 345 → 600+. Same JSON seed format,
  same body-annotation pipeline (`scripts/sidify_annotations.py`).
- Optional cue media: short illustrated GIFs or static stick-figure poses
  per exercise. (Selection criterion: must be MIT / CC-BY licensable so the
  app stays free of third-party dependency creep.)

### Platform

- **CloudKit sync** across user's own devices. App Group
  (`group.com.tomo.workoutkit`) is already declared in entitlements so the
  storage migration path is short.
- **iCloud Drive backup** for users who prefer a manual snapshot over
  CloudKit auto-sync.
- **Vision Pro** rendering pass once SwiftUI's diagram renders pass first
  visual review.

### Quality

- Migrate to Swift 6 strict-concurrency mode once SwiftData annotates
  `PartialKeyPath` + `@Query` sortBy parameters as `Sendable`. v1.0 ships
  in Swift 5 mode with 19 future-error warnings tracked in
  `RELEASE_AUDIT.md`.
- Screenshot-diff CI job that runs the existing UI test capture suites and
  asserts against a baseline.

---

## Out of scope (no plans)

Listed only to prevent re-discussion:
- Real-time multiplayer / social feed.
- Built-in YouTube player (App Store guideline 4.0 — passing through to the
  YouTube app is intentional).
- Calorie tracking / nutrition database (different product).
- Ads. Ever. (Premium subscription is the only monetization channel.)
- Web app, Android app, or any platform other than Apple's.

# Free Exercise Asset Research — Report

**Branch**: `research/free-exercise-assets`
**Goal**: Replace the rejected stick-figure / 3D-self-made exercise visuals with **professional-quality real-human demonstrations** for the 5 prototype slugs (`push-up`, `air-squat`, `plank`, `reverse-lunge`, `burpee`), under licenses safe for App Store commercial distribution.

---

## TL;DR

- **Adopted source**: **Pexels** (Pexels License — CC0-equivalent, free for commercial use, no attribution required, modification allowed).
- **Rejected source**: `yuhonas/free-exercise-db` (visually superior, but the maintainer himself admits in [issue #2](https://github.com/yuhonas/free-exercise-db/issues/2) that the images are of unknown origin and "usage at your own risk"; reverse image search and a [follow-up thread](https://github.com/wrkout/exercises.json/issues/305) trace the source to **bodybuilding.com**, whose ToU explicitly prohibits redistribution).
- **Bundled**: 19 photos, **2.8 MB** total, organised as Asset Catalog image sets under `WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/`.
- **New view**: `ExercisePhotoCarouselView` — SwiftUI `TabView(.page)` auto-advancing every 2 s, paused under Reduce Motion, with VoiceOver label + "Photo N of M" value.
- **Wiring**: `ExerciseAnimationView` now prefers the carousel for the 5 supported slugs and falls back to the existing procedural stick figure for everything else.
- **Build / tests**: `xcodebuild build` and `xcodebuild test` both **succeed** on iPhone 16 (iOS 18.5). Swift-testing reports **112 tests in 15 suites passed**, plus 1 UI-test. No regressions.
- **Honest caveat**: only **1 high-quality burpee photo** was findable on Pexels' free search. See "Burpee gap" below for the proposed v1.1 mitigation.

---

## 1. Source Comparison

| Source | License | Image style | Commercial OK? | Burpee available? | API key needed? | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| **Pexels** | Pexels License (CC0-equivalent, attribution-free) | Real-people photos, professional lighting, varied subjects/locations | ✅ Yes, explicitly | △ 1 high-quality photo | Optional (CDN URLs are public; API only needed for search at scale) | **ADOPTED** |
| Unsplash | Unsplash License (similar to Pexels) | High-quality lifestyle photos | ✅ Yes | Not investigated | Optional | Backup if Pexels lacks a slug |
| Pixabay | Pixabay License (CC0-like) | Mixed (photos + vectors + illustrations) | ✅ Yes | Not investigated | Required for API | Backup |
| `yuhonas/free-exercise-db` | Repo LICENSE: Unlicense; **but images are scraped from a copyrighted source** ([source admission](https://github.com/yuhonas/free-exercise-db/issues/2#issuecomment-1641820098), [trace to bodybuilding.com](https://github.com/wrkout/exercises.json/issues/305)) | Studio fitness-model series, classic gym setting, two-photo start/end pairs | ❌ **Infringing** despite the LICENSE file | ❌ No burpee in DB | None (raw GitHub URLs) | **REJECTED** — license unsafe for App Store |
| `wrkout/exercises.json` | Same as above (parent repo) | Same images | ❌ Same problem | ❌ | None | REJECTED — same problem; maintainer points commercial users to the paid `wrkout.xyz` service |
| wger (`wger.de`) | Per-image CC-BY-SA 4.0 | Mixed quality, mostly illustrations / community photos | △ With attribution | Mixed | API call needed | Possible v1.1 source if attribution UI is added |
| Wikimedia Commons | Mostly PD or CC-BY-SA | Varied — some excellent, many amateur | △ Per-image check required | Possible | None | Not worth per-image vetting at this scale |
| LottieFiles (CDN) | Per-asset; many require attribution / paid use | Stylised animations, not real humans | △ Per-asset | △ | None for direct file URL | Conflicts with the "real human" goal |

### Why `free-exercise-db` was so tempting (and why we said no)

The studio shots in `yuhonas/free-exercise-db` are **visually outstanding** for a fitness product — single fitness model in a controlled gym setting, consistent angle per exercise, paired start/end frames that map cleanly onto a 2-frame loop. They are exactly what every "scrappy fitness app" wishes it had.

Unfortunately:

1. The repo's own LICENSE is `Unlicense`, which would normally place everything in the public domain.
2. But the maintainer of the **upstream** repo (`wrkout/exercises.json`) **explicitly states in `CONTRIBUTING.md`** that the images were "scraped off the internet" and "would advise against using them in commercial projects".
3. Reverse image search by another contributor traced multiple images to **bodybuilding.com**, whose Terms of Use grant only a personal-use viewing right and "do not grant to you or any person any right to use, reproduce, copy, modify, transmit, display, publish, sell, license, create derivative works, publicly perform, or distribute by any means".
4. The original-repo maintainer now sells the curated dataset commercially via wrkout.xyz, which would not be the case if the underlying images were truly Public Domain.

A LICENSE file cannot launder copyrighted content. We treat this as **clearly infringing for App Store distribution** and **do not bundle, mirror, or even check in any image from this dataset**, including in test fixtures.

---

## 2. What Was Bundled

`WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/` (namespace `ExercisePhotos`, `provides-namespace: true`):

| Slug → set | Photos bundled | Notes |
| --- | --- | --- |
| `push-up` → `pushup` | 5 | Side angles, front-low, indoor + park; varied subjects (men, varied ages/ethnicities) |
| `air-squat` → `squat` | 5 | Front, deep ATG, two-person partner, indoor + outdoor + studio |
| `plank` → `plank` | 4 | Side, outdoor mountain backdrop, forearm + extended; one close-up was dropped (`plank-3` removed — it was just hands/arms, didn't show full pose) |
| `reverse-lunge` → `lunge` | 4 | Forward & reverse stances; one barbell-hold candidate (`reverse-lunge-5`) dropped — it wasn't actually a lunge |
| `burpee` → `burpee` | **1** | Only one high-quality, clearly-labelled burpee photo could be found on Pexels' free search (see "Burpee gap" below) |

Total: **19 image sets, 2.8 MB**. JPEGs served at `?auto=compress&cs=tinysrgb&w=1200` from the Pexels CDN.

Curation manifest with full per-photo metadata: `/tmp/exercise-photos/MANIFEST.json` (committed to research worktree, not to repo). The same metadata is reproduced verbatim in `THIRD_PARTY_NOTICES.md`.

---

## 3. Implementation Notes

### `ExercisePhotoCarouselView`

- `TabView(selection:)` with `.tabViewStyle(.page(indexDisplayMode: .always))` for swipeable + auto-advancing pages.
- Auto-advance is a `Timer` started in `.onAppear` and torn down in `.onDisappear`. Index wraps mod `count`. Animation: `.easeInOut(duration: 0.4)`.
- **Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`) **stops auto-advance** and shows the first photo statically — users can still swipe manually. Detected on first appear and re-evaluated when the env value changes.
- **Single-photo case** (`burpee`): `indexDisplayMode: .never` (no dots), auto-advance disabled. The view degrades gracefully into a static image instead of looking broken.
- **Accessibility**: VoiceOver reads the existing `library.detail.animation.a11y.<slug>` key (e.g., "Push-up demonstration animation") as the label, plus a new `library.detail.photo.index %lld %lld` value ("Photo N of M") that updates as the carousel advances. `.isImage` trait. The view is treated as a single accessibility element so swiping doesn't trap focus.

### `ExerciseAnimationView` integration

The detail screen calls `ExerciseAnimationView(slug:)` once. That view now branches:

- **If `ExercisePhotoSet.from(slug:) != nil`** → render `ExercisePhotoCarouselView` (real-human photos).
- **Else** → fall back to the existing procedural stick-figure body (untouched).

This keeps the F-09 prototype in place for any slug we haven't bundled photos for, while shipping the higher-quality experience wherever we have one. The existing `ExerciseAnimationKind` API and snapshot tests are unchanged — `ExerciseAnimationSnapshotTests` continues to pass (it uses `kind.pose(_:)` directly, bypassing the body).

### Localisation

Added one new key to `WorkoutKit/Resources/Localizable.xcstrings`:

| Key | en | ja |
| --- | --- | --- |
| `library.detail.photo.index %lld %lld` | `Photo %1$lld of %2$lld` | `写真 %1$lld / %2$lld` |

Existing `library.detail.animation.a11y.<slug>` keys are reused — they describe the exercise, not the rendering, so they apply equally to the carousel and the procedural animation.

---

## 4. Burpee gap (the honest part)

Pexels' "burpee" search returns ~80k candidates, but the vast majority are unrelated lifestyle/yoga shots that surfaced because of generic tag keywords. After manual inspection, only **one** photo (Pexels ID `30246184` by Andrea Musto) is a clear, well-lit burpee mid-rep. The rest were either:

- Different exercises (squats, jump rope, mountain climbers) tagged "burpee" because they appear in the same routine.
- Studio fitness models in static "stand" or "smile to camera" poses with no clear movement intent.
- Composition issues (cropped, busy background, low resolution).

**Why this is OK for the prototype**:

- The carousel handles single-photo sets gracefully (no dot indicator, no auto-advance, no broken-loop appearance).
- A burpee is a multi-phase movement (squat → kick-back → push-up → jump). Even a real-time video clip would only loosely "demonstrate" it; a single decisive mid-rep frame is honest.
- The supporting text instructions on the detail screen carry the procedural detail.

**Mitigations for v1.1**:

1. **Apply for a Pexels API key** (free, instant) and run a programmatic batch search filtered by orientation + min resolution + min likes, then manually approve top 20. Likely yields 3–5 acceptable burpee photos.
2. **Composite a 4-frame "burpee progression" carousel** by curating one squat, one push-up, one jump, plus the mid-burpee shot — labelled appropriately ("Phase 1 / 4: squat down" etc.). This is conceptually a different feature and worth a separate design pass.
3. **Cross-reference Pixabay and Unsplash** for additional burpee candidates; both have similar attribution-free licenses.
4. **Commission 5–10 photos** from a fitness photographer (≈ ¥30–50k for the full WorkoutKit shot list) — by far the cleanest path if the app starts generating revenue.

The `1 burpee photo` is documented in `THIRD_PARTY_NOTICES.md` and is the only known content gap in this branch. Everything else has 4–5 photos per exercise.

---

## 5. Photos per exercise — UX trade-offs (real photos vs. animation)

| Aspect | Real-photo carousel (this branch) | Procedural stick figure (F-09 prototype) | Lottie / 3D animation |
| --- | --- | --- | --- |
| Perceived quality | **High** (real human, professional shoot) | Low (clearly toy-like) | Medium-High (depends on artist) |
| Movement clarity | Medium (discrete frames; Δ between photos visible but not continuous) | High (continuous motion) | High |
| Variety / inclusivity | High (different bodies, ages, genders, settings) | None (one stick figure) | Low (single character) |
| File size | Medium (≈ 150 KB/photo, 2.8 MB total for 5 exercises) | ~0 (procedural) | Medium (≈ 50–200 KB per Lottie JSON; more for 3D) |
| Accessibility | Same a11y label; auto-advance respects Reduce Motion | Reduce Motion freezes mid-pose | Per-asset |
| Localisation | Photos are language-neutral | Language-neutral | Language-neutral |
| Risk | License + likeness rights (Pexels handles model releases) | None | License + redistribution |
| Future scaling cost | Linear (one curated photo set per slug) | Linear (one procedural choreography per slug) | Linear (one Lottie file per slug) |
| Time to add a 6th exercise | ~30 min curation + bundling | ~2 hours of pose-keyframing code | ~4–8 hours commission |

**Recommended v1.0 mix** (this branch):

- The 5 prototype slugs ship with the carousel (this PR).
- All other slugs continue to fall back to the procedural stick figure (already in `main`).
- For slugs we don't yet have a carousel for, the user still gets *something*, which is strictly better than a missing media slot.

---

## 6. Verification (this branch)

- `xcodegen generate` regenerates `WorkoutKit.xcodeproj` cleanly (incidental scheme/pbxproj diff is xcodegen's own output, not hand-edited).
- `xcodebuild build` succeeds on iPhone 16 sim, Xcode 26.4.1, iOS 18.5.
- `xcodebuild test` succeeds: **112 swift-testing tests in 15 suites + 1 UITest**, all green. `ExerciseAnimationSnapshot` suite still passes (it uses `kind.pose(_:)` directly and so is unaffected by the new branch in `body`).
- 19 PNG screenshots of the bundled photos are written to `/tmp/photo-carousel/<asset>.png` (≈ 10 MB) — these are exactly what the carousel renders frame-by-frame.

To see the live carousel:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project WorkoutKit.xcodeproj -scheme WorkoutKit \
  -destination 'platform=iOS Simulator,id=A2CBC991-8C08-4CE2-B53B-20998462398D' \
  -configuration Debug build
xcrun simctl boot A2CBC991-8C08-4CE2-B53B-20998462398D
open -a Simulator
xcrun simctl install A2CBC991-8C08-4CE2-B53B-20998462398D \
  ~/Library/Developer/Xcode/DerivedData/WorkoutKit-*/Build/Products/Debug-iphonesimulator/WorkoutKit.app
xcrun simctl launch A2CBC991-8C08-4CE2-B53B-20998462398D com.tomo.workoutkit
# Navigate Library → push-up → carousel auto-advances every 2 s.
```

---

## 7. Decisions worth re-confirming

1. **Burpee shipping with 1 photo**: should the v1.0 build ship with only the burpee carousel-of-one, or should we delay until a fuller burpee set exists? My recommendation is *ship now*, because (a) the single photo is genuinely good, (b) the other 4 exercises benefit immediately, and (c) the prototype's bar is "show what's possible", not "feature-complete".
1. **Photo-set namespace**: I used `ExercisePhotos/<asset>` rather than flattening into the asset catalog root. This avoids future name collisions when the photo set grows.
1. **Carousel pace (2 s/photo)**: this is a guess. If user testing finds it too fast/slow it's a one-line constant change in `ExercisePhotoCarouselView.interval`.
1. **Where the carousel auto-pauses**: currently *only* under Reduce Motion. We could also pause when the user manually swipes — that would feel more polite but adds state. Leaving for v1.1 unless tomo flags it.

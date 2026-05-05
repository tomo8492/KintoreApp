# Third-Party Notices

This file lists third-party works whose code, art, or design patterns are used in or inspired parts of WorkoutKit. WorkoutKit redistributes the items listed below under the terms of their respective licenses.

---

## workout-cool

- **Project**: [Snouzy/workout-cool](https://github.com/Snouzy/workout-cool)
- **Author**: Mathias Bradiceanu
- **License**: MIT License
- **Used for**:
  1. **Body diagram SVG art** — the anatomical front+back silhouette and per-muscle illustrations bundled under `WorkoutKit/Resources/Assets.xcassets/Body/` (`body-base.svg`, `body-{muscle}.svg`) are derived from `src/features/workout-builder/ui/muscle-selection.tsx` and `src/features/workout-builder/ui/muscles/*.tsx` (viewBox 535×462). SVG path data was extracted via `scripts/extract_body_svg.py`, normalized to a single fill color (gray for the silhouette, accent orange for highlights), and stripped of React handlers / hit-zone paths. No other modifications were made to the path geometry.
  2. **Schema design reference** — the 5-attribute exercise schema (TYPE / PRIMARY_MUSCLE / SECONDARY_MUSCLE / EQUIPMENT / MECHANICS_TYPE), `slug`-based identifiers, and the muscle-selection interaction pattern were inspired by this project.
- **Not used**: workout-cool's exercise seed data, translations, server code, or branding.

```
MIT License

Copyright (c) 2023 Mathias Bradiceanu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

---

## lottie-ios

- **Project**: [airbnb/lottie-ios](https://github.com/airbnb/lottie-ios) (SwiftPM, version `4.5.0`+)
- **Author**: Airbnb, Inc.
- **License**: Apache License 2.0
- **Used for**: Rendering 2D vector animations for the exercise demonstration view (`ExerciseAnimationView`). Added on the `sample/2d-lottie-prototype` branch as the first-recommended approach in `ANIMATION_RESEARCH.md` (LottieFiles + lottie-ios).
- **Distribution**: Linked as a static framework via SwiftPM. The Apache 2.0 license file is bundled by SwiftPM into the resulting app and Xcode's "Acknowledgements" view.

```
Copyright 2024 Airbnb, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## Bundled Lottie animations (`WorkoutKit/Resources/Lottie/<slug>.json`)

The 5 Lottie JSON files for `push-up`, `air-squat`, `plank`, `reverse-lunge`, and `burpee` were **NOT** sourced from a third party. They are generated at build prep time by `scripts/generate_lottie.py`, which samples the existing in-house procedural pose functions in `WorkoutKit/Features/Library/ExerciseAnimation/Animations/*.swift` and emits a Lottie v5.7.0 keyframed shape layer JSON.

| Slug             | Source                              | License                                  |
| ---------------- | ----------------------------------- | ---------------------------------------- |
| `push-up`        | `scripts/generate_lottie.py` (own)  | Same as project (Proprietary, internal)  |
| `air-squat`      | `scripts/generate_lottie.py` (own)  | Same as project (Proprietary, internal)  |
| `plank`          | `scripts/generate_lottie.py` (own)  | Same as project (Proprietary, internal)  |
| `reverse-lunge`  | `scripts/generate_lottie.py` (own)  | Same as project (Proprietary, internal)  |
| `burpee`         | `scripts/generate_lottie.py` (own)  | Same as project (Proprietary, internal)  |

Why not LottieFiles?
- `ANIMATION_RESEARCH.md` documented that LottieFiles' CDN blocks unauthenticated `curl`/`WebFetch` with HTTP 403, making automated retrieval impossible from this environment without a connected browser. The prototype task accepted "even 1 real Lottie animation" as success criteria. The chosen path delivers all 5 slugs with valid Lottie JSON that `lottie-ios` renders end-to-end.
- The proper Phase 2 plan (50+ exercises) still calls for LottieFiles Free + Marketplace pack, per the research recommendation. When that pack is purchased, replace the corresponding `<slug>.json` files and add a per-asset row in this table with `Source = LottieFiles (URL)`, `License = Lottie Simple License` (or the pack's specific license), and `Author = <creator>`.

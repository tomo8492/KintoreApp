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

## Pexels — Exercise Demonstration Photos

- **Source**: [Pexels](https://www.pexels.com/) — stock photo platform
- **License**: [Pexels License](https://www.pexels.com/license/)
- **Summary**: Free for commercial use, no attribution required, modification allowed. Prohibited: selling unaltered copies, misrepresenting endorsements, redistributing on competing stock platforms, using as trademarks.
- **Used for**: 30 exercise demonstration photos bundled under `WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/<name>.imageset/`. Displayed in `AnnotatedFormView` (form-cue overlay on the Library detail screen; see `WorkoutKit/Resources/FormAnnotations/<slug>-annotations.json` for the per-exercise annotation data). Source URL pattern: `https://images.pexels.com/photos/<id>/pexels-photo-<id>.jpeg?auto=compress&cs=tinysrgb&w=1200`.
- **Attribution**: not required by the license, but listed below as a courtesy.

| Asset | Pexels ID | Photographer | Page |
| --- | --- | --- | --- |
| `barbell-back-squat-1` | 13106591 | Airam Dato-on | https://www.pexels.com/photo/13106591/ |
| `barbell-bench-press-1` | 3837757 | Andrea Piacquadio | https://www.pexels.com/photo/3837757/ |
| `barbell-deadlift-1` | 1552103 | Leon Mart | https://www.pexels.com/photo/1552103/ |
| `barbell-row-1` | 4793200 | Anete Lusina | https://www.pexels.com/photo/4793200/ |
| `dumbbell-curl-1` | 3763115 | Andrea Piacquadio | https://www.pexels.com/photo/3763115/ |
| `dumbbell-shoulder-press-1` | 7289370 | Alesia Kozik | https://www.pexels.com/photo/7289370/ |
| `dumbbell-row-1` | 12890887 | Connor Scott McManus (alteredsnaps) | https://www.pexels.com/photo/12890887/ |
| `kettlebell-swing-1` | 416809 | Pixabay | https://www.pexels.com/photo/416809/ |
| `lat-pulldown-1` | 30165244 | Foad Shariyati | https://www.pexels.com/photo/30165244/ |
| `pull-up-1` | 9644832 | Ron Lach | https://www.pexels.com/photo/9644832/ |
| `romanian-deadlift-1` | 14623740 | Miguel González | https://www.pexels.com/photo/14623740/ |
| `push-up-1` | 4720304 | Ketut Subiyanto | https://www.pexels.com/photo/4720304/ |
| `push-up-2` | 4720307 | Ketut Subiyanto | https://www.pexels.com/photo/4720307/ |
| `push-up-3` | 4720314 | Ketut Subiyanto | https://www.pexels.com/photo/4720314/ |
| `push-up-4` | 8173436 | Kampus Production | https://www.pexels.com/photo/8173436/ |
| `push-up-5` | 4803858 | Ketut Subiyanto | https://www.pexels.com/photo/4803858/ |
| `air-squat-1` | 7746286 | Polina Tankilevitch | https://www.pexels.com/photo/7746286/ |
| `air-squat-2` | 30246176 | Andrea Musto | https://www.pexels.com/photo/30246176/ |
| `air-squat-3` | 8032754 | MART PRODUCTION | https://www.pexels.com/photo/8032754/ |
| `air-squat-4` | 4662331 | Anthony Shkraba | https://www.pexels.com/photo/4662331/ |
| `air-squat-5` | 14061687 | Ricardo Cesar Lima | https://www.pexels.com/photo/14061687/ |
| `plank-1` | 6285204 | Gustavo Fring | https://www.pexels.com/photo/6285204/ |
| `plank-2` | 7801480 | Pavel Danilyuk | https://www.pexels.com/photo/7801480/ |
| `plank-4` | 4945275 | Anastasia Shuraeva | https://www.pexels.com/photo/4945275/ |
| `plank-5` | 4945276 | Anastasia Shuraeva | https://www.pexels.com/photo/4945276/ |
| `reverse-lunge-1` | 29825236 | Marcus Chan Media | https://www.pexels.com/photo/29825236/ |
| `reverse-lunge-2` | 5067743 | Anna Shvets | https://www.pexels.com/photo/5067743/ |
| `reverse-lunge-3` | 4348637 | MART PRODUCTION | https://www.pexels.com/photo/4348637/ |
| `reverse-lunge-4` | 8770407 | Gustavo Fring | https://www.pexels.com/photo/8770407/ |
| `burpee-1` | 30246184 | Andrea Musto | https://www.pexels.com/photo/30246184/ |

> Numbering gaps (`plank-3`, `reverse-lunge-5`) are intentional — those candidates were dropped during curation (one was an arms-only close-up, the other was a barbell hold that wasn't a lunge). The numbering was preserved from the curation manifest so future audits can match this list against `/tmp/exercise-photos/MANIFEST.json` from the research worktree.

### Pexels License (verbatim, abridged)

> All photos and videos on Pexels can be downloaded and used for free.
>
> ✓ All photos and videos on Pexels are free to use.
> ✓ Attribution is not required. Giving credit to the photographer or Pexels is not necessary but always appreciated.
> ✓ You can modify the photos and videos from Pexels. Be creative and edit them as you like.
>
> ✗ Identifiable people may not appear in a bad light or in a way that is offensive.
> ✗ Don't sell unaltered copies of a photo or video, e.g. as a poster, print or on a physical product without modifying it first.
> ✗ Don't imply endorsement of your product by people or brands on the imagery.
> ✗ Don't redistribute or sell the photos and videos on other stock photo or wallpaper platforms.

Full text: https://www.pexels.com/license/

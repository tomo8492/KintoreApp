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
- **Used for**: 101 exercise demonstration photos bundled under `WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/<name>.imageset/`. Displayed in `AnnotatedFormView` (form-cue overlay on the Library detail screen; see `WorkoutKit/Resources/FormAnnotations/<slug>-annotations.json` for the per-exercise annotation data). Source URL pattern: `https://images.pexels.com/photos/<id>/pexels-photo-<id>.jpeg?auto=compress&cs=tinysrgb&w=1200`.
- **Attribution**: not required by the license, but listed below as a courtesy.

| Asset | Pexels ID | Photographer | Page |
| --- | --- | --- | --- |
| `barbell-back-squat-1` | 13106591 | Airam Dato-on | https://www.pexels.com/photo/13106591/ |
| `barbell-bench-press-1` | 3837757 | Andrea Piacquadio | https://www.pexels.com/photo/3837757/ |
| `barbell-deadlift-1` | 1552103 | Leon Mart | https://www.pexels.com/photo/1552103/ |
| `barbell-row-1` | 4793200 | Anete Lusina | https://www.pexels.com/photo/4793200/ |
| `dumbbell-curl-1` | 3763115 | Andrea Piacquadio | https://www.pexels.com/photo/3763115/ |
| `dumbbell-shoulder-press-1` | 7289370 | Alesia Kozik | https://www.pexels.com/photo/7289370/ |
| `barbell-curl-1` | 5327456 | (photographer TBD) | https://www.pexels.com/photo/5327456/ |
| `crunch-1` | 6516230 | Polina Tankilevitch | https://www.pexels.com/photo/6516230/ |
| `dumbbell-row-1` | 12890887 | Connor Scott McManus (alteredsnaps) | https://www.pexels.com/photo/12890887/ |
| `front-squat-1` | 1552249 | (photographer TBD) | https://www.pexels.com/photo/1552249/ |
| `glute-bridge-1` | 4534632 | Vlada Karpovich | https://www.pexels.com/photo/4534632/ |
| `hanging-leg-raise-1` | 5799860 | Kong Khawlhring | https://www.pexels.com/photo/5799860/ |
| `kettlebell-swing-1` | 416809 | Pixabay | https://www.pexels.com/photo/416809/ |
| `lat-pulldown-1` | 30165244 | Foad Shariyati | https://www.pexels.com/photo/30165244/ |
| `mountain-climber-1` | 2294361 | Li Sun | https://www.pexels.com/photo/2294361/ |
| `seated-cable-row-1` | 4162476 | (photographer TBD) | https://www.pexels.com/photo/4162476/ |
| `pull-up-1` | 9644832 | Ron Lach | https://www.pexels.com/photo/9644832/ |
| `romanian-deadlift-1` | 14623740 | Miguel González | https://www.pexels.com/photo/14623740/ |
| `russian-twist-1` | 6740053 | Mikhail Nilov | https://www.pexels.com/photo/6740053/ |
| `side-plank-1` | 6303452 | Klaus Nielsen | https://www.pexels.com/photo/6303452/ |
| `bicycle-crunch-1` | 8038640 | Roman Odintsov | https://www.pexels.com/photo/8038640/ |
| `bird-dog-1` | 6454196 | Marta Wave | https://www.pexels.com/photo/6454196/ |
| `cat-cow-1` | 7663225 | Anastasia Shuraeva | https://www.pexels.com/photo/7663225/ |
| `childs-pose-1` | 4127307 | Gustavo Fring | https://www.pexels.com/photo/4127307/ |
| `cobra-stretch-1` | 6787216 | Marcus Aurelius | https://www.pexels.com/photo/6787216/ |
| `downward-dog-1` | 7664139 | Anastasia Shuraeva | https://www.pexels.com/photo/7664139/ |
| `dumbbell-bench-press-1` | 3839310 | Andrea Piacquadio | https://www.pexels.com/photo/3839310/ |
| `dumbbell-lateral-raise-1` | 5327464 | Tima Miroshnichenko | https://www.pexels.com/photo/5327464/ |
| `hammer-curl-1` | 30672394 | foad shariyati | https://www.pexels.com/photo/30672394/ |
| `high-knees-1` | 4194670 | Dinielle De Veyra | https://www.pexels.com/photo/4194670/ |
| `jump-rope-1` | 8401106 | RDNE Stock project | https://www.pexels.com/photo/8401106/ |
| `jumping-jacks-1` | 7298411 | Kindel Media | https://www.pexels.com/photo/7298411/ |
| `leg-raise-1` | 6283634 | Anna Shvets | https://www.pexels.com/photo/6283634/ |
| `pigeon-pose-1` | 7318689 | MART PRODUCTION | https://www.pexels.com/photo/7318689/ |
| `seated-dumbbell-press-1` | 4164756 | Ivan S | https://www.pexels.com/photo/4164756/ |
| `sit-up-1` | 8401120 | RDNE Stock project | https://www.pexels.com/photo/8401120/ |
| `squat-jump-1` | 13327298 | Jordan Bergendahl | https://www.pexels.com/photo/13327298/ |
| `wall-sit-quad-1` | 6740055 | Mikhail Nilov | https://www.pexels.com/photo/6740055/ |
| `chin-up-1` | 14591604 | (photographer TBD) | https://www.pexels.com/photo/14591604/ |
| `incline-push-up-1` | 8401820 | RDNE Stock project | https://www.pexels.com/photo/8401820/ |
| `step-up-1` | 13896897 | (photographer TBD) | https://www.pexels.com/photo/13896897/ |
| `tricep-dip-bench-1` | 8567596 | Karolina Grabowska | https://www.pexels.com/photo/8567596/ |
| `running-treadmill-1` | 30704307 | (photographer TBD) | https://www.pexels.com/photo/30704307/ |
| `stationary-bike-1` | 4162595 | (photographer TBD) | https://www.pexels.com/photo/4162595/ |
| `rowing-machine-1` | 6551064 | Andres Ayrton | https://www.pexels.com/photo/6551064/ |
| `butterfly-stretch-1` | 7593065 | (photographer TBD) | https://www.pexels.com/photo/7593065/ |
| `seated-forward-fold-1` | 6454092 | (photographer TBD) | https://www.pexels.com/photo/6454092/ |
| `quad-stretch-standing-1` | 4426393 | Ketut Subiyanto | https://www.pexels.com/photo/4426393/ |
| `standing-hamstring-stretch-1` | 4908627 | (photographer TBD) | https://www.pexels.com/photo/4908627/ |
| `standing-calf-raise-1` | 13965339 | (photographer TBD) | https://www.pexels.com/photo/13965339/ |
| `lateral-lunge-1` | 29881486 | (photographer TBD) | https://www.pexels.com/photo/29881486/ |
| `supine-twist-1` | 7592444 | (photographer TBD) | https://www.pexels.com/photo/7592444/ |
| `dynamic-lunge-1` | 4498178 | Karolina Grabowska | https://www.pexels.com/photo/4498178/ |
| `doorway-chest-stretch-1` | 4720286 | Ketut Subiyanto | https://www.pexels.com/photo/4720286/ |
| `neck-side-stretch-1` | 8033048 | (photographer TBD) | https://www.pexels.com/photo/8033048/ |
| `tricep-overhead-stretch-1` | 6388359 | (photographer TBD) | https://www.pexels.com/photo/6388359/ |
| `cable-curl-1` | 29850900 | Foad Shariyati | https://www.pexels.com/photo/29850900/ |
| `cable-fly-1` | 10754972 | Ronin | https://www.pexels.com/photo/10754972/ |
| `cat-stretch-1` | 7663035 | Anastasia Shuraeva | https://www.pexels.com/photo/7663035/ |
| `cross-body-shoulder-stretch-1` | 8173417 | Kampus Production | https://www.pexels.com/photo/8173417/ |
| `decline-push-up-1` | 8401198 | RDNE Stock project | https://www.pexels.com/photo/8401198/ |
| `dip-1` | 4803710 | Ketut Subiyanto | https://www.pexels.com/photo/4803710/ |
| `dumbbell-romanian-deadlift-1` | 14604676 | viridianaor | https://www.pexels.com/photo/14604676/ |
| `dumbbell-walking-lunge-1` | 8846122 | Mart Production | https://www.pexels.com/photo/8846122/ |
| `forward-fold-1` | 17440584 | Vi Nguyen | https://www.pexels.com/photo/17440584/ |
| `goblet-squat-1` | 14020554 | Cesar Perez | https://www.pexels.com/photo/14020554/ |
| `knee-to-chest-1` | 7662437 | Anastasia Shuraeva | https://www.pexels.com/photo/7662437/ |
| `leg-extension-1` | 19722966 | Nikolai Veksharev | https://www.pexels.com/photo/19722966/ |
| `low-lunge-stretch-1` | 6303729 | Klaus Nielsen | https://www.pexels.com/photo/6303729/ |
| `pike-push-up-1` | 6388372 | Tima Miroshnichenko | https://www.pexels.com/photo/6388372/ |
| `seated-spinal-twist-1` | 4534688 | Vlada Karpovich | https://www.pexels.com/photo/4534688/ |
| `sphinx-pose-1` | 6958056 | Thirdman | https://www.pexels.com/photo/6958056/ |
| `tricep-pushdown-1` | 29084391 | Foad Shariyati | https://www.pexels.com/photo/29084391/ |
| `wide-push-up-1` | 4995975 | Valerie V | https://www.pexels.com/photo/4995975/ |
| `battle-ropes-1` | 7187951 | RDNE Stock project | https://www.pexels.com/photo/7187951/ |
| `calf-stretch-wall-1` | 5036898 | Ketut Subiyanto | https://www.pexels.com/photo/5036898/ |
| `elliptical-1` | 6285181 | Gustavo Fring | https://www.pexels.com/photo/6285181/ |
| `seated-hamstring-stretch-1` | 4422914 | Maksim Goncharenok | https://www.pexels.com/photo/4422914/ |
| `shadow-boxing-1` | 5320034 | cottonbro studio | https://www.pexels.com/photo/5320034/ |
| `sprinting-1` | 31675724 | Ciro Palomba | https://www.pexels.com/photo/31675724/ |
| `standing-side-bend-1` | 5331224 | Monstera Production | https://www.pexels.com/photo/5331224/ |
| `heavy-bag-boxing-1` | 7991688 | (photographer TBD) | https://www.pexels.com/photo/7991688/ |
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

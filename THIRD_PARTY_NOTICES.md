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

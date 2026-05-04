# Third-Party Notices

This file lists third-party works whose ideas, design patterns, or specifications inspired parts of WorkoutKit.

WorkoutKit does not bundle or redistribute any third-party code or art. The notices below are provided as design-credit / acknowledgement only.

---

## workout-cool

- **Project**: [Snouzy/workout-cool](https://github.com/Snouzy/workout-cool)
- **Author**: Mathias Bradiceanu
- **License**: MIT License
- **Used for**: Reference for the body-diagram muscle-selection UX in `WorkoutKit/Features/Builder/BodyDiagram/`. The 5-attribute exercise schema (TYPE / PRIMARY_MUSCLE / SECONDARY_MUSCLE / EQUIPMENT / MECHANICS_TYPE), `slug`-based identifiers, and the front/back tappable body-diagram interaction pattern were inspired by this project (see `src/features/workout-builder/ui/muscle-selection.tsx`).
- **Code reused**: None. All SwiftUI `Path` data, silhouette geometry, and muscle region shapes in `BodyDiagramShapes.swift` were drawn from scratch for this project. The exercise seed JSON is original WorkoutKit content.

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

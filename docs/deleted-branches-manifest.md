# 削除ブランチ manifest

> 2026-07-11 08:12 UTC 時点で mainline (`claude/init-workoutkit-ios-YHots`) 以外の全リモートブランチを削除した記録。
> 各 tip SHA は GitHub が保持している間 `git fetch origin <SHA>` で復元可能。
> 全ブランチの価値ある作業は mainline に反映済み(照合レポート参照)。

| branch | tip SHA | base への未マージ commit 数 |
|---|---|---|
| chore/cleanup-and-tests | 3b8066f | 1 |
| cleanup/remove-stick-figure-animation | 07030bf | 0 |
| debug/comprehensive-pass | a535b23 | 1 |
| docs/app-store-metadata | 0dbcaaf | 0 |
| docs/legal-privacy-terms | 504d57b | 0 |
| docs/release-notes-and-review | 7a7f5d2 | 0 |
| feature/A2-seed-expansion | 577962f | 0 |
| feature/B1-workout-generator | 16e848a | 1 |
| feature/B2-builder-wizard | d919eb2 | 1 |
| feature/D3-manual-entry | 06d5a58 | 9 |
| feature/annotated-form-view | c41f730 | 1 |
| feature/annotations-all-345 | 094b4a8 | 0 |
| feature/app-store-screenshots | d3b3500 | 0 |
| feature/body-diagram-2row-layout | 80b5d38 | 0 |
| feature/body-diagram-annotations | a037cc4 | 1 |
| feature/body-diagram-picker | 5e1c7db | 0 |
| feature/body-diagram-v2-anatomical | ae8a438 | 0 |
| feature/exercise-animation-prototype | ae20a52 | 0 |
| feature/exercise-detail-body-diagram | 09d9f57 | 0 |
| feature/steps-mistakes-cards | d05a122 | 0 |
| feature/v0.5-subscription-pivot | 27b0850 | 23 |
| fix/back-section-cues | bf3eb75 | 0 |
| fix/body-diagram-bigger-layout | 9f84f18 | 0 |
| fix/builder-session-settings-ux | 594514a | 0 |
| fix/debug-critical-session-history | 578c6f4 | 0 |
| fix/debug-major-minor | 2493225 | 0 |
| fix/draw-things-api | f0da1ac | 0 |
| fix/missing-localizations | 9d26de3 | 0 |
| fix/remove-unimplemented-pro-features | 59db696 | 0 |
| fix/terminology-and-html-render | 998b072 | 2 |
| fix/terminology-cleanup | 608d8e9 | 1 |
| fix/three-real-bugs | 741a924 | 2 |
| fix/v1-polish | 6cc8415 | 0 |
| fix/widget-and-text-localizations | 0fe874a | 3 |
| integration/all-features-clean | 0fe874a | 3 |
| qa/a11y-and-network | 5cbfa6d | 1 |
| qa/post-purchase-verification | 94548b7 | 0 |
| qa/pre-release-audit | 0b2369e | 1 |
| qa/remaining-items-check | a8032cc | 0 |
| qa/robustness-stress-and-recovery | f3691b4 | 1 |
| qa/xcode-runtime-check | da22c40 | 1 |
| research/exercise-animation-quality | cd621d0 | 1 |
| research/free-exercise-assets | 08bb07f | 1 |
| sample/2d-lottie-prototype | dec5fbb | 1 |
| sample/3d-realitykit-prototype | 798e3b5 | 1 |
| sample/exercise-detail-body-diagram | 3512142 | 2 |
| task/ci-release-audit | 68d7a78 | 0 |
| task/docs-audit-v1 | 7900ba1 | 0 |
| task/m6-screenshots-en | d84c639 | 0 |
| task/privacy-manifest-review | a611c96 | 0 |
| task/swift6-warnings | 94a3967 | 0 |
| tools/stable-diffusion-setup | b51520c | 0 |

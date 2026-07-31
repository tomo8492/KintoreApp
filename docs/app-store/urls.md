# App Store Connect — URL fields

> v1.0 launch values (filled). Defaults below point at the GitHub Pages
> location (`tomo8492.github.io/KintoreApp/legal/`). If a custom domain
> (e.g. `workoutkit.app`) is provisioned later, replace these in one pass.

| Field | Required | Value | Source |
|---|---|---|---|
| Support URL              | ✅ | `mailto:tomo060213@gmail.com`                                                | tomo's personal mail (single-person dev) |
| Marketing URL            | optional | `https://github.com/tomo8492/KintoreApp` (currently private — leave blank in ASC if repo stays private) | replace with landing page when domain ships |
| Privacy Policy URL       | ✅ | `https://tomo8492.github.io/KintoreApp/legal/privacy-policy.html`            | hosted from `docs/legal/privacy-policy.html` via GitHub Pages |
| Terms of Use URL (EULA)  | optional | `https://tomo8492.github.io/KintoreApp/legal/terms-of-service.html`          | hosted from `docs/legal/terms-of-service.html`; if blank, Apple's standard EULA applies |
| Copyright                | ✅ | `© 2026 Tomo`                                                                | individual developer name; should match the legal name on Apple Developer enrollment |

English variants live next to the Japanese ones:
- `https://tomo8492.github.io/KintoreApp/legal/privacy-policy.en.html`
- `https://tomo8492.github.io/KintoreApp/legal/terms-of-service.en.html`

App Store Connect's localised metadata (en-US) should reference these
`.en.html` versions; ja-JP metadata uses the un-suffixed `.html` versions.

## Where these values live in code

- The URLs live in `project.yml`, on the `WorkoutKit` app target's
  `info.properties` (`WKPrivacyPolicyURL` / `WKTermsOfUseURL`), and are
  read at runtime via `SettingsLinks` in
  `WorkoutKit/Features/Settings/SettingsView.swift`. Both `SettingsView`
  and `PaywallView` reuse `SettingsLinks` for their legal-link rows. If a
  custom domain ships, update the two `info.properties` values in
  `project.yml` in one place.
- `docs/app-store/{ja,en}/description.txt` — support email.
- `docs/app-store/app-review-notes.md` — reviewer-facing email + URLs.
- `docs/legal/*.md` and `docs/legal/*.html` — author/email/copyright in
  the document bodies.

## Publishing the legal pages

1. Enable GitHub Pages on the `claude/init-workoutkit-ios-YHots` branch
   (or `main` after merge) with `docs/` as the source folder.
2. Visit the four URLs to confirm 200 OK.
3. (Optional) If you later acquire `workoutkit.app`, add a `docs/legal/CNAME`
   file and switch the placeholder URLs to that domain in the locations
   above.

## TODO before App Store submission (M9)

1. Confirm Apple Developer enrollment legal name matches `Tomo` (the
   Copyright field), or update Copyright accordingly.
2. Verify the four `tomo8492.github.io/.../...html` URLs return 200 OK
   after Pages is enabled.
3. Re-run xcodebuild build / test → push the URL-update commit (already
   covered by the v1.0 placeholder-fill commit).

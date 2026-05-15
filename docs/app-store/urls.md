# App Store Connect — URL fields

> Each value is a placeholder until Apple Developer enrollment closes (Phase P-1)
> and the workoutkit.app domain / mailbox are provisioned. **All five must be
> finalised before the first App Store submission.**

| Field | Required | Placeholder | Final source |
|---|---|---|---|
| Support URL              | ✅ | `mailto:[YOUR_EMAIL]`               | tomo's support email or a static support page |
| Marketing URL            | optional | `https://github.com/tomo8492/KintoreApp` (private) — leave blank if private | landing page once domain ships |
| Privacy Policy URL       | ✅ | `https://workoutkit.app/privacy`    | hosted privacy.html (separate task) |
| Terms of Use URL (EULA)  | optional | `https://workoutkit.app/terms`      | hosted terms.html, otherwise Apple's standard EULA applies |
| Copyright                | ✅ | `© 2026 [YOUR_NAME]`                | individual developer name as on Apple Developer enrollment |

## Where the placeholders live in code

- `WorkoutKit/Features/Paywall/PaywallLegalSection.swift`
  (`placeholderTermsURL`, `placeholderPrivacyURL` — flagged with 🚨 RELEASE BLOCKER 🚨).
  Current defaults point at `https://workoutkit.app/terms` and
  `https://workoutkit.app/privacy`; the GitHub Pages fallback
  (`https://tomo8492.github.io/KintoreApp/legal/{terms-of-service,privacy-policy}.html`)
  is documented in-source as a comment.

The rendered legal pages live under `docs/legal/` (`*.md` source +
`*.html` published copy). To publish on GitHub Pages, enable Pages on
the `main` branch with `docs/` as the source folder. Custom domain wiring
goes in `docs/legal/CNAME` once `workoutkit.app` is provisioned.

## After they're finalised

1. Replace the two `placeholderXxxURL` constants in PaywallLegalSection.swift.
2. Regenerate `docs/legal/*.html` from the updated `*.md` source
   (current dates are stale on the published HTML — keep them in sync).
3. Update `[YOUR_EMAIL]` in `docs/app-store/{ja,en}/description.txt`
   and `docs/app-store/app-review-notes.md` (search for the literal token
   and replace).
4. Update `[YOUR_NAME]` in this file's Copyright row and in
   `app-review-notes.md`'s signature line.
5. Re-run xcodebuild build / test → push the URL-update commit.

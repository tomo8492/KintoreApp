# ASC Privacy "Nutrition Label" Cheat Sheet — WorkoutKit v1.0

> Authored 2026-05-16 for App Store Connect "App Privacy" submission.
> Use this file as a printable answer key while you walk through the ASC
> wizard. Every Yes/No below is grounded in actual source-tree audit, not
> in marketing copy.
>
> Scope: **v1.0** (subscription pivot landed on `claude/init-workoutkit-ios-YHots`,
> RevenueCat 5.x wired through `Features/Paywall/PurchaseManager.swift`).
>
> Sources of truth used to derive this sheet:
>
> - `WorkoutKit/Resources/PrivacyInfo.xcprivacy`
> - `docs/legal/privacy-policy.md` / `docs/legal/privacy-policy.en.md`
> - `WorkoutKit/Features/Paywall/PurchaseManager.swift` (RevenueCat surface)
> - `WorkoutKit/Features/DataIO/HistoryExporter.swift`
> - `Config/Shared.xcconfig` (Info.plist keys, no usage descriptions)
> - grep over `WorkoutKit/`, `WorkoutKitWatch/`, `WorkoutKitLiveActivity/`
>   for HealthKit / AVCapture / CLLocation / CNContact / PHPhotoLibrary /
>   AVAudioRecord / UNUserNotification / URLSession

---

## TL;DR — what to click in ASC

1. **Do you or your third-party partners collect data from this app?** → **Yes**
   (RevenueCat collects Purchase History and a vendor-generated Anonymous ID
   on the developer's behalf — Apple's App Privacy rules count this as
   *the developer's* collection, even though no app code calls a server
   directly.)
2. Declare two data types: **Purchases → Purchase History**, **Identifiers → User ID**.
3. For both: linked to identity = **No**. Used for tracking = **No**.
4. Privacy Policy URL → already locked in `docs/app-store/urls.md`.

Estimated time in ASC UI from a cold start: **20–30 min** (most of it spent
re-reading Apple's category descriptions and double-checking RevenueCat's
recommended answers). Allow another 10 min if you also re-enter the
Privacy Choices Disclosure URL.

---

## 1. ASC UI walkthrough (screen-by-screen)

> Path is current as of ASC 2026-05 layout. If Apple moves things around,
> the anchor is always the app record → left-nav **Privacy** section.

| Step | Where you are | What to do |
|---|---|---|
| 1.1 | App Store Connect → **My Apps** → *WorkoutKit* | Open the app record. |
| 1.2 | Left nav → **App Privacy** | Click **Get Started** (first-time) or **Edit** next to "Data Types" (re-edit). |
| 1.3 | "Do you or your third-party partners collect data from this app?" | **Yes**. (RevenueCat = third-party partner.) |
| 1.4 | "Privacy Choices URL" (optional) | Leave **blank**. We do not expose user-facing privacy choices (no account, no opt-out toggles beyond OS-level). |
| 1.5 | Data Types selection grid | Tick the two boxes listed in §2 below. Leave every other category unticked. |
| 1.6 | For each ticked category, ASC asks four follow-up questions | See per-row config in §2. |
| 1.7 | "Privacy Policy URL" field (separate from Data Types, lives under **App Information** → **General Information**) | Paste `https://tomo8492.github.io/KintoreApp/legal/privacy-policy.en.html` for the English locale, `…/privacy-policy.html` for the Japanese locale. Already canonicalised in `docs/app-store/urls.md`. |
| 1.8 | "Publish" the privacy form | ASC will then unlock the app submission flow. Required before any binary upload review can finish. |

---

## 2. Data Types matrix (the actual answers)

> **Legend**
>
> - **Collect?** — does the app or any embedded SDK ship this data off-device?
> - **Purpose** — Apple's predefined purpose categories. Pick the narrowest
>   honest one.
> - **Linked to user?** — "Yes" means Apple considers the data tied to an
>   identifiable individual (account / email / phone / payment / device-tied
>   identifier used to identify a *person*). RevenueCat's anonymous ID is
>   per-install and not linked to a real-world identity, so this stays **No**.
> - **Tracking?** — "Yes" means the data is used to follow the user across
>   apps/sites owned by other companies, or shared with a data broker.
>   We do neither, so this stays **No** everywhere.

### 2.1 Categories to declare (tick these)

| ASC Category | ASC Sub-type | Collect? | Purpose | Linked to user? | Tracking? | Why |
|---|---|---|---|---|---|---|
| **Purchases** | **Purchase History** | ✅ Yes | App Functionality | ❌ No | ❌ No | RevenueCat receives the StoreKit transaction so it can resolve the `premium` entitlement (`Purchases.shared.customerInfo()` / `.purchase(...)` / `.restorePurchases()` in `PurchaseManager.swift`). The receipt itself is processed by Apple; RevenueCat stores a record of which products this install owns, keyed by an anonymous ID. |
| **Identifiers** | **User ID** | ✅ Yes | App Functionality | ❌ No | ❌ No | RevenueCat generates a `$RCAnonymousID:*` per install and uses it as the lookup key for the entitlement record above. It is **not** the device IDFV/IDFA and is not linked to email/name/phone (we never set `Purchases.shared.logIn(...)` or `.setAttributes(...)`). |

### 2.2 Categories to leave unticked (sanity list — everything below must stay **No**)

| ASC Category | Why "No" is correct |
|---|---|
| **Contact Info** (Name, Email, Phone, Address, Other) | No account, no sign-in. Grep confirms no `CNContact*` import anywhere. |
| **Health & Fitness** (Health, Fitness) | No HealthKit linkage in v1.0. `Info.plist` has no `NSHealthShareUsageDescription` (verified via `grep INFOPLIST_KEY` in `Config/Shared.xcconfig`). All workout records live in SwiftData on-device only. SwiftData persistence is **not** "collection" per Apple's definition (data never leaves the device). |
| **Financial Info** (Payment Info, Credit Info, Other) | Apple/StoreKit handles all payment data. RevenueCat sees Apple's transaction receipts, not card numbers. |
| **Location** (Precise, Coarse) | No `CoreLocation` / `CLLocation*` usage anywhere. |
| **Sensitive Info** | None collected. |
| **Contacts** | No contacts access. |
| **User Content** (Photos/Videos, Audio, Gameplay Content, Customer Support, Other) | Pro feature "Photos & notes" exists in the localizable strings but is gated and **does not upload** — content stays in SwiftData (see Pro feature gate in `Features/Paywall/ProFeatureGate.swift`). Same for session notes. |
| **Browsing History** | App does no browsing. |
| **Search History** | In-app search is local-only; SwiftData query, never transmitted. |
| **Identifiers → Device ID** | RevenueCat 5.x does **not** collect IDFV unless `Purchases.shared.collectDeviceIdentifiers()` is called. `PurchaseManager.swift` does not call it. Verified via grep. |
| **Purchases → Other Purchase Activity** | Only purchase records relevant to the `premium` entitlement are tracked. No cross-app purchase profiling. |
| **Usage Data** (Product Interaction, Advertising Data, Other) | No analytics SDK. CLAUDE.md §-1.11 lock. No `URLSession` calls anywhere in app code. |
| **Diagnostics** (Crash, Performance, Other Diagnostic) | We rely on Apple's built-in crash reporting via Xcode Organizer, which is *Apple-collected* and explicitly **exempt** from App Privacy disclosure (Apple "App Privacy details" FAQ, 2022). No Sentry/Crashlytics. |
| **Surroundings / Body / Other** | None. |

> ⚠️ **Reviewer hint for the Health & Fitness category:** App Store reviewers
> sometimes flag fitness apps that declare "no Health & Fitness data" because
> they expect HealthKit. The app review note in `docs/app-store/app-review-notes.md`
> already explains "no HealthKit in v1.0, all data is on-device SwiftData."
> Keep that note in sync if you ever change the answer here.

---

## 3. Privacy Manifest (`PrivacyInfo.xcprivacy`) declarations

Current state of `WorkoutKit/Resources/PrivacyInfo.xcprivacy`:

| Key | Value | Source |
|---|---|---|
| `NSPrivacyTracking` | `false` | hard-coded; matches §2 "Tracking? = No everywhere" |
| `NSPrivacyTrackingDomains` | (empty array) | matches above |
| `NSPrivacyCollectedDataTypes` | (empty array) | **see §4 flag #1 — likely intentional but worth re-reading Apple's intent** |
| `NSPrivacyAccessedAPITypes[0]` | `NSPrivacyAccessedAPICategoryUserDefaults` / reason `CA92.1` ("Access info from same app, per documentation") | covers `UserDefaults.standard` in `SettingsKeys.swift`, `TemplateSeeder.swift`, `LaunchTrialTracker.swift`, plus App Group `UserDefaults(suiteName:)` in `Shared/WatchSummaryBridge.swift` |
| `NSPrivacyAccessedAPITypes[1]` | `NSPrivacyAccessedAPICategoryFileTimestamp` / reason `C617.1` ("Inside the app or group, with the user's consent") | **see §4 flag #2 — no actual source-code use detected** |

### Required-Reason API coverage check (per Apple's May 2024 enforcement list)

| Apple Category | Used in app code? | Currently declared? | Action |
|---|---|---|---|
| `UserDefaults` | ✅ Yes (heavy) | ✅ Yes | OK |
| `FileTimestamp` (`creationDate` / `modificationDate` / `URLResourceKey.contentModificationDateKey` / `attributesOfItem(atPath:)`) | ❌ Not found in grep over `*.swift` | ⚠️ Yes (declared) | **Flag #2** — decide: remove the declaration, OR add a timestamped export filename to make it true |
| `SystemBootTime` (`systemUptime`, `mach_absolute_time`) | ❌ Not used directly (Swift Concurrency `Clock` is covered by Swift runtime, not the app) | ❌ No | OK |
| `DiskSpace` (`volumeAvailableCapacity*`) | ❌ Not used | ❌ No | OK |
| `ActiveKeyboards` | ❌ Not used | ❌ No | OK |

> The `PrivacyInfo.xcprivacy` declarations cover only **first-party** code.
> RevenueCat's SDK ships its **own** bundled `PrivacyInfo.xcprivacy` inside
> the framework, so we don't need to mirror RevenueCat's API uses in ours.
> If you ever copy code out of the RevenueCat package and inline it,
> revisit this assumption.

---

## 4. Discrepancies & open flags (resolve before submission)

Each flag below is **read-only documentation** for tomo. No source edits
were made in this branch.

### Flag #1 — `NSPrivacyCollectedDataTypes` is empty in the manifest, but ASC declares two data types

`PrivacyInfo.xcprivacy` currently declares `NSPrivacyCollectedDataTypes`
as an empty array. Apple's official rule: this key in the manifest is
**informational** for app developers and reviewers; the **authoritative**
declaration is in App Store Connect's App Privacy section. The two
locations should agree.

- **Recommended fix:** add Purchases→Purchase History and Identifiers→User
  ID to the manifest array as well, so the on-device file and the ASC
  declaration tell the same story. See Apple's
  ["Describing data use in privacy manifests"](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
  for the exact dict shape (`NSPrivacyCollectedDataTypeIdentifiers` etc.).
- **Risk if you skip:** Low for review approval, but Apple's static
  scanner may diff the two and surface a warning in the next review cycle.

### Flag #2 — `NSPrivacyAccessedAPICategoryFileTimestamp` declared but not used

The XML comment at the top of `PrivacyInfo.xcprivacy` says the
declaration covers "エクスポートファイル名生成" (export filename generation),
but `HistoryExporter` writes a **static** filename:

```swift
// WorkoutKit/Features/DataIO/DataIOView.swift:74
defaultFilename: "workoutkit-history"
```

No code under `WorkoutKit/`, `WorkoutKitWatch/`, or `WorkoutKitLiveActivity/`
calls any `FileTimestamp` Required-Reason API (verified with
`grep -rIn 'FileManager\|attributesOfItem\|contentModificationDateKey\|creationDate' --include="*.swift"`,
zero hits).

- **Option A (recommended)**: drop the `FileTimestamp` entry from the
  manifest — fewer declarations is better, and reviewers occasionally ask
  "why is this here" for unused reasons. This is the cleaner choice.
- **Option B**: leave it, on the theory that you plan to add a
  `workoutkit-history-2026-05-16.csv` style filename later. If you go
  this route, also update the XML comment from "エクスポートファイル名生成"
  to something like "予約済み: F-06 タイムスタンプ付きエクスポート(v1.1+)".

### Flag #3 — Privacy Policy mentions local notifications; source code does not implement them

`docs/legal/privacy-policy.md` §3 and `privacy-policy.en.md` §3 say:

> The App uses local notifications (`UNUserNotificationCenter`) for
> interval timer end notifications during workouts.

But grep finds **zero** uses of `UNUserNotificationCenter` /
`UNNotificationRequest` / `UNUserNotifications` across the app, watch,
and Live Activity targets. v1.0 uses **Live Activities** (`ActivityKit`)
for the interval/session UI instead — see
`WorkoutKit/Features/Session/SessionStore+LiveActivity.swift`.

- **Recommended fix:** strike the local-notification paragraph from both
  language versions of the privacy policy, and remove "Local Notifications"
  from §4 Device Permissions / "Permission" table. Replace it with
  Live Activities only (already mentioned as the second row).
- **Risk if you skip:** ASC review can compare the in-app permission
  prompts to the privacy policy. Saying you use a permission you don't
  request is harmless to data privacy but is a reviewer red flag for
  "stale documentation" — Guideline 5.1.1(i).

### Flag #4 — Privacy Policy still has `XX-XX` placeholder dates

`privacy-policy.md` and `privacy-policy.en.md` both still show:

```text
**Last Updated**: 2026-XX-XX
**Initial Release**: 2026-XX-XX
```

These need real dates before the v1.0 ASC submission. Mirror them in
both files (Japanese policy is the canonical legal version; the English
file follows). After dating, re-run the GitHub Pages HTML regeneration
(`docs/legal/*.html`) to keep the hosted pages in sync.

### Flag #5 — RevenueCat is mentioned in Privacy Policy §5, but only in passing in `PrivacyInfo.xcprivacy`

This is **not** a defect — `PrivacyInfo.xcprivacy` is only for *your* code, and RevenueCat ships its own manifest inside the framework. Just calling
it out so a future maintainer doesn't "fix" it.

If you later switch RevenueCat off and inline the StoreKit calls, you'll
need to:

1. Remove §5's RevenueCat paragraph from both Privacy Policy files.
2. Re-evaluate whether Purchase History / User ID should still be ticked
   in ASC (probably not — Apple's own StoreKit handling is exempt).

---

## 5. Cross-references

| Need to confirm… | Look at |
|---|---|
| What the manifest currently declares | `WorkoutKit/Resources/PrivacyInfo.xcprivacy` |
| What we tell the user | `docs/legal/privacy-policy.md` (canonical, JA) and `docs/legal/privacy-policy.en.md` (EN translation) |
| Hosted Privacy Policy URLs | `docs/app-store/urls.md` |
| What we tell the reviewer | `docs/app-store/app-review-notes.md` → "Privacy and Terms" section |
| Where RevenueCat actually runs | `WorkoutKit/Features/Paywall/PurchaseManager.swift` |
| RevenueCat key handling (Info.plist injection) | `Config/Shared.xcconfig` + `WorkoutKit/Shared/AppSecrets.swift` |
| StoreKit configuration (Sandbox) | `WorkoutKit/Resources/WorkoutKit.storekit` |

### Privacy Policy clause anchors

- Japanese: [`docs/legal/privacy-policy.md`](../legal/privacy-policy.md)
  - §2.1 "私たちが収集しない情報" — matches the §2.2 "leave unticked" list in this doc
  - §2.2 "端末内にのみ保存される情報" — backs up "SwiftData = no collection"
  - §3 "通知について" — **see Flag #3**, currently inaccurate
  - §4 "端末の権限(Permissions)" — backs up §2 "leave unticked" list
  - §5 "第三者サービス・SDK" — backs up the RevenueCat-only declaration
- English: [`docs/legal/privacy-policy.en.md`](../legal/privacy-policy.en.md)
  - §2.1, §2.2, §3, §4, §5 — same structure as the Japanese version

---

## 6. ASC-side time estimate breakdown

| Sub-task | Estimated time |
|---|---|
| Read this file end-to-end before opening ASC | 5 min |
| Click through the App Privacy wizard following §1 | 8 min |
| Resolve Flags #3 and #4 in `docs/legal/` and re-deploy GitHub Pages | 10 min |
| Decide and apply Flag #1 + Flag #2 in `PrivacyInfo.xcprivacy` | 5 min |
| Re-archive build (if manifest edited) and re-validate | 8 min |
| **Total (worst case, all flags resolved)** | **≈ 35 min** |
| **Total (just the ASC wizard, defer flags to a follow-up)** | **≈ 15 min** |

The flags above don't block ASC submission per se — App Store Connect
will happily accept the declarations regardless of what
`PrivacyInfo.xcprivacy` says. But if you want a clean v1.0 audit trail
(and not have to file a Resolution Center reply later about why the
privacy policy mentions a permission the app doesn't request), close
Flags #1–#4 before submission.

---

## 7. 整合チェック 2026-05-16(3-file cross-audit)

Re-ran the audit after worker commits `a8f406f` (manifest cleanup) and
`e63df66` (legal-doc fixes). The three sources of truth are now compared
head-to-head:

- `WorkoutKit/Resources/PrivacyInfo.xcprivacy` (on-device manifest)
- `docs/app-store/privacy-nutrition-label.md` (this file — ASC cheat sheet)
- `docs/legal/privacy-policy.md` and `docs/legal/privacy-policy.en.md`
  (user-facing legal text, with HTML rendered copies under `docs/legal/*.html`)

### 7.1 Data Type alignment

| Topic                                | Manifest                          | This cheat sheet                  | Legal docs (§5)                                      | Status |
|--------------------------------------|-----------------------------------|-----------------------------------|------------------------------------------------------|--------|
| `NSPrivacyTracking`                  | `false`                           | "Tracking? No everywhere"         | "no tracking" (§5)                                   | ✅ aligned |
| `NSPrivacyCollectedDataTypes`        | `[]` (empty)                      | declares 2 types (RC-driven)      | RC mentioned in §5; data types listed in §2.3 table | ⚠ Flag #1 still open — see §4 above |
| Purchase data sent off-device        | (n/a — manifest covers app code only) | Purchases→Purchase History (Yes) | "RevenueCat handles receipt + anonymous ID" (§5)    | ✅ aligned |
| `$RCAnonymousID:*` user identifier   | (n/a)                             | Identifiers→User ID (Yes)         | Explicitly named in §5                              | ✅ aligned |
| Linked to identity                   | (n/a)                             | No (anonymous, never `logIn`'d)   | "no PII transmitted" (§5)                           | ✅ aligned |

### 7.2 Required-Reason API alignment

| API category   | Source code uses?      | Manifest declares? | Cheat sheet says?      | Status |
|----------------|------------------------|--------------------|------------------------|--------|
| `UserDefaults` | ✅ yes (heavy)         | ✅ `CA92.1`        | OK (§3)                | ✅ aligned |
| `FileTimestamp`| ❌ no (grep clean)     | ❌ removed in `a8f406f` | Flag #2 marked resolved (now noted as ✅) | ✅ aligned — see §7.5 below |
| `SystemBootTime` / `DiskSpace` / `ActiveKeyboards` | ❌ no | ❌ no | "OK" in §3 table       | ✅ aligned |

### 7.3 Notification framing alignment

| Where                                                    | Current wording                                          |
|----------------------------------------------------------|----------------------------------------------------------|
| Source code                                              | No `UNUserNotificationCenter` usage; `ActivityKit` only |
| `privacy-policy.md` §3                                   | "v1.0 時点で UNUserNotificationCenter を使用していません" + Live Activities |
| `privacy-policy.en.md` §3                                | "the App does not use the User Notifications framework" + Live Activities |
| `privacy-policy.md` §4 Permissions table                 | Lists Live Activities only (no UN row)                  |
| `privacy-policy.en.md` §4 Permissions table              | Lists Live Activities only                              |
| `privacy-policy.md` §5 third-party services list         | **fixed in this commit** — "Live Activities (ActivityKit)" replaces "Local Notifications" |
| `privacy-policy.en.md` §5 third-party services list      | **fixed in this commit** — "Live Activities (ActivityKit)" replaces "Local Notifications" |
| `privacy-policy.html` §5 summary paragraph               | **fixed in this commit** — same replacement, plus RevenueCat added to "third-party services" |
| `privacy-policy.en.html` §5 summary paragraph            | **fixed in this commit** — same replacement              |
| This cheat sheet §2 "Categories to leave unticked"       | No notification-related row — Apple does not surface "Notifications" as a data type, so no ASC implication |

> Closes the residual Flag #3 cleanup that worker `e63df66` started in
> the .md prose but missed in the .md §5 list and in the HTML mirrors.

### 7.4 RevenueCat anonymous-ID handling alignment

| Where                                            | Says                                                                                |
|--------------------------------------------------|-------------------------------------------------------------------------------------|
| `PurchaseManager.swift`                          | Never calls `Purchases.shared.logIn(...)` or `.setAttributes(...)`; never calls `collectDeviceIdentifiers()` |
| `privacy-policy.md` §5                           | "匿名 ID (`$RCAnonymousID:*`) を扱い、個人識別情報は本アプリから送信されません" |
| `privacy-policy.en.md` §5                        | "an anonymous ID (`$RCAnonymousID:*`); no personally identifiable information"     |
| Cheat sheet §2.1 (Identifiers→User ID row)       | "Not the device IDFV/IDFA; not linked to email/name/phone"                          |
| ASC declaration (per §2.1)                       | Identifiers→User ID = collected, Linked = No, Tracking = No                         |

All four sources are mutually consistent. ✅

### 7.5 Flag status after this audit

| Flag | 2026-05-16 status | Resolution path                                                                 |
|------|-------------------|---------------------------------------------------------------------------------|
| #1 NSPrivacyCollectedDataTypes empty | ⚠ Still open | Optional manifest entries; ASC declaration is authoritative. Low priority. |
| #2 FileTimestamp declared but unused | ✅ Resolved by worker `a8f406f` | Manifest no longer declares it. |
| #3 Policy mentions UN notifications  | ✅ Resolved | §3 + §4 fixed by `e63df66`; §5 list + HTML mirrors fixed by this commit. |
| #4 Placeholder XX-XX dates           | ✅ Resolved by worker `e63df66` | Real `2026-05-16` dates baked in. |
| #5 RevenueCat coverage note          | ✅ No action needed | SDK ships its own PrivacyInfo. |

Only Flag #1 remains, and it is a "nice-to-have" parity tweak rather than
a submission blocker.

### 7.6 Known divergence between `*.md` and `*.html`

> Out of scope for this consistency check — flagged for tomo's next legal
> regeneration pass.

The HTML mirrors under `docs/legal/*.html` were originally produced from
an older revision of the .md sources, then hand-tightened (you can tell
because they have `id="sec*"` anchors and condensed prose that pandoc
doesn't emit by default). After this commit they are consistent on the
notification-framing point, but they still differ from the .md in two
places that pre-date the v1.0 subscription pivot:

1. `privacy-policy.html` §2.3 table row still labels the IAP entry
   "App 内課金(Pro 解除)" instead of "App 内課金(プレミアム サブスクリプション)".
   Same in `privacy-policy.en.html` ("In-app purchase (Pro)").
2. The third-party SDK section in both HTML files is much shorter than
   the .md §5 — RevenueCat's anonymous-ID disclosure paragraph is not
   reproduced in the HTML, only summarised in the trailing one-liner.

These do **not** create a Foundation-Lock violation or a privacy
disclosure gap (the in-app About → Privacy link points to the HTML, so
users still see the correct legal text — they just see less of it than
the .md contains). Tomo should plan a single pandoc-or-manual
regeneration of the HTMLs before submission so the canonical .md and
hosted .html stay byte-traceable.

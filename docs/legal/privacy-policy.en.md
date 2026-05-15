# Privacy Policy

**App Name**: WorkoutKit (the "App")
**Provider**: Independent developer (the "Developer", "we", "us", or "our")
**Last Updated**: 2026-XX-XX
**Initial Release**: 2026-XX-XX
**Version**: 1.0

---

## 1. Introduction

We respect your privacy. This Privacy Policy explains what information the App handles and how it is protected.

The App is **designed to operate fully offline**. Your workout records and other personal information are **never transmitted to or collected by us**.

By downloading or using the App, you agree to the terms of this Privacy Policy. If you do not agree, please do not use the App.

---

## 2. Information We Do and Do Not Collect

### 2.1 Information We Do Not Collect

We do **not** collect any of the following:

- Your name, email address, phone number, or other contact information
- Profile information such as date of birth, gender, or address
- Location data (GPS, Wi-Fi, Bluetooth beacons, etc.)
- Data from other apps such as Contacts, Photos, Calendar, or Reminders
- Audio or video from camera or microphone
- Device identifiers, including the IDFA / IDFV advertising identifiers
- Usage logs, crash reports, or behavioral data (analytics)
- IP addresses or network information

The App has **no account registration or sign-in**, and contains no mechanism to identify individual users.

### 2.2 Information Stored Only on Your Device

The following information is stored **only on your device** (in SwiftData local storage) and is never transmitted externally:

- Workout menus and templates you create
- Workout records (sets, reps, weight, distance, time)
- History, goals, and favorite exercises
- App settings (units, theme, language, notifications, etc.)

This data is **yours**. When you delete the App, this data is removed from your device. (If iCloud Backup is enabled on your device, your data may be included in Apple's backup.)

### 2.3 Information Apple Processes (We Have No Access)

Because the App runs on Apple's platforms, the following data is processed by Apple, but **we cannot access individual user information**:

| Data                       | Processed By         | Our Access                                  |
| -------------------------- | -------------------- | ------------------------------------------- |
| In-app purchase (Premium subscription) | App Store / StoreKit | None (only purchase status known to App) |
| Receipts, payment info     | Apple                | None                                        |
| Aggregate reviews / ratings | App Store           | View only (no individual identification)    |
| App Analytics aggregates   | App Store Connect    | View aggregate only (no user identification) |
| Crash reports (opt-in)     | Apple                | View aggregate via Xcode Organizer (no user identification) |

For Apple's handling of data via the App Store and StoreKit, see [Apple Privacy Policy](https://www.apple.com/legal/privacy/).

---

## 3. Notifications

The App uses local notifications (`UNUserNotificationCenter`) for **interval timer end notifications** during workouts.

- Notifications are **opt-in** (your permission is requested on first use)
- All notification content is **generated locally** and is never transmitted from a server
- You can revoke permission at any time in iOS Settings
- The App does **not** use push notification services (APNs)

---

## 4. Device Permissions

The App requests the minimum permissions necessary:

| Permission         | Purpose                                            | Required / Optional |
| ------------------ | -------------------------------------------------- | ------------------- |
| Local Notifications | Interval timer end notifications                   | Optional            |
| Live Activities    | Show session progress on Lock Screen               | Optional            |
| Family Sharing     | Sharing the Premium subscription across family members | Optional        |

The App does **not** request any of the following:

- ❌ HealthKit (a future version may add this with a separate consent flow and updated Privacy Policy)
- ❌ Camera
- ❌ Microphone
- ❌ Location
- ❌ Contacts
- ❌ Photo Library
- ❌ Bluetooth
- ❌ Motion (steps, etc.)

---

## 5. Third-Party Services and SDKs

The App contains **no analytics, advertising, or social third-party SDKs**:

- ❌ No analytics SDKs (Google Analytics, Firebase, Mixpanel, etc.)
- ❌ No crash reporting SDKs (Crashlytics, Sentry, etc.)
- ❌ No advertising SDKs (AdMob, Meta Audience Network, etc.)
- ❌ No social login SDKs (Facebook, Google, etc.)

The only third-party SDK used by the App is **RevenueCat** for purchase processing:

- ✅ **RevenueCat** (purchase processing only): used to manage Premium subscription
  state (¥980/month / ¥4,900/year) routed through the App Store / StoreKit 2.
  RevenueCat handles the purchase receipt and an anonymous ID
  (`$RCAnonymousID:*`); no personally identifiable information such as your
  name or email address is transmitted from the App. RevenueCat's own data
  handling is governed by the
  [RevenueCat Privacy Policy](https://www.revenuecat.com/privacy).
  The App **disables** RevenueCat's attribution / analytics features
  (subscription state sync only).

The only third-party services the App interacts with are Apple and RevenueCat:

- **App Store / StoreKit**: Payment processing for the Premium subscription
- **Local Notifications**: On-device local notifications
- **iCloud Backup** (optional): If you have enabled iCloud Backup on iOS, App data may be included in Apple's backup.

---

## 6. Bundled Content Attribution

The App ships with 150+ exercises and SVG illustrations (the bundled exercise database grows over time):

- **Exercise data**: Created by the developer or compiled from public-domain sources
- **SVG illustrations**: Partially derived from [workout-cool](https://github.com/Snouzy/workout-cool) (MIT License)

See Settings → About → Third-Party Licenses in the App, or `THIRD_PARTY_NOTICES.md` in the repository, for details.

---

## 7. Children's Privacy (COPPA / Child Protection)

The App is not specifically targeted at children, and **does not include features or advertising directed at children under 13**. We do not knowingly collect personal information from children under 13. Children under 13 should use the App only with parental consent and supervision.

If we learn that personal information of a child under 13 has been collected, we will delete it promptly. Please contact us using the information at the bottom of this policy if you believe this has occurred.

---

## 8. Your Rights

Because we do not collect or hold your personal information, the typical data subject rights (access, rectification, erasure) are **fulfilled by deleting the App from your device**.

### 8.1 GDPR (EU General Data Protection Regulation)

If you reside in the EU, EEA, or UK, you have the following rights under GDPR:

- **Right of access / portability**: You can export your in-app data as CSV (Premium feature) from the Settings screen
- **Right to erasure / right to be forgotten**: Uninstalling the App via iOS standard procedures deletes all data from your device
- **Right to object**: We do not process your data, so there is no processing activity to object to

### 8.2 CCPA (California Consumer Privacy Act)

For California residents:

- We do **not sell** your personal information
- We do **not share** your personal information
- Disclosure, deletion, and opt-out requests are all fulfilled by deleting the App yourself

### 8.3 Act on the Protection of Personal Information (Japan)

For Japan residents:

- We do not collect "personal information" as defined in the Act on the Protection of Personal Information
- Data on your device belongs to you; we do not handle it
- For complaints, contact the Personal Information Protection Commission: [https://www.ppc.go.jp/](https://www.ppc.go.jp/)

### 8.4 Other Jurisdictions

If you have similar rights under other applicable laws, deleting the App from your device fulfills those rights. For additional matters, please contact us using the information at the bottom of this policy.

---

## 9. Data Retention

Because we do not retain personal information, retention periods do not apply to us.

Data on your device is retained until you delete it or uninstall the App.

---

## 10. International Data Transfers

We do not transfer your data internationally. All data stays on your device.

App Store / StoreKit transactions and iCloud Backup may be processed by Apple on servers around the world. Please refer to Apple's Privacy Policy for details.

---

## 11. Accessibility

The App supports the following accessibility features:

- VoiceOver (screen reader)
- Dynamic Type (text size scaling)
- Reduce Motion
- High Contrast
- Dark Mode

Enable these from iOS Settings → Accessibility.

---

## 12. Security

The App employs the following security measures:

- All data stays on your device; no network transmission occurs (except StoreKit communications)
- Security depends on standard iOS protections (passcode, Face ID / Touch ID, file protection class)
- App Transport Security (ATS) is enabled (only Apple-native traffic such as StoreKit is permitted, encrypted via TLS)

We cannot be held responsible for data leakage caused by loss of your device or third-party physical access. Please enable the device lock.

---

## 13. Changes to This Policy

We may revise this Privacy Policy from time to time. When we do:

1. The "Last Updated" date at the top of this document will be updated
2. Material changes will be communicated via in-app dialog at launch or in the App Store release notes
3. Continued use of the App after revisions constitutes acceptance of the revised policy

Past versions are available in this repository's Git history.

---

## 14. Contact

For questions or concerns about this Policy:

- **In the App**: Settings → About → Contact
- **Email**: `[YOUR_EMAIL]` (to be replaced)
- **GitHub**: [https://github.com/tomo8492/KintoreApp/issues](https://github.com/tomo8492/KintoreApp/issues)

We aim to respond within a few days to two weeks.

---

## 15. Governing Law

This Policy is governed by and construed in accordance with the laws of Japan.

---

## Revision History

| Version | Date         | Changes        |
| ------- | ------------ | -------------- |
| 1.0     | 2026-XX-XX   | Initial release |

---

> ⚠️ **Important Notice**
> This Policy is a template prepared in good faith by an independent developer. **It has not been reviewed by a legal professional.**
> We strongly recommend obtaining a review from a lawyer or privacy professional before commercial release.

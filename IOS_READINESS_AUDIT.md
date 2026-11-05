# iOS Readiness Audit

**Audit date:** 5 November 2026  
**App:** Loki Partnerz (BridalBooker Machine)  
**Flutter version:** 3.2.15+43  
**iOS bundle ID:** `com.lwv.bridalbookermachine`  
**Firebase project:** `lead-management-app-74c44`  
**Firebase iOS app ID:** `1:103543831309:ios:5abacb86219615daccce44`

## Verdict: continue from the existing iOS changes

Do **not** start over. The previous iOS work (commit `f8c1417`, 27 May 2026,
"android to ios code changes") is a coherent first pass and covers the hard
parts: bundle ID, Firebase, Facebook, notifications, platform guards, update
handling, account deletion, and App Store checklist.

The remaining problems are configuration and deployment issues, not a broken
architecture. A restart would throw away correct work and add risk.

Approximate state before this pass:

| Area | State | Verdict |
|---|---|---|
| Flutter iOS project (scene-based template) | Present | Keep |
| Bundle identifier / display name | `com.lwv.bridalbookermachine`, "Loki Partnerz" | Keep |
| Firebase iOS app + plist | Matches bundle ID | Keep (one config mismatch fixed) |
| FCM / APNs code | Dart side ready | Native capability + APNs key still needed |
| Notification permissions | iOS permission macro missing | Fixed |
| Razorpay on iOS | Correctly disabled | Keep |
| Play Store in-app update on iOS | Correctly guarded | Keep |
| Account deletion | UI present; production endpoint missing | Deploy endpoint |
| Version check | iOS row missing; `store_url` regression | Fixed in code + SQL |
| iOS subscription | External website link | Replaced with companion-only UI |
| Build config | iOS 13.0 vs Firebase iOS 15.0 | Fixed |
| App Store icon | 1024 px icon had alpha | Fixed |
| Privacy manifest | Missing | Added |
| `GoogleService-Info.plist` | Git-ignored | Un-ignored |

## What the previous iOS work already got right

- Set `PRODUCT_BUNDLE_IDENTIFIER` to `com.lwv.bridalbookermachine`.
- Set display name to **Loki Partnerz** and bundle name to `LokiPartnerz`.
- Added `GoogleService-Info.plist` to the Runner target.
- Added Facebook App Events keys and URL scheme to `Info.plist`.
- Added `UIBackgroundModes` → `remote-notification`.
- Added Darwin notification initialization and iOS foreground presentation.
- Guarded Android-only `in_app_update` so it never runs on iOS.
- Added platform-aware version checking (`platform=ios`).
- Added an in-app account-deletion flow for iOS.
- Added an iOS-oriented App Store checklist.

## Problems found and fixed in this pass

| # | Problem | Fix |
|---|---|---|
| 1 | `ios/Podfile` targeted iOS 13.0, but `firebase_core` / `firebase_messaging` 4.x require iOS 15.0. `pod install` would fail. | Podfile and Xcode deployment target set to 15.0. |
| 2 | `permission_handler` compiles no permission groups on iOS without Podfile macros. The notification banner would always show "disabled". | Added `PERMISSION_NOTIFICATIONS=1` macro in `post_install`. Also switched the status check to Firebase Messaging on iOS. |
| 3 | The 1024×1024 App Store icon had an alpha channel. App Store validation rejects transparent icons. | Flattened all app icons to RGB (white background). |
| 4 | No `PrivacyInfo.xcprivacy`; `shared_preferences` uses `UserDefaults`, which triggers an App Store privacy-manifest warning. | Added `ios/Runner/PrivacyInfo.xcprivacy` with the `CA92.1` UserDefaults reason. |
| 5 | `GoogleService-Info.plist` was ignored by `.gitignore`, so a Mac clone would not have it and the build would fail. | Un-ignored `ios/Runner/GoogleService-Info.plist`. Commit this file. |
| 6 | `firebase.json` pointed the iOS app at `...:ios:10dca50b3a60ab19ccce44`, while the plist and Dart options use `...:ios:5abacb86219615daccce44`. | Aligned `firebase.json` with the plist/Dart app ID. |
| 7 | `check_app_version.php` lost the `store_url` field in a later "pulled_api" commit (`b662491`). | Restored `store_url` and made a missing iOS row return a non-blocking response instead of HTTP 500. |
| 8 | No iOS row in `app_version_config`; production returns HTTP 500 for `platform=ios`. | Added a migration and admin support for an iOS version row. |
| 9 | Production `mobile_api/delete_account.php` returns HTTP 404. The iOS delete button would fail. | Code exists; **must be uploaded to production**. |
| 10 | iOS subscription page opened `lpz.lokiwebvibe.com`, an external purchase path. | Removed on iOS; replaced with a companion-app information card and support contact. |
| 11 | iOS still offered self-registration, which leads to a paywall with no purchase option. | Sign-up is hidden on iOS. |
| 12 | `dart:io` `Platform.isIOS` breaks the web target. | Replaced with `defaultTargetPlatform` checks. |

## Production checks performed

| URL | Result |
|---|---|
| `https://bbm.lokiwebvibe.com/privacy.html` | 200 OK |
| `https://bbm.lokiwebvibe.com/mobile_api/check_app_version.php?...&platform=android` | 200 OK |
| `https://bbm.lokiwebvibe.com/mobile_api/check_app_version.php?...&platform=ios` | **500** before fix; deploy the updated PHP + iOS row |
| `https://bbm.lokiwebvibe.com/mobile_api/delete_account.php` | **404**; deploy this file |
| `https://lpz.lokiwebvibe.com/` | 200 OK |
| `https://bbm.lokiwebvibe.com/subscriptions/get_subscription_plans.php` | 200 OK |

## App Store payment policy: important residual risk

The previous iOS implementation showed a "Visit Website" button that opened the
Razorpay subscription site. That is an external purchase mechanism for digital
features and violates Guideline **3.1.1**. It was removed.

The app is now a **companion app for existing subscribers**:

- No purchase UI on iOS.
- No external purchase link on iOS.
- Sign-up is hidden on iOS.
- Existing subscribers sign in and use the app.
- Support contact is available by email.

This is the fastest viable route, but it is not risk-free. Guideline
**3.1.3(b) (Multiplatform Services)** allows access to subscriptions acquired
elsewhere only when those items are **also available as in-app purchases**.
Apple may therefore reject a subscription-only companion app and ask for
StoreKit IAP. Be prepared for that outcome.

Recommended contingency, if App Review rejects the companion-only model:

1. Add Apple auto-renewable subscriptions with StoreKit (`in_app_purchase`).
2. Create matching App Store Connect products for each plan.
3. Add a server endpoint that validates Apple transactions and writes the same
   `subscription_history` / `users.level` data as the Razorpay flow.
4. Show localized StoreKit prices on iOS and keep Apple's restore-purchases
   requirement.

The existing subscription database schema is compatible with that work
(`subscription_plans`, `subscription_history`, `subscription_transactions`).

## What still must be done on a Mac / in Apple's portal

These cannot be completed from Windows:

- Enroll in the Apple Developer Program.
- Create the App ID and enable Push Notifications.
- Create an APNs key and upload it to Firebase Cloud Messaging.
- Open `ios/Runner.xcworkspace` and set the signing team.
- Add the Push Notifications and Background Modes capabilities.
- Run `pod install`.
- Build, test on a real iPhone and iPad, and archive.
- Create the App Store Connect record, screenshots, privacy answers, and submit.

See [IOS_PRODUCTION_GUIDE.md](IOS_PRODUCTION_GUIDE.md) for the step-by-step
production runbook.

## Recommendation

**Continue.** Finish the native signing, push, and deployment work described in
the production guide. Do not rewrite the iOS layer. If App Review rejects the
companion-only subscription model, implement StoreKit IAP as a phase-2 change
rather than reverting to the external website link.

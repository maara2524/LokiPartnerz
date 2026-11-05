# iOS Readiness Audit

**Audit date:** 5 November 2026  
**App:** Loki Partnerz (BridalBooker Machine)  
**App version:** 3.2.15+43
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
| Razorpay on iOS | Must remain disabled | Use StoreKit for iOS digital plans |
| Play Store in-app update on iOS | Correctly guarded | Keep |
| Account deletion | UI present; production endpoint missing | Deploy endpoint |
| Version check | iOS row missing; `store_url` regression | Fixed in code + SQL |
| iOS subscription | StoreKit fixed-term plans | StoreKit product lookup, signed transaction verification, and account restore wired |
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
| 10 | iOS subscription page opened `lpz.lokiwebvibe.com`, an external purchase path for digital services. | iOS now shows the same fixed-term plans and registration flow as Android, with StoreKit purchase and no Razorpay checkout or external purchase link. |
| 11 | iOS self-registration led to a paywall without an in-app purchase option. | Registration and `/Subscription` routes are enabled on iOS and use StoreKit. |
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

## App Store payments and commission

The iOS app now offers the same registration and fixed-term plan flow as Android,
but digital plan purchases use Apple's in-app purchase sheet. The iOS build must
not route a user to Razorpay or a website to pay for these digital features.

The existing plans have a `duration_days` term and do not renew automatically.
The iOS implementation therefore uses non-renewing subscription products,
shows the localized StoreKit price, verifies Apple's signed transaction on the
backend, and restores currently active access by the user's Loki Partnerz
account. A past, expired purchase must not grant a fresh term.

To reduce Apple's commission legally, enroll in the **App Store Small Business
Program** if eligible. Apple's current program page describes a 15% commission
for eligible developers with up to USD 1 million in annual proceeds, subject to
associated-account and agreement requirements. This is eligibility-dependent,
not guaranteed; check Apple's current terms before setting prices. The paid
Apple Developer Program membership, taxes, and local rules are separate.

App Review approval is never guaranteed. The owner must complete App Store
Connect agreements, provide accurate terms/privacy information, and test actual
products and account access before submission.

## What still must be done on a Mac / in Apple's portal

These cannot be completed from Windows:

- Enroll in the Apple Developer Program.
- Accept the Paid Apps agreement and complete banking and tax setup in App Store Connect.
- Apply for the App Store Small Business Program if eligible.
- Create non-renewing subscription products matching the two plans sold in the app.
- Create the App ID and enable Push Notifications.
- Create an APNs key and upload it to Firebase Cloud Messaging.
- Open `ios/Runner.xcworkspace` and set the signing team.
- Add the Push Notifications and Background Modes capabilities.
- Run `pod install`.
- Build and archive on the remote Mac; use the Simulator for UI/StoreKit tests
  and arrange a physical iPhone test for push notifications.
- Create the App Store Connect record, screenshots, privacy answers, and submit.

See [IOS_PRODUCTION_GUIDE.md](IOS_PRODUCTION_GUIDE.md) for the step-by-step
production runbook.

## Recommendation

**Continue.** Finish native signing, App Store Connect IAP setup, backend
deployment, and testing described in the production guide. Do not restore an
external Razorpay purchase link in the iOS app.

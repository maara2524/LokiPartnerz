# iOS App Store Mac Checklist

Use this when you move the project to a Mac for signing, device testing, and App Store upload.

## Apple Developer Portal

- Enroll in the Apple Developer Program.
- Create or verify the App ID for `com.lwv.bridalbookermachine`.
- Enable Push Notifications for the App ID.
- Create an APNs authentication key and upload it to Firebase Cloud Messaging.

## Xcode Project

- Run `flutter pub get` on the Mac once so `ios/Flutter/Generated.xcconfig` is created.
- From the `ios` folder, run `pod install` so Firebase, Facebook SDK, notifications, URL launcher, WebView, and other native iOS plugin pods are installed.
- Open `ios/Runner.xcworkspace`, not `Runner.xcodeproj`.
- Select the Runner target and set the Apple Developer Team.
- Confirm Bundle Identifier is `com.lwv.bridalbookermachine`.
- Enable Signing & Capabilities:
  - Push Notifications
  - Background Modes: Remote notifications
- Confirm `GoogleService-Info.plist` is included in the Runner target.
- Confirm the display name is `Loki Partnerz`.

## App Store Connect

- Create the app record with bundle ID `com.lwv.bridalbookermachine`.
- Privacy Policy URL: `https://bbm.lokiwebvibe.com/privacy.html`.
- Support URL: `https://bbm.lokiwebvibe.com/support.html` (upload `support.html` first).
- Add screenshots for required iPhone/iPad sizes.
- Add App Review demo login credentials (username, not email).
- Complete App Privacy details.
- Create Basic and Extended Basic as Non-Renewing Subscription products. Match
  their product IDs to the backend migration and set localized App Store prices.
- Complete the Paid Apps agreement, tax, and banking setup; enroll in the App
  Store Small Business Program if eligible.
- Confirm iOS uses StoreKit for plan purchases and has no Razorpay or external
  payment link for digital access.
- Add the iOS App Store URL to the backend app version config after the app record exists.

## Backend Before Submission

- Upload the updated `mobile_api/check_app_version.php`, `delete_account.php`, `admin/settings.php`, and `admin/settings_update_version.php`.
- Run `mobile_api/migrations/2026_11_05_add_ios_app_version.sql` on production.
- Run `mobile_api/migrations/2026_11_06_add_apple_iap.sql` once, after a database backup.
- Run `mobile_api/migrations/2026_11_07_add_account_deletion_audit.sql` after the Apple IAP migration.
- Configure a private `APPLE_IAP_TOMBSTONE_HMAC_KEY` (at least 32 random characters) and keep it stable for that database.
- Upload `subscriptions/get_subscription_plans.php`, `subscriptions/verify_apple_purchase.php`, `subscriptions/get_my_subscription.php`, `subscriptions/apple_iap_helpers.php`, and the updated `claim_leads.php`.
- Leave `APPLE_IAP_ALLOWED_ENVIRONMENT` at its default `Production` on the production server.
- Verify `check_app_version.php?platform=ios` returns HTTP 200.
- Verify `delete_account.php` returns 200, not 404.
- Test transaction verification against Sandbox on a separate staging backend.
- Verify `support.html` and `privacy.html` both return 200.
- Verify the live privacy policy matches actual app/backend data practices and
  the App Privacy details and privacy manifest have been reviewed against the
  final SDK set.

## Final Build

- Test registration, login, plan display, StoreKit sandbox purchase, account
  restore, notifications, deletion, printing, and video on the iOS Simulator or
  TestFlight.
- Validate push notifications on a real iPhone before release; simulator push
  behavior does not replace APNs testing.
- Archive from Xcode.
- Upload to App Store Connect.
- Submit TestFlight build for internal testing.
- Submit the app for App Review.

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
- Confirm the iOS build has no purchase button, no website purchase link, no subscription plans screen, and no sign-up entry.
- Add the iOS App Store URL to the backend app version config after the app record exists.

## Backend Before Submission

- Upload the updated `mobile_api/check_app_version.php`, `delete_account.php`, `admin/settings.php`, and `admin/settings_update_version.php`.
- Run `mobile_api/migrations/2026_11_05_add_ios_app_version.sql` on production.
- Verify `check_app_version.php?platform=ios` returns HTTP 200.
- Verify `delete_account.php` returns 200, not 404.
- Verify `support.html` and `privacy.html` both return 200.

## Final Build

- Test on a real iPhone (and iPad if the app stays universal).
- Test login, notifications, the companion subscription info card, account deletion, and the version check.
- Archive from Xcode.
- Upload to App Store Connect.
- Submit TestFlight build for internal testing.
- Submit the app for App Review.

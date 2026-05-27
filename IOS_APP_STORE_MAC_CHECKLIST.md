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
- Add Privacy Policy URL and Support URL.
- Add screenshots for required iPhone/iPad sizes.
- Add App Review demo login credentials.
- Complete App Privacy details.
- Confirm App Review compliance for the iOS website link before submission.
- Add the iOS App Store URL to the backend app version config after the app record exists.

## Final Build

- Test on a real iPhone.
- Test login, registration, notifications, account deletion, and the iOS website subscription link.
- Archive from Xcode.
- Upload to App Store Connect.
- Submit TestFlight build for internal testing.
- Submit the app for App Review.

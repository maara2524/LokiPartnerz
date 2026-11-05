# iOS Production Guide — Loki Partnerz

This is the end-to-end runbook for taking the Flutter app from this Windows
repository to a live App Store release.

Read [IOS_READINESS_AUDIT.md](IOS_READINESS_AUDIT.md) first for the audit and
the reasoning behind the current iOS approach.

**Current facts**

| Item | Value |
|---|---|
| Flutter version | `3.2.15+43` |
| Bundle ID | `com.lwv.bridalbookermachine` |
| Display name | `Loki Partnerz` |
| Minimum iOS | `15.0` |
| iPhone / iPad | Universal (`TARGETED_DEVICE_FAMILY = 1,2`) |
| Firebase project | `lead-management-app-74c44` |
| Firebase iOS app ID | `1:103543831309:ios:5abacb86219615daccce44` |
| API base URL | `https://bbm.lokiwebvibe.com` |
| Privacy policy | `https://bbm.lokiwebvibe.com/privacy.html` |
| Support page | `https://bbm.lokiwebvibe.com/support.html` (upload `support.html`) |

> The iOS app is a **companion app for existing subscribers**. Do not add a
> "Subscribe", "Buy", "Upgrade", or website-purchase link to the iOS build.
> That is an App Store rejection under Guideline 3.1.1. If Apple later requires
> in-app purchase, follow the StoreKit contingency in the audit.

---

## Phase 0 — Prerequisites

You need:

- [ ] A Mac (Apple Silicon recommended) with the latest stable Xcode.
- [ ] Xcode Command Line Tools: `xcode-select --install`.
- [ ] CocoaPods 1.16 or newer: `sudo gem install cocoapods`.
- [ ] Flutter 3.47.x (or the version that built `3.2.15+43`).
- [ ] An Apple Developer Program membership (paid, individual or organization).
- [ ] Access to App Store Connect with the Admin or App Manager role.
- [ ] Access to the Firebase project `lead-management-app-74c44`.
- [ ] SSH/HTTPS access to this Git repository.
- [ ] A real iPhone for testing. Push notifications do not work reliably on the
      simulator.

> An organization account needs a D-U-N-S number. Start enrollment early; it can
> take several days.

---

## Phase 1 — Get the project onto the Mac

```bash
git clone <your-repo-url> bbm
cd bbm
git checkout <the-branch-with-the-ios-fixes>
flutter --version
flutter pub get
```

`flutter pub get` creates `ios/Flutter/Generated.xcconfig`, which is intentionally
not committed.

**Firebase plist.** This pass un-ignored `ios/Runner/GoogleService-Info.plist`
and committed it, so a clone already contains it. If it is ever missing, download
it again from:

Firebase Console → Project settings → Your apps → the iOS app with bundle ID
`com.lwv.bridalbookermachine` → `GoogleService-Info.plist`.

The plist's `GOOGLE_APP_ID` must be
`1:103543831309:ios:5abacb86219615daccce44` and `BUNDLE_ID` must be
`com.lwv.bridalbookermachine`.

> Do not run `flutterfire configure` against a different iOS app. The repo's
> `firebase.json` is now aligned with the plist. If you regenerate, verify the
> app ID again.

Install pods:

```bash
cd ios
pod install --repo-update
cd ..
```

Open the workspace, **not** the project:

```bash
open ios/Runner.xcworkspace
```

You should see `Pods` in the left sidebar and the `Runner` scheme. If
`Runner.xcworkspace` only shows `Runner.xcodeproj`, `pod install` did not
complete.

---

## Phase 2 — Apple Developer Portal

1. Go to <https://developer.apple.com/account>.
2. Open **Certificates, Identifiers & Profiles → Identifiers**.
3. Find or create the App ID:
   - Bundle ID: `com.lwv.bridalbookermachine` (explicit, not wildcard).
   - Enable **Push Notifications**.
   - Enable any capabilities you add in Xcode later.
4. Create an APNs key:
   - **Keys → + → Apple Push Notifications service (APNs)**.
   - Download the `.p8` file once and store it safely. Apple cannot show it again.
   - Note the **Key ID** and your **Team ID**.
5. If Xcode asks to register a device, let it. For TestFlight you do not need to
   register every tester's device.

---

## Phase 3 — Firebase Cloud Messaging (iOS push)

1. Open the Firebase Console → project `lead-management-app-74c44`.
2. **Project settings → Cloud Messaging → Apple app configuration**.
3. Upload the APNs `.p8` key, with its Key ID and your Team ID.
4. Confirm the iOS app in Firebase uses bundle ID
   `com.lwv.bridalbookermachine` and app ID
   `1:103543831309:ios:5abacb86219615daccce44`.
5. The backend sends FCM messages; the iOS app registers its FCM token through
   `save_fcm_token.php`. No APNs server code is needed in this repo.

Test after the first device build: log in, allow notifications, then send a test
message from Firebase Console → Messaging → Create campaign → test on device.

---

## Phase 4 — Xcode project setup

Open `ios/Runner.xcworkspace`.

### 4.1 Signing

1. Select the **Runner** project → **Runner** target → **Signing & Capabilities**.
2. Team: select your Apple Developer team.
3. Check **Automatically manage signing**.
4. Bundle Identifier: `com.lwv.bridalbookermachine`.
5. If Xcode reports a conflict, make sure the App ID in the portal matches
   exactly and that no other app uses it.

### 4.2 Capabilities

Add:

- [ ] **Push Notifications**
- [ ] **Background Modes** → check **Remote notifications**

You do **not** need "Background fetch" or "Audio" for this app.

### 4.3 Deployment target

Confirm **Runner → General → Minimum Deployments** is **iOS 15.0**. The Podfile
and project are already set to 15.0 because Firebase 12.x requires it.

### 4.4 Verify bundled files

In **Runner → Build Phases → Copy Bundle Resources**, confirm:

- [ ] `GoogleService-Info.plist`
- [ ] `PrivacyInfo.xcprivacy`
- [ ] `Assets.xcassets`

In **Runner → Info**, confirm the display name is `Loki Partnerz`.

### 4.5 Version and build number

The Xcode project uses `$(FLUTTER_BUILD_NAME)` and `$(FLUTTER_BUILD_NUMBER)`, so
the values come from `pubspec.yaml`:

```yaml
version: 3.2.15+43
```

App Store Connect rejects a build number that was already uploaded. Before every
upload, increment `+43` to `+44`, `+45`, and so on. The marketing version can stay
`3.2.15` until you ship a user-facing release.

### 4.6 App icon

The icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset` were flattened to
remove the alpha channel. The `pubspec.yaml` now also has:

```yaml
flutter_launcher_icons:
  remove_alpha_ios: true
```

If you ever regenerate icons, run:

```bash
dart run flutter_launcher_icons
```

and verify the 1024×1024 icon has no alpha channel. A transparent App Store icon
fails upload with "Invalid App Store Icon".

### 4.7 Build a device build

```bash
flutter devices
flutter run --release -d <your-iphone-id>
```

If the app builds but crashes at launch, check:

- `GoogleService-Info.plist` is in **Copy Bundle Resources**.
- The bundle ID matches Firebase and the App ID.
- You opened the `.xcworkspace`.

---

## Phase 5 — Backend deployment (critical)

The iOS app calls endpoints that are **not all live yet**. Complete this before
submitting.

### 5.1 Upload the new/changed PHP files

Upload these to the production server, preserving paths:

```text
mobile_api/check_app_version.php
mobile_api/delete_account.php
mobile_api/admin/settings.php
mobile_api/admin/settings_update_version.php
```

`delete_account.php` currently returns **404** in production, so the in-app
Delete Account button will fail until it is uploaded. App Store Guideline
5.1.1(v) requires in-app account deletion, so this is a hard blocker.

### 5.2 Add the iOS version row

Run the migration on the production database:

```text
mobile_api/migrations/2026_11_05_add_ios_app_version.sql
```

This inserts an `ios` row into `app_version_config`. Until it exists, the updated
`check_app_version.php` returns a non-blocking response instead of HTTP 500.

### 5.3 Verify

```bash
curl "https://bbm.lokiwebvibe.com/mobile_api/check_app_version.php?version=3.2.15&platform=ios"
```

Expected: `success: true`, `force_update: false`, a `store_url` field, and HTTP
200. After the App Store record exists, set the iOS row's `playstore_url` to the
real App Store URL (for example
`https://apps.apple.com/app/id1234567890`). That value is returned as
`store_url` and is used by the force-update screen.

Test account deletion with a disposable account:

```bash
curl -X POST "https://bbm.lokiwebvibe.com/mobile_api/delete_account.php" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <API_TOKEN>" \
  -d "{\"api_token\":\"<API_TOKEN>\"}"
```

Expected: `{"success":true,"message":"Account deleted successfully"}`.

### 5.4 Upload the support page

Upload `support.html` to the web root so this URL works:

```text
https://bbm.lokiwebvibe.com/support.html
```

Verify:

```bash
curl -I "https://bbm.lokiwebvibe.com/support.html"
```

App Store Connect requires a Support URL and a Privacy Policy URL. The privacy
policy is already live at `https://bbm.lokiwebvibe.com/privacy.html`.

---

## Phase 6 — Test on device (do not skip)

Use a real iPhone and, if possible, an iPad. Test at least iOS 15 and the latest
iOS.

| Area | What to test |
|---|---|
| Launch | Splash → login; no white screen; correct logo/name |
| Login | Valid and invalid credentials; session restore |
| Version check | No 500; force-update screen opens the App Store URL when configured |
| Push | Permission prompt, token saved, foreground/background/terminated notification |
| Leads | Available leads, claim, release, status updates |
| Profile | Edit profile, validation, save |
| Account status | Inactive users see the neutral account-help page; **no subscription plans, prices, purchase button, or website link** |
| Account deletion | Settings → Delete Account → confirm → returns to login; test with a disposable account |
| PDF report | Generate and print/share a telecaller report |
| Video | Wistia video plays inside the app (WKWebView) |
| Links | `tel:` call button, WhatsApp link, Instagram/Facebook links open correctly |
| iPad | Layout, orientation, keyboard, sheets, and print popover |
| Offline | Airplane mode shows a friendly error, not a crash |

Also confirm the app does not show a "Create account" link on iOS and that the
registration route cannot open the registration form.

---

## Phase 7 — App Store Connect setup

### 7.1 Create the app record

App Store Connect → **My Apps → + → New App**:

- Platform: **iOS**
- Name: **Loki Partnerz** (must be unique on the App Store; use a subtitle if
  needed)
- Primary language: English
- Bundle ID: `com.lwv.bridalbookermachine`
- SKU: something internal, for example `lokipartnerz-ios-001`
- User access: full access for your team

### 7.2 App information

- **Category:** Business (or Productivity, if you prefer)
- **Content rights:** answer honestly. If the app displays content owned by third
  parties, confirm you have the rights.
- **Age rating:** complete the questionnaire. A lead-management app with no
  mature content is usually 4+ or 12+.
- **Made for Kids:** No.

### 7.3 Pricing

- **Price:** Free.
- The iOS app does not sell subscriptions. Do not configure in-app purchases for
  this companion-only release.

### 7.4 App Privacy

Complete the privacy questionnaire. At minimum, the app collects account and
contact data, and uses push notifications and Facebook App Events. A conservative
answer set:

- **Data linked to the user:** Yes.
- **Data used for tracking:** No. The app disables Facebook Advertiser ID
  collection (`FacebookAdvertiserIDCollectionEnabled = false`), so do not turn on
  ATT or IDFA collection.
- **Contact Info:** Name, email address, phone number, other contact info.
- **User Content:** Other user content (profile links, business details, notes).
- **Identifiers:** User ID, device ID (FCM token).
- **Usage Data:** Product interaction (Facebook App Events).
- **Diagnostics:** Only if your final SDK set collects crash/diagnostic data.

Review the Facebook SDK's data disclosure and the Firebase/Google privacy
manifests. Do not declare "no data collected"; this app has accounts and leads.

### 7.5 Screenshots

Screenshots must show the app in use, not the splash or login screen. Show the
dashboard, leads, claim flow, and settings.

App Store Connect will list the exact required sizes. At minimum prepare:

- iPhone 6.9-inch (for example 1320×2868 or 2868×1320).
- iPhone 6.5-inch (1242×2688 or 1284×2778) if requested.
- iPad 13-inch if the app remains universal (`TARGETED_DEVICE_FAMILY = 1,2`).

If you do not want to support iPad, change `TARGETED_DEVICE_FAMILY` to `1` and
retest. Apple encourages iPad support, but iPhone-only apps are allowed.

### 7.6 Metadata

- **Subtitle:** e.g. "Lead management for artists".
- **Description:** describe the actual features. Do not mention "subscribe on our
  website" or link to a purchase page.
- **Keywords:** lead management, makeup artist, bridal, bookings, CRM.
- **Support URL:** `https://bbm.lokiwebvibe.com/support.html`.
- **Privacy Policy URL:** `https://bbm.lokiwebvibe.com/privacy.html`.
- **Marketing URL:** optional; `https://lpz.lokiwebvibe.com/` works.

---

## Phase 8 — TestFlight

1. In Xcode, select **Any iOS Device (arm64)**.
2. **Product → Archive**.
3. In Organizer, **Distribute App → App Store Connect → Upload**.
4. Wait for processing in App Store Connect → TestFlight.
5. Add internal testers first. Internal testing does not require Beta App Review.
6. Test push, login, deletion, printing, and video on a real device.
7. For external testers, submit the build for Beta App Review.

TestFlight builds expire after 90 days.

---

## Phase 9 — Submit for App Review

1. In App Store Connect, select the processed build.
2. Fill in **App Review Information**:
   - Contact name, phone, email.
   - **Demo account:** username and password for an active, non-admin artist
     account that can see the full app. The app logs in with **username**, not
     email. Do not use an admin or telecaller account.
   - **Notes:** use the template below.
3. Answer export compliance. The app sets
   `ITSAppUsesNonExemptEncryption = false` for standard HTTPS only.
4. Select **Manually release** for your first release so you can control the
   launch.
5. **Add for Review → Submit**.

### Review notes template

```text
Loki Partnerz is the iOS companion app for our lead-management service for
makeup artists. The app lets existing customers sign in to view available
leads, claim leads, manage their profile, and receive push notifications.

The iOS app does not offer in-app purchases and does not contain links or calls
to action to purchase anything outside the app. Accounts are provisioned by
Loki Partnerz for its customers. The demo account below has full access so App
Review can use every feature.

Demo account:
  Username: <demo-username>
  Password: <demo-password>

Account deletion: Settings > Delete Account (available to signed-in users).
Privacy policy: https://bbm.lokiwebvibe.com/privacy.html
Support: https://bbm.lokiwebvibe.com/support.html / contact@lokiwebvibe.com
```

> Be honest if Apple asks how customers get accounts or how access is paid for.
> Do not add a purchase link or a "subscribe" call to action. If Apple requires
> in-app purchase, follow the StoreKit contingency instead of restoring the
> external website link.

---

## Phase 10 — After approval

1. Release the app.
2. Copy the App Store URL (`https://apps.apple.com/app/id<APP_ID>`).
3. Update the iOS `app_version_config` row's `playstore_url` field to that URL.
   The admin settings screen now has an **iOS** platform option where you can
   paste the App Store URL.
4. Increment the build number for every future upload.
5. Monitor reviews and crashes. This app does not currently include Crashlytics;
   add it if you want production crash reporting.

---

## Commands cheat sheet

```bash
# First-time setup
flutter pub get
cd ios && pod install --repo-update && cd ..

# Debug on a device
flutter run -d <device-id>

# Analyze
flutter analyze

# Regenerate icons (keep alpha removal)
dart run flutter_launcher_icons

# Build an IPA (signing must be configured in Xcode first)
flutter build ipa --release

# Where the IPA goes
build/ios/ipa/
```

If `flutter build ipa` complains about signing, open `ios/Runner.xcworkspace`,
select the Runner target, and fix **Signing & Capabilities** first.

---

## Troubleshooting

### `pod install` fails with a deployment target error

Firebase 12.x requires iOS 15.0. Confirm:

- `ios/Podfile` starts with `platform :ios, '15.0'`.
- `post_install` sets `IPHONEOS_DEPLOYMENT_TARGET` to `15.0`.
- `ios/Runner.xcodeproj/project.pbxproj` has `IPHONEOS_DEPLOYMENT_TARGET = 15.0;`.

If needed:

```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

### `No such module 'Firebase'` or missing plugin symbols

- Open `Runner.xcworkspace`, not `Runner.xcodeproj`.
- Run `pod install`.
- Clean: **Product → Clean Build Folder** (Shift+Cmd+K), then rebuild.

### Push notifications do not arrive

Check, in order:

1. Real device, not simulator.
2. App ID has Push Notifications enabled.
3. Xcode Runner target has the Push Notifications capability.
4. Background Modes has Remote notifications.
5. APNs key is uploaded to Firebase with the correct Key ID and Team ID.
6. The iOS app in Firebase uses bundle ID `com.lwv.bridalbookermachine`.
7. Notification permission was granted.
8. The backend saved the FCM token (`save_fcm_token.php`).

### "Invalid App Store Icon" / transparent icon

The icon was flattened in this pass. If you regenerate icons, keep
`remove_alpha_ios: true` in `pubspec.yaml`, or use ImageMagick:

```bash
magick mogrify -background white -alpha remove -alpha off \
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
```

### "Missing API declaration" / ITMS-91053

The app's own `PrivacyInfo.xcprivacy` covers `UserDefaults`. If App Store
Connect reports a missing declaration from a third-party SDK, update that pod.
Firebase 12.x and Facebook SDK 18.x ship privacy manifests. If the Razorpay pod
is flagged, update it or remove it from the iOS dependency graph in a future
change.

### Account deletion fails

- Confirm `mobile_api/delete_account.php` is uploaded (production currently
  returns 404).
- Confirm the user's token is valid and the user is not an admin.
- Check the PHP error log. The endpoint deletes related rows inside a
  transaction and rolls back on failure.

### iOS version check returns 500

Run `mobile_api/migrations/2026_11_05_add_ios_app_version.sql` and upload the
updated `check_app_version.php`. The updated endpoint also returns a
non-blocking response when the row is missing.

### App Store rejection for external purchases

If you receive a 3.1.1 / 3.1.3(b) rejection, do not re-add the website link.
Implement StoreKit auto-renewable subscriptions and server-side transaction
validation, as described in the audit. The existing subscription tables can store
Apple transactions.

---

## Final pre-submission checklist

- [ ] `flutter analyze` passes.
- [ ] `pod install` succeeds on the Mac.
- [ ] Xcode signing team selected; no signing errors.
- [ ] Minimum iOS is 15.0.
- [ ] Push Notifications capability enabled.
- [ ] Background Modes → Remote notifications enabled.
- [ ] `GoogleService-Info.plist` is in Copy Bundle Resources and the bundle ID
      matches Firebase.
- [ ] `PrivacyInfo.xcprivacy` is in Copy Bundle Resources.
- [ ] App icon 1024×1024 has no alpha channel.
- [ ] iOS build number is higher than every previous upload.
- [ ] Production `delete_account.php` works (no 404).
- [ ] iOS version row exists; `check_app_version.php` returns 200.
- [ ] App Store URL added to the iOS version row after the record exists.
- [ ] `support.html` and `privacy.html` are live.
- [ ] No purchase button, website purchase link, or "subscribe" call to action
      in the iOS app.
- [ ] The iOS `/Subscription` route shows only the account-help page, with no
      plans or prices.
- [ ] Sign-up is hidden on iOS, and the registration route does not open the
      registration form.
- [ ] Demo account is active and can access the full app.
- [ ] Screenshots show real app screens (not login/splash).
- [ ] App Privacy answers completed.
- [ ] Tested on a real iPhone and, if universal, an iPad.
- [ ] TestFlight build passes internal testing.

# Loki Partnerz (formerly BBM) - Full AI Project Context

## 1. Project Overview

- Repository: `maara2524/LokiPartnerz`
- Flutter package: `bbm_app`
- Current public app/display name: `Loki Partnerz`
- Previous/public legacy names: `BBM`, `BBM Artist App`, and `Bridal Booker Machine`
- iOS display name: `Loki Partnerz`
- Android `app_name`: `Loki Partnerz`
- Android application ID: `com.lwv.bridalbookermachine`
- iOS bundle display/name: Loki Partnerz / LokiPartnerz
- Current pubspec version: `3.2.16+44`
- Dart SDK constraint: `^3.8.1`
- Platforms: Android, iOS, and limited/web scaffolding
- Primary API: `https://bbm.lokiwebvibe.com`
- API override: `--dart-define=API_BASE_URL=<base-url>`
- Backend: procedural PHP endpoints plus MySQL/PDO
- Backend directory: `mobile_api/`
- Database config: `app/config/database.php`
- Main database timezone: `Asia/Kolkata` / MySQL `+05:30`

Loki Partnerz is the current display name of the subscription-based lead marketplace previously known as BBM/BBM Artist App/Bridal Booker Machine. The rebrand changed the user-facing app name only. Existing package names, application IDs, bundle identifiers, API domains, backend paths, database identifiers, payment/deep-link identifiers, and signed app installations must not be renamed casually.

The app lets artists pay for plans that allow them to claim leads in their service category. Telecallers use the same application for internal lead follow-up and artist assignment. Admin users manage users, leads, plans, app settings, UI content, telecallers, and platform operations.

This is not a generic CRM or consumer booking app. The core commercial loop is:

1. Leads enter the system from external sources, including Meta/Facebook campaigns.
2. Leads are delayed, filtered, and made visible according to category and system rules.
3. Artists purchase or receive a plan.
4. Artists claim leads and update them through a status and follow-up workflow.
5. Telecallers and admins monitor and intervene in the lead workflow.
6. Daily and lifetime claim limits, expiry, locking, and auto-release control lead access.

## 1.1 Branding and Identifier Rules

The rename is a display-brand rebrand, not a technical rename. AI agents and developers must distinguish public branding from legacy/internal identifiers:

### Use for user-facing branding

- `Loki Partnerz`
- Android launcher label: `Loki Partnerz`
- iOS `CFBundleDisplayName`: `Loki Partnerz`
- iOS `FacebookDisplayName`: `Loki Partnerz`

Do not describe the current app as a newly named package or imply that package/application IDs changed.

### Keep unchanged for compatibility

- Flutter package: `bbm_app`
- Android application ID: `com.lwv.bridalbookermachine`
- Android namespace: `com.lwv.bridalbookermachine`
- Android signing asset names may remain `bbm-key.jks` and `bbm_android`
- Android deep-link scheme: `bbm://payment-callback`
- API host: `bbm.lokiwebvibe.com`
- Backend/database/UI terminology: `BBM`, `bbm_app`, `bbm_api`, and `mobile_api`
- Existing database tables, columns, routes, app route names, analytics labels, and files
- iOS bundle/product identifiers unless a separate Apple product and identifier migration is explicitly approved

Renaming these technical values may break existing installations, payment callbacks, Firebase configuration, deep links, Play/App Store identity, or backend integrations. BBM names are therefore legacy identifiers and Loki Partnerz is the current brand name.

## 2. User Roles

### 2.1 Artist

The normal consumer of paid leads.

- Registers with business/profile details.
- Begins inactive at level `5`.
- Receives a 10-digit WhatsApp number as the initial login username/password.
- Purchases or receives a subscription.
- Sees leads matched to the profile category.
- Can claim leads, view claim history, search/filter claims, update status, add notes, release leads, and open lead details.
- Can edit profile and business information.
- Can use Wistia tutorial resources.
- Can logout or, on iOS, delete the account.

### 2.2 Telecaller

A role for internal sales/follow-up operations.

- Uses the normal login flow but receives a separate shell.
- Views an operational dashboard.
- Views available leads and leads assigned or interacted with by the telecaller.
- Updates telecaller call/status information.
- Adds notes and follow-up activity.
- Views reports and today-versus-total metrics.
- Assigns eligible elite artists to leads.

The app identifies the role from `SharedPreferences["role"] == "telecaller"`.

### 2.3 Admin

An authenticated mobile backoffice shell.

- Views dashboard totals, lead distribution, category distribution, and activity.
- Creates, edits, activates, and deletes users.
- Grants plans to users and changes claim limits.
- Creates/removes telecaller users.
- Lists, searches, inspects, edits, unlocks, deletes, and releases leads.
- Reviews claim history and lead status timeline.
- Views and updates subscription plans.
- Updates Android/iOS/Web version settings and forced-update content.
- Toggles lead locking, auto-release, FCM, Meta events, intro videos, and maintenance mode.
- Updates database-backed UI configuration keys.
- Releases every locked lead.

The app identifies admin sessions from `SharedPreferences["role"] == "admin"` and validates them through the bearer-protected admin API.

## 3. Authentication and Sessions

### 3.1 Login

`POST mobile_api/auth.php`

- Accepts username and password as JSON or form data.
- Password is verified with PHP `password_verify`.
- A 32-byte random API token is generated with `bin2hex(random_bytes(32))`, stored in `users.api_token`.
- Token expiry is set to 30 days.
- Login stores:
  - `auth_token`
  - `user_id`
  - `level`
  - `username`
  - `role`
  - `status`
  - `business_name`
- The login routes based on role/status/level:
  - admin -> admin shell
  - telecaller -> main shell
  - inactive or level 5 artist -> subscription page
  - active eligible artist -> artist shell

### 3.2 Registration

`POST mobile_api/register.php`

Registration collects:

- business name
- contact person
- WhatsApp number
- Instagram URL
- service category
- optional coupon code

Validation includes:

- exactly 10 digits for WhatsApp
- non-empty business/contact fields
- Instagram URL format when supplied
- service category
- unique username/WhatsApp

The initial password is the WhatsApp number. On success, the account is created with:

- role `artist`
- status `inactive`
- level `5`
- an API token
- an `artist_profiles` record

A registration-success dialog displays the username and password. A Facebook `CompleteRegistration` app event is logged after registration.

### 3.3 Password Recovery

There are dedicated pages and PHP endpoints for:

- `forgot_password_page.dart`
- `otp_verification_page.dart`
- `reset_password_page.dart`
- `mobile_api/password_recovery/send_otp.php`
- `mobile_api/password_recovery/verify_otp.php`
- `mobile_api/password_recovery/reset_password.php`

The recovery flow sends an OTP, verifies it, and sets a new password. OTP delivery/implementation details are backend concerns and should be verified against the live endpoint.

### 3.4 Session Storage

The app uses `SharedPreferences` for local session and cached data:

- `auth_token`
- `user_id`
- `level`
- `username`
- `role`
- `status`
- `business_name`
- `fcm_token`
- `artist_profile`
- lead disclaimer daily/permanent opt-out keys

`prefs.clear()` is used on logout and account/session termination. The app does not maintain a private, encrypted Flutter credential store; all persistent auth state is in SharedPreferences.

## 4. Navigation and App Shells

### 4.1 Splash and startup

`lib/splash_page.dart`

Startup performs:

1. Package-name/version lookup.
2. Server forced-update check.
3. Platform-specific update check.
4. Android Play Core flexible/immediate update handling.
5. Three-second splash delay.
6. Local session check.
7. Server-side role/status validation.
8. Route to admin, telecaller, artist subscription, artist shell, or login.

The server version check fails open: if it cannot run or the API is unavailable, the app continues.

### 4.2 Named routes

`lib/main.dart` defines:

- `/` - splash
- `/dashboard` - dashboard
- `/settings` - settings
- `/leads` - lead launcher
- `/available_leads` - available leads
- `/my_claims` - artist claims
- `/lead_detail` - lead detail
- `/login` - login
- `/register` - registration
- `/Subscription` - subscription
- `/assign_artist` - elite artist assignment
- `/admin` - admin shell

### 4.3 Artist tabs

`MainShell` uses a `PageView` and bottom navigation:

1. Home - artist dashboard
2. Leads - available leads
3. My Claims - claimed leads
4. Resources - tutorial videos
5. Settings - profile/account

Tab counts are returned by child pages and shown in app-bar titles.

### 4.4 Telecaller tabs

1. Home - telecaller dashboard
2. Leads - available telecaller leads
3. My Leads - telecaller interacted/assigned leads
4. Report - telecaller report
5. Settings

### 4.5 Admin tabs

1. Dashboard
2. Users
3. Leads
4. Plans
5. Settings

## 5. Subscription System

### 5.1 Plan model

Subscriptions use `subscription_plans` and `subscription_history`.

A plan normally has:

- ID
- slug
- name
- integer price
- currency
- description
- artist level
- duration
- Apple product ID
- active state

Known plan slugs in the app:

- `trial`
- `basic`
- `extended_basic`
- `elite`

Higher/lower plan meaning is numeric and should not be reversed without backend verification:

- level `5`: inactive/unsubscribed
- level `4`: trial
- level `3`: basic
- level `2`: extended/basic higher tier
- level `1`: elite/internal

Some of these levels are also used as operational system-setting keys. The backend is the authority for exact values and current plan behavior.

### 5.2 Subscription page

`lib/subscription.dart`

- Loads subscription plans.
- Loads UI copy from `app_ui_config`.
- Loads a free Wistia intro video.
- Supports Android Razorpay checkout.
- Supports iOS StoreKit/In-App Purchase checkout.
- Supports a website fallback link.
- Shows notification permission status and can open OS notification settings.
- Logs payment funnel events to Facebook App Events.
- Prevents duplicate/reentrant payment calls with loading and timeout guards.

### 5.3 Android/Razorpay flow

1. Create Razorpay order through `subscriptions/create_order.php`.
2. Open Razorpay checkout with order, amount, currency, and customer details.
3. Receive payment ID/signature/order ID callbacks.
4. Send confirmation to `subscriptions/confirm_razorpay_payment.php`.
5. Verify the server-side Razorpay signature.
6. Activate the user and artist level.
7. Navigate to the app shell.

The backend also supports a webhook at `subscriptions/razorpay_webhook.php`.

### 5.4 iOS/App Store flow

The app initializes `InAppPurchase` StoreKit:

- Loads available Apple product IDs from plan records.
- Requests purchase restoration.
- Completes purchased transactions.
- Sends purchase verification to `subscriptions/verify_apple_purchase.php`.
- Receives verification and account activation status.
- Prevents account use until the backend confirms the purchase.

Apple product IDs must match App Store Connect and `subscription_plans.apple_product_id`.

### 5.5 Legacy/alternate payments

The repository contains PhonePe-style endpoints:

- `mobile_api/create_order.php`
- `mobile_api/check_order_status.php`
- `mobile_api/payment_callback.php`
- `mobile_api/config/phonepe_config.php`

Treat Razorpay and Apple IAP as current active mobile paths unless live backend evidence says otherwise.

### 5.6 Subscription activation

Successful activation:

- expires old/duplicate active subscriptions
- inserts or updates `subscription_history`
- updates `artist_profiles.artist_level`
- sets `users.status = active`
- sets `users.level` to the plan's artist level

If claim use reaches or exceeds the subscription limit:

- the subscription is marked expired
- the user is marked inactive
- user level is reset to `5`
- the next app flow routes back to subscription

## 6. Lead Marketplace

### 6.1 Lead data

The `leads` table/entity contains customer and event information:

- source
- customer name
- WhatsApp number
- event date
- event type
- services required
- location
- budget range
- additional information
- status
- claimed by
- claim time
- claim expiry
- claim count
- lock state
- notified state
- maximum allowed claims
- timestamps

Artist category matching uses the artist profile category against lead event/service fields.

### 6.2 Available-lead rules

`all_leads.php` validates:

- API token
- token expiry
- user role
- artist category for non-telecaller users

It automatically resets expired claims and opens expired lead rows.

It may filter by:

- lead visibility delay
- event date at least two days away
- lead category/service match
- lead not locked by another user
- lead not already fully claimed
- lead not previously claimed by this artist
- lead state not booked/closed
- telecaller lead start date
- telecaller team-tracking state

UI behavior includes:

- one-time daily disclaimer
- permanent disclaimer opt-out
- refresh/internet retry states
- session-expired state
- subscription-ended state
- claim confirmation
- category/event/price/detail cards
- contact action and lead detail navigation

### 6.3 Claiming

`POST mobile_api/claim_leads.php`

The claim endpoint enforces:

- active token
- active account
- active subscription
- daily claim limit
- total plan claim limit
- lead existence
- lead not booked/closed
- lead not claimed by another active artist
- lead not already fully claimed
- event date eligibility
- previously claimed lead restrictions

A successful claim:

1. Locks the lead.
2. Sets `claimed_by`.
3. Sets claim expiry.
4. Increments `claim_count`.
5. Inserts `claimed_leads_log`.
6. Adds lead status history.
7. Increments `subscription_history.total_leads_claimed`.

Database transactions and `SELECT ... FOR UPDATE` are used to reduce race conditions.

### 6.4 My Claims

`lib/my_claims_page.dart`

- Loads subscription-period aggregated stats.
- Shows claimed leads for the artist.
- Supports text search.
- Filters by status.
- Filters by event date.
- Supports refresh and connectivity handling.
- Opens lead details.
- Shows session-expired/network/empty states.

### 6.5 Lead Details

`lib/new_lead_details.dart`

The details page:

- loads normalized event type and requirements;
- shows customer and event information;
- exposes WhatsApp call/chat actions;
- shows status and follow-up controls;
- adds notes;
- lists status history;
- releases a claimed lead when allowed;
- handles booked/closed/expired states.

Lead status updates:

- are ownership checked;
- update lead status;
- record status history;
- may clear/reapply locks according to rules.

Status labels used by the artist UI include:

- New
- Contacted
- Follow Up
- Closed
- Booked
- Booked inside app
- Booked outside app

### 6.6 Lead Notes

`lead_notes_page.dart` and `add_new_note.php` provide:

- note entry
- note history display
- formatted status labels
- per-claimed-lead context

### 6.7 Lead release

`release.php` clears active claim ownership/expiry/lock fields according to authorization and claim state. The admin shell can also release all locked leads.

## 7. Artist Dashboard

`lib/dashboard_page.dart`

The dashboard:

- loads business name and username.
- loads database-backed UI config.
- queries subscription-period claim stats.
- can switch subscription period or selected subscription.
- shows total, new, contacted, and booked lead counts.
- shows recent claimed leads.
- shows total lead data and subscription periods.
- checks notification permission.
- opens notification settings.
- listens for app resume and route-pop refresh events.
- listens for internet reconnection.
- distinguishes network, session-expired, and unknown errors.

Dashboard cards navigate to Available Leads or My Claims through `MainShell.switchToTab`.

## 8. Telecaller Workflow

### 8.1 Telecaller dashboard

`telecaller_dashboard_page.dart`

Shows:

- leads contacted
- total calls
- notes added
- interested leads
- today totals for calls, notes, and interested leads

It handles session expiration, network failures, and retry.

### 8.2 Telecaller leads

`telecaller_leads_page.dart` and `available_leads_page.dart`

The telecaller lead page:

- loads available lead inventory.
- loads leads assigned or followed by the telecaller.
- exposes lead details and status controls.
- sends WhatsApp/call actions.
- adds follow-up activity.

### 8.3 Telecaller reports

`telecaller_report_page.dart`

- loads telecaller reporting data.
- presents call/status totals and activity breakdown.
- supports refreshed report data.

### 8.4 Elite artist assignment

`assign_artist_page.dart`, `elite_artists.php`, and `assign_artist.php`

- loads elite artist candidates.
- assigns an artist to a lead.
- updates telecaller tracking/assignment state.
- records the assignment in lead activity.

### 8.5 Telecaller database model

The telecaller side uses:

- `team_lead_tracking`
- `lead_activity`
- `status_master`
- `elite_clients`

The latest status is commonly represented by `team_lead_tracking.current_status_id`, while activity and call history are stored in lead activity tables.

## 9. Resources and Training

### 9.1 Resources page

`lib/resources_page.dart`

- loads paid or gated tutorial videos.
- uses Wistia WebViews.
- applies the access flag returned by the backend.
- displays locked, unavailable, and network states.

### 9.2 Subscription intro video

`subscription-intro-video.php`

- returns the first/free Wistia intro video.
- is used in the subscription page.

### 9.3 Wistia player

`wistia_player_page.dart`

- opens a Wistia iframe.
- enables JavaScript.
- has loaded/error states.

## 10. Profile and Settings

`lib/settings_page.dart`

### Profile

Loads the local profile cache first, then refreshes from `get_profile.php`.

Editable fields include:

- username
- business name
- WhatsApp number
- Instagram handle
- Facebook page
- website
- location
- profile/category-related fields exposed by the backend

Validation includes:

- unique username length of at least 4
- 10-digit WhatsApp
- valid HTTP/HTTPS URLs

### Account

- logout clears all shared preferences and returns to login
- iOS account deletion is explicitly supported
- Android account deletion is not exposed
- notification settings can be opened
- privacy/support links can be opened

Android and iOS receive platform-specific subscription/account behavior.

## 11. Notifications

### 11.1 Firebase

Dependencies:

- `firebase_core`
- `firebase_messaging`
- `flutter_local_notifications`

Startup:

- initializes Firebase
- registers a background messaging handler
- requests alert/badge/sound permission
- fetches and stores FCM token
- uploads token to `save_fcm_token.php`
- listens for token refresh
- shows foreground Android notifications locally
- uses iOS foreground presentation options

### 11.2 Android notification channel

- channel ID: `default_channel`
- channel name: `General Notifications`
- importance: high

### 11.3 Notification permission

`permission_handler` and `utils/notification_permission.dart` are used to inspect/open notification settings.

### 11.4 Server notification endpoints

- `save_fcm_token.php`
- `send_fcm.php`
- `check_new_leads.php`
- `test_push.php`

## 12. Admin System

`lib/admin/`

### 12.1 Admin API authentication

`AdminApiService` obtains the bearer token from SharedPreferences and sends:

```http
Authorization: Bearer <auth_token>
Content-Type: application/json
Accept: application/json
```

`mobile_api/admin/_bootstrap.php` supplies shared admin authorization and JSON behavior.

### 12.2 Dashboard

`admin_dashboard_page.dart`

- lead/user/subscription metrics
- lead breakdown
- category breakdown
- recent activity
- skeleton and error states

### 12.3 Users

`admin_users_page.dart`

- list/search/filter users
- create artist/telecaller/admin users
- update user/profile fields
- toggle active/inactive
- delete users
- grant plans
- set per-user claim limits
- open user detail sheet

Endpoints:

- `admin/users.php`
- `admin/user_create.php`
- `admin/user_update.php`
- `admin/user_toggle_status.php`
- `admin/user_delete.php`
- `admin/user_grant_plan.php`
- `admin/user_claim_limit_update.php`

### 12.4 Leads

`admin_leads_page.dart`

- search by customer/details
- filter status/category
- inspect a lead
- edit lead fields
- set maximum claims
- view claim history
- view status timeline
- unlock lead
- delete lead
- release all leads

Endpoints:

- `admin/leads.php`
- `admin/lead_detail.php`
- `admin/lead_update.php`
- `admin/lead_unlock.php`
- `admin/lead_delete.php`
- `admin/leads_release_all.php`

### 12.5 Plans

`admin_subscriptions_page.dart`

- list active subscription data
- update plan details
- update Apple product identifiers
- update plan prices/descriptions/levels

Endpoint:

- `admin/subscriptions.php`
- `admin/subscription_plan_update.php`

### 12.6 Settings

`admin_settings_page.dart`

- forced update version settings for Android/iOS
- force-update message and store URL
- FCM toggle
- Meta event toggle
- lead-lock toggle
- auto-release toggle
- intro-video toggle
- maintenance mode
- UI configuration keys by screen
- telecaller creation/removal
- release all locked leads
- admin sign-out

Endpoints:

- `admin/settings.php`
- `admin/settings_update_version.php`
- `admin/settings_update_toggles.php`
- `admin/settings_update_ui_config.php`
- `admin/telecaller_create.php`
- `admin/telecaller_remove.php`

## 13. UI Configuration System

`get_ui_config.php` and `app_ui_config`

The backend supplies key/value UI content for screens. The app fetches values for:

- subscription
- available leads
- resources
- other configured screens

Common keys include screen disclaimer title/body and plan benefit point lists:

- `basic_point_1`, `basic_point_2`, ...
- `trial_point_1`, ...
- `elite_point_1`, ...

Dynamic UI text must not be assumed to match hardcoded defaults. Backend/UI config is an effective CMS layer.

## 14. Main Technologies

### 14.1 Flutter/Dart

- Dart `^3.8.1`
- Material 3
- Stateful widget/page architecture
- `PageView` and bottom navigation
- `SharedPreferences`
- `package:http`
- `GoogleFonts`
- `FontAwesomeFlutter`
- `url_launcher`
- `connectivity_plus`

### 14.2 Android

- Kotlin
- Gradle Kotlin DSL
- compile/target SDK `36`
- Java/Kotlin JVM target `17`
- Core library desugaring
- Firebase BOM
- R8/resource shrinking setup
- Play Core immediate/flexible updates
- release signing loaded from `key.properties`

### 14.3 iOS

- Swift AppDelegate/scene setup
- CocoaPods
- StoreKit/In-App Purchase
- Firebase
- Facebook SDK/App Events
- remote notifications background mode

### 14.4 Backend

- procedural PHP
- PDO
- MySQL
- JSON endpoints
- CORS headers
- server-side password verification
- bearer/query-token authorization
- PHP random API token sessions
- 30-day token expiry

### 14.5 External services

- Firebase Core and Cloud Messaging
- Razorpay
- Apple StoreKit/IAP
- Wistia
- Facebook App Events
- Google Play in-app updates
- Meta lead sources
- optional legacy payment callbacks

## 15. Flutter Dependencies

Declared direct dependencies:

- `firebase_core`
- `firebase_messaging`
- `flutter_local_notifications`
- `http`
- `shared_preferences`
- `google_fonts`
- `font_awesome_flutter`
- `connectivity_plus`
- `url_launcher`
- `app_links`
- `razorpay_flutter`
- `facebook_app_events`
- `webview_flutter`
- `in_app_update`
- `package_info_plus`
- `pdf`
- `printing`
- `permission_handler`
- `in_app_purchase`

Development dependencies:

- `flutter_test`
- `flutter_lints`
- `flutter_launcher_icons`

## 16. Backend Endpoint Map

### Authentication/profile

- `auth.php`
- `register.php`
- `get_profile.php`
- `update_artist_profile.php`
- `delete_account.php`
- `get-service-categories.php`
- `password_recovery/send_otp.php`
- `password_recovery/verify_otp.php`
- `password_recovery/reset_password.php`

### Lead operations

- `all_leads.php`
- `claim_leads.php`
- `release.php`
- `lead_details.php`
- `update_status.php`
- `add_new_note.php`
- `stats.php`
- `get_followup_status.php`

### Telecaller

- `telecaller_dashboard.php`
- `telecaller_my_leads.php`
- `telecaller_report.php`
- `assign_artist.php`
- `elite_artists.php`

### Subscription/payment

- `subscriptions/get_subscription_plans.php`
- `subscriptions/create_order.php`
- `subscriptions/confirm_razorpay_payment.php`
- `subscriptions/razorpay_webhook.php`
- `subscriptions/get_my_subscription.php`
- `subscriptions/verify_apple_purchase.php`
- `create_order.php`
- `check_order_status.php`
- `payment_callback.php`

### Content/platform

- `get_ui_config.php`
- `tutorial_videos.php`
- `subscription-intro-video.php`
- `check_app_version.php`
- `save_fcm_token.php`
- `send_fcm.php`
- `check_new_leads.php`
- `test_push.php`
- `test.php`

### Admin

- `admin/dashboard.php`
- `admin/users.php`
- `admin/user_create.php`
- `admin/user_update.php`
- `admin/user_toggle_status.php`
- `admin/user_delete.php`
- `admin/user_grant_plan.php`
- `admin/user_claim_limit_update.php`
- `admin/leads.php`
- `admin/lead_detail.php`
- `admin/lead_update.php`
- `admin/lead_unlock.php`
- `admin/lead_delete.php`
- `admin/leads_release_all.php`
- `admin/subscriptions.php`
- `admin/subscription_plan_update.php`
- `admin/settings.php`
- `admin/settings_update_version.php`
- `admin/settings_update_toggles.php`
- `admin/settings_update_ui_config.php`
- `admin/telecaller_create.php`
- `admin/telecaller_remove.php`

## 17. Core Database Tables

### Identity/profile

- `users`
- `artist_profiles`

### Leads/claims

- `leads`
- `claimed_leads_log`
- `lead_status_history`
- `lead_activity`
- `lead_notes`

### Subscription

- `subscription_plans`
- `subscription_history`
- `payment_transactions`

### Rules/config

- `system_settings`
- `app_ui_config`

### Telecaller

- `team_lead_tracking`
- `status_master`
- `elite_clients`

### Operational

- notifications and FCM state on `users`
- app version/system settings

Table names and columns must be verified against live migrations and the SQL dump when making backend changes.

## 18. System-Setting Rules

`system_settings` is a database-driven policy layer keyed by setting and user level.

Important keys include:

- `lead_visibility_delay_hours`
- `claim_lock_duration_hours`
- `auto_release_inactive_hours`
- `max_claims_per_day`
- `max_total_claims`
- `can_claim_leads`

These control:

- lead visibility delay
- claim locks
- expired claim release
- per-day artist claims
- lifetime plan claims
- whether the user level can claim

There may also be admin toggle records controlling FCM, Meta events, locking, auto-release, intro video, and maintenance mode. The admin settings endpoint is authoritative for present behavior.

## 19. Important HTTP/Session Conventions

- Public lead/subscription data can use unauthenticated GET requests.
- Most artist and telecaller endpoints use a query parameter `token`.
- Admin endpoints use `Authorization: Bearer <token>`.
- Several POST endpoints accept JSON or form data.
- JSON success is commonly represented by `success: true`.
- Errors can use `error` or `message`.
- HTTP `401` means invalid/expired/missing auth.
- HTTP `403` commonly means inactive subscription, limit, or role denial.
- HTTP `409` commonly means a lead has been claimed or is in a terminal state.
- Session-expired UI clears/redirects local credentials.

Do not introduce one authentication convention globally without auditing every PHP endpoint.

## 20. Connectivity and Error Handling

The app uses:

- `connectivity_plus`
- custom `NetworkUtils`
- per-page loading, retry, and refresh states
- session-expired screens
- subscription-ended screens
- `AppErrorView`
- HTTP status-specific fallbacks
- JSON parsing guards
- request timeouts on sensitive login/startup calls

The app must distinguish:

- no internet
- server unavailable
- invalid/expired token
- inactive subscription
- claim limit reached
- lead already claimed
- lead booked/closed
- malformed server response

## 21. Analytics and Tracking

### Facebook App Events

The app has a Facebook App Events wrapper.

Configured iOS Facebook values are stored in `Info.plist`, and Android uses Firebase/Google services plus the app event plugin.

Events observed include:

- `CompleteRegistration`
- subscription/payment funnel events

Do not enable advertising or analytics outside the existing privacy/consent configuration without product review.

## 22. Update and Release Behavior

### Server update gate

`check_app_version.php` receives:

- current app version
- platform

It can force update and provide store URL/message.

### Android in-app update

Uses Play Core:

- immediate update if allowed
- flexible update if immediate is unavailable
- completes flexible update after download

### iOS

Store URL is shown by the update-required screen; Apple IAP is independent from App Store app updates.

### Release configuration

- Android signing properties are in `android/key.properties`
- Android release signing may use `android/app/bbm-key.jks`
- iOS signing is configured in Xcode/CocoaPods
- native Firebase configuration files are present in Android/iOS folders

Secrets and signing material must remain outside source control and must not be pasted into AI context.

## 23. Project Structure

```text
lib/
  main.dart
  main_shell.dart
  splash_page.dart
  login_page.dart
  register_page.dart
  forgot_password_page.dart
  otp_verification_page.dart
  reset_password_page.dart
  dashboard_page.dart
  leads_home_page.dart
  available_leads_page.dart
  my_claims_page.dart
  new_lead_details.dart
  lead_notes_page.dart
  assign_artist_page.dart
  subscription.dart
  subscription_ended_screen.dart
  resources_page.dart
  wistia_player_page.dart
  settings_page.dart
  telecaller_dashboard_page.dart
  telecaller_leads_page.dart
  telecaller_report_page.dart
  update_req_screen.dart
  meta_events.dart
  config/api_config.dart
  theme/
  utils/
  widgets/
  admin/

mobile_api/
  auth/profile/lead endpoints
  password_recovery/
  subscriptions/
  admin/

android/
ios/
web/
assets/
test/
```

Current source directories can contain build artifacts and generated Gradle/Xcode files. Use source folders and manifests as authority, not build output.

## 24. Build and Run

### Flutter setup

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

### Android

```powershell
flutter build apk --release
flutter build appbundle --release
```

### iOS

```powershell
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release
```

### Environment override

```powershell
flutter run --dart-define=API_BASE_URL=https://your-api.example
```

The API default is production and changing the base URL affects every endpoint built by `ApiConfig`.

## 25. Testing Guidance

Before completing a change:

1. Run targeted Flutter tests or `flutter test`.
2. Run `flutter analyze`.
3. Verify Android and iOS compilation where native/API behavior changed.
4. Test login, registration, logout, and session expiry.
5. Test subscription plan loading and payment activation.
6. Test artist claim limits and duplicate/expired claims.
7. Test telecaller dashboard/assignment/report.
8. Test admin CRUD and authorization.
9. Test no-network behavior and server malformed JSON behavior.
10. Test notification token upload and foreground/background handling.

No backend or database migration should be considered complete until Flutter payloads and PHP SQL agree.

## 26. Known Risks and Caveats

### Security

- API tokens are stored as SharedPreferences strings.
- PHP auth is endpoint-local and largely procedural.
- Backend credentials and payment secrets may exist in server files/config.
- API responses and endpoint authorization should be audited for every change.
- Never include live secrets, private keys, service-account JSON, passwords, or signing passwords in prompts, docs, or commits.
- Razorpay signatures, Apple receipt verification, and token expiry must be enforced server-side.

### Mixed implementations

- Razorpay and legacy PhonePe-style flows coexist.
- Apple IAP and Razorpay use separate activation APIs.
- Admin pages and legacy artist pages use slightly different response conventions.
- The SQL dump and live PHP schema may differ.

### Status terminology

Artist, telecaller, and admin status names are not identical. Preserve the originating status model unless a migration is intentional.

### Schema drift

The app contains both older and newer SQL/PHP assumptions. Verify:

- role values
- status names
- plan/level mappings
- lead claim columns
- claim history table names
- telecaller tracking tables
- system-setting keys

### Product assumptions

- level `5` is the default inactive state
- categories drive lead matching
- subscriptions can be exhausted by usage
- expired leads can be automatically released
- lead visibility delay and lock duration are configurable

Do not hardcode these values in Flutter when the backend exposes a setting or subscription plan field.

## 27. Change Guidelines for AI Coding Agents

Before editing:

1. Trace the Flutter screen -> `ApiConfig` endpoint -> PHP endpoint -> SQL table/column.
2. Read nearby code and preserve existing response parsing fallbacks.
3. Make coordinated Flutter/PHP/schema changes in one task.
4. Preserve role/status/level behavior.
5. Use existing theme, widget, and admin API patterns.
6. Do not expose or move secrets.
7. Add focused tests for claim, auth, subscription, role, or status changes.
8. Validate Android and iOS when navigation, payment, permissions, or deep links change.
9. Use the production base URL unless the task explicitly configures a different environment.

## 28. Best Mental Model

Loki Partnerz is a:

> Flutter mobile lead marketplace and operations system for artists/vendors, previously known as BBM/BBM Artist App/Bridal Booker Machine, backed by procedural PHP/MySQL endpoints, with subscription-based lead access, category matching, claim limits, Wistia training, Razorpay and Apple IAP payments, Firebase notifications, telecaller workflows, and a mobile admin backoffice.

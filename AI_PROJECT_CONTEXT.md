# BBM App: Full Project Context for AI Systems

## 1. Project Identity

- Project name: `bbm_app`
- Product name used in UI/docs: `BBM`, `BBM Artist App`, `Bridal Booker Machine`
- App type: Flutter mobile app backed by a PHP + MySQL API
- Primary domain: lead distribution and conversion for wedding/event service providers
- Primary backend host configured in the app: `https://bbm.lokiwebvibe.com`

This project is not a generic CRM. It is a monetized lead marketplace and operations app centered on bridal/event vendors, especially makeup artists, with an additional telecaller workflow for internal lead handling.

## 2. Product Goal

The app exists to convert inbound customer leads into paid business opportunities for service providers.

In practice, it does four things:

1. Onboards artists/vendors into the BBM ecosystem.
2. Sells subscriptions that unlock access to leads.
3. Lets subscribed artists discover, claim, and work leads relevant to their category.
4. Gives telecallers an internal workflow to contact leads, track status, and assign elite artists.

The lead funnel appears to be:

1. Leads are generated externally, often from Meta/Facebook campaigns.
2. Leads enter the BBM database.
3. Telecallers and/or artists work those leads depending on role and business flow.
4. Artists convert leads into contacted/booked outcomes.
5. The app tracks usage so subscriptions can expire after total claim limits are reached.

## 3. Main User Types

### Artist

This is the main mobile user.

- Registers from the app.
- Starts as `inactive` and `level = 5`.
- Must purchase a subscription to become active.
- Can view only category-matched leads.
- Can claim leads, view claimed leads, update statuses, add notes, and watch training resources.
- Can edit profile/business details.

Typical categories seen in code/data:

- `Makeup`
- `Photography`
- `Events (Dance, Catering etc.)`
- `Others`

### Telecaller

This is an internal operational role.

- Uses the same app shell, but sees a different set of tabs/pages.
- Can view available leads in a telecaller mode.
- Has dashboard/report pages.
- Can access telecaller-specific lead details and status tracking.
- Can assign an artist from the elite artist pool.

Telecaller workflow is separate from artist claim workflow. Telecaller activity is tracked through `team_lead_tracking`, `lead_activity`, and `status_master`.

### Admin / Backoffice

There is evidence of admin/backoffice behavior in the database and API, but not a full mobile admin UI.

- Admin users exist in the `users` table.
- Admin/backoffice likely manages:
  - plans
  - system settings
  - UI config
  - incoming leads
  - subscription/payment oversight
  - tutorial resources
  - telecaller operations

## 4. Role and Access Model

### Auth storage

The mobile app stores session state locally in `SharedPreferences`, including:

- `auth_token`
- `user_id`
- `level`
- `username`
- `role`
- `status`
- `business_name`
- cached profile data
- `fcm_token`

### Token model

- Login issues a server-generated API token.
- The token is stored in `users.api_token`.
- Tokens expire after 30 days via `users.token_expires`.
- Most API requests authenticate using that token.

### Effective permissions

The system uses a combination of:

- `role`
- `status`
- `level`
- subscription history
- artist profile category

to decide what a user can do.

### Important role/status rules

- No token: send user to login.
- `status = inactive`: send artist to subscription/paywall flow.
- `level = 5`: treated as unsubscribed/inactive in the app flow.
- `role = telecaller`: app uses telecaller dashboard, leads, report, and assignment flows.
- non-telecaller artist users: app uses artist dashboard, available leads, claims, resources, settings.

## 5. Subscription and Level Model

This app is strongly subscription-driven.

### Key idea

Artists do not get lead access by default. Registration creates an inactive account, and subscription purchase activates the account and upgrades the artist level.

### Known levels

The system uses numeric levels, and the current code behavior strongly suggests:

- `5` = unsubscribed / inactive / blocked from claiming
- `4` = trial plan
- `3` = basic plan
- `2` = extended/basic higher plan
- `1` = admin or highest internal privilege

This interpretation comes from `system_settings`, `subscription_history`, and payment activation code.

### Subscription effects

Successful subscription payment does all of the following:

- marks old subscriptions expired
- inserts a new active row in `subscription_history`
- updates `artist_profiles.artist_level`
- updates `users.status = active`
- updates `users.level` to the plan’s mapped `artist_level`

### Claim limits are plan-driven

`system_settings` controls plan behavior by `user_level`, including:

- `max_claims_per_day`
- `max_total_claims`
- `can_claim_leads`
- `claim_lock_duration_hours`
- `lead_visibility_delay_hours`
- `auto_release_inactive_hours`

Examples found in the dump:

- level 3 basic plan: total claims `50`
- level 4 trial plan: total claims `12`
- level 5 unsubscribed: claim limits `0`

### Payment systems

There are two payment paths in the repo:

- Razorpay: actively wired into Flutter subscription flow
- older PhonePe-style endpoints: still present in backend

The current mobile app appears to rely mainly on Razorpay.

## 6. End-to-End User Journeys

### Artist onboarding journey

1. User opens app.
2. Splash checks forced app update and optional Play Store update.
3. If not logged in, user goes to login/register.
4. Registration creates:
   - `users` row with `role = artist`, `status = inactive`, `level = 5`
   - `artist_profiles` row with category/business details
5. User is redirected to subscription page.
6. User selects a plan and pays.
7. Backend activates the account and sets plan level.
8. User enters artist shell and can work leads.

### Artist lead workflow

1. App fetches available leads using the artist token.
2. Backend filters leads by artist category.
3. Artist claims a lead.
4. Claim lock / daily limits / total limits are enforced.
5. Artist sees the lead in `My Claims`.
6. Artist updates lead status and adds notes.
7. Dashboard aggregates claim stats and recent lead activity.

### Telecaller workflow

1. Telecaller logs in with `role = telecaller`.
2. App switches to telecaller shell automatically.
3. Telecaller sees dashboard + available leads + interacted leads + report.
4. Telecaller updates statuses through team tracking.
5. Telecaller can assign an elite artist to a lead.
6. Activity is tracked in telecaller-specific tables and status mappings.

## 7. Frontend Structure

The Flutter app is mostly a single-feature mobile client with page-based architecture rather than a deep layered architecture.

### Key app entry files

- `lib/main.dart`
- `lib/splash_page.dart`
- `lib/main_shell.dart`

### Main artist pages

- `dashboard_page.dart`
- `available_leads_page.dart`
- `my_claims_page.dart`
- `new_lead_details.dart`
- `resources_page.dart`
- `settings_page.dart`
- `subscription.dart`

### Main telecaller pages

- `telecaller_dashboard_page.dart`
- `telecaller_leads_page.dart`
- `telecaller_report_page.dart`
- `assign_artist_page.dart`

### Support/auth pages

- `login_page.dart`
- `register_page.dart`
- `forgot_password_page.dart`
- `otp_verification_page.dart`
- `reset_password_page.dart`
- `update_req_screen.dart`

### Configuration/support files

- `lib/config/api_config.dart`
- `lib/utils/network_utils.dart`
- `lib/meta_events.dart`
- `lib/theme/bbm_theme.dart`

## 8. Navigation Model

The app uses a simple route table plus `MainShell`.

### Artist shell tabs

1. Home
2. Available Leads
3. My Claims
4. Resources
5. Settings

### Telecaller shell tabs

1. Home
2. Leads
3. My Leads
4. Report
5. Settings

Role detection is local and based on the stored `role` value in shared preferences.

## 9. UI / Theme / Brand Character

The product is function-first, not design-system heavy.

### Visual traits seen in code

- gradients, especially purple-blue on splash/login
- some pink branding on registration
- Material 3 base
- white card-heavy forms and dashboard surfaces
- Google Fonts used in parts of auth flow

### Brand/domain language

- bridal / wedding / booking
- artists
- vendors
- leads
- claims
- subscription
- tutorial resources

The UI tone suggests a sales-enablement/business app for Indian wedding/event vendors, not a consumer booking app.

## 10. Backend Architecture

The backend is a PHP API located in `mobile_api/`.

### Backend style

- plain PHP endpoints
- direct PDO access
- no visible modern framework in this folder
- many endpoints include `../app/config/database.php`
- JSON request/response model
- CORS headers added manually

### Architectural characteristics

- endpoint-per-use-case style
- thin controller + inline SQL approach
- business rules enforced directly in endpoint code
- token auth implemented at endpoint level
- heavy coupling to the live MySQL schema

This is not a REST API with clean resource abstraction. It is a pragmatic mobile backend with use-case endpoints.

## 11. Backend Endpoint Groups

### Authentication and profile

- `auth.php`
- `register.php`
- `get_profile.php`
- `update_artist_profile.php`
- password recovery endpoints

### Leads for artists

- `all_leads.php`
- `claim_leads.php`
- `release.php`
- `lead_details.php`
- `update_status.php`
- `add_new_note.php`
- `stats.php`
- `get_followup_status.php`

### Telecaller operations

- `telecaller_dashboard.php`
- `telecaller_my_leads.php`
- `telecaller_report.php`
- `assign_artist.php`
- `elite_artists.php`

### Subscription/payments

- `subscriptions/get_subscription_plans.php`
- `subscriptions/create_order.php`
- `subscriptions/confirm_razorpay_payment.php`
- `subscriptions/razorpay_webhook.php`
- legacy payment endpoints also exist at top level

### Content/config

- `get_ui_config.php`
- `tutorial_videos.php`
- `subscription-intro-video.php`

### Platform/ops

- `check_app_version.php`
- `save_fcm_token.php`
- `send_fcm.php`
- `check_new_leads.php`
- `release.php`

## 12. Core Data Model

The most important business entities are:

### `users`

Holds identity/session basics.

Important fields:

- `id`
- `username`
- `password_hash`
- `role`
- `status`
- `level`
- `api_token`
- `fcm_token`
- `token_expires`

Important note:

- The SQL dump shows `role` enum values `admin`, `artist`, `lead_manager`.
- The live code clearly expects `telecaller`.
- This means the dump is probably older than the current production schema, or the schema was altered later.

### `artist_profiles`

Holds artist/vendor business metadata.

Important fields:

- `user_id`
- `business_name`
- `contact_person_name`
- `whatsapp_number`
- `instagram_handle`
- `facebook_page`
- `website_url`
- `location`
- `artist_level`
- `is_active`
- `category`
- `coupon_code`

### `leads`

The core monetizable unit of the system.

Important fields:

- `lead_source`
- `customer_name`
- `whatsapp_number`
- `event_date`
- `event_type`
- `services_required`
- `location`
- `budget_range`
- `additional_info`
- `status`
- `claimed_by`
- `claim_time`
- `claim_expiry`
- `claim_count`
- `is_locked`
- `notified`
- `max_claims_allowed`

Observations:

- `event_type` can be JSON-like or plain text.
- `services_required` is used for category matching.
- many leads appear sourced from Meta campaigns.

### `subscription_history`

Tracks purchased/trial subscription periods.

Important fields:

- `user_id`
- `plan_id`
- `plan_name`
- `subscription_type`
- `start_date`
- `end_date`
- `total_leads_claimed`
- `payment_id`
- `order_id`
- `amount_paid`
- `currency`
- `status`

### `system_settings`

This is a very important business-rules table.

It drives behavior like:

- visibility delay
- claim locks
- daily/total claim limits
- whether a level can claim at all
- auto release

### `app_ui_config`

Acts like a mini CMS/config store for app copy/content by screen.

Used for screens such as:

- subscription
- available leads
- resources

### Telecaller-related entities

The telecaller side uses additional entities including:

- `team_lead_tracking`
- `lead_activity`
- `status_master`
- `elite_clients`

These support assignment, workflow stages, activity logging, and elite artist matching.

## 13. Lead Distribution Logic

### Artist lead visibility rules

Artists do not see all leads. The backend filters by:

- valid token
- role not telecaller
- artist profile category
- event date not too close
- visibility delay hours
- lead not already fully claimed
- lead not already claimed by the same user before
- lead still available/unlocked

### Telecaller lead visibility rules

Telecallers use a different query path and are not category-filtered the same way.

### Claiming behavior

Claiming a lead enforces:

- active token
- active user status
- active subscription
- total subscription claim limit
- daily claim limit by user level
- event date validity
- lead not already actively claimed by same user
- lead not already fully claimed by too many users

### Subscription expiry on overuse

When total claims reach plan limit:

- subscription row is marked expired
- user is downgraded to inactive
- user level is set back to `5`

This is a critical business rule.

## 14. Status Tracking Model

There are effectively two status systems in this project.

### Artist status flow

Artists update statuses on claimed leads. Observed statuses include:

- `new`
- `contacted`
- `booked`
- `follow_up`
- `closed`

Artist notes are stored separately and returned per-user for the lead.

### Telecaller status flow

Telecaller statuses are more workflow-driven and use `status_master`.

Examples inferred from code:

- `assigned`
- `interested`
- `callback_needed`

Telecaller activity is logged in `lead_activity`, and the latest status is tracked through `team_lead_tracking.current_status_id`.

## 15. Content and Training Model

The app includes gated training/tutorial content.

### Resources page

- loads tutorial videos from the backend
- uses Wistia embeds
- respects per-user access flags
- hides/locks content if the user lacks access

### Subscription intro content

- separate endpoint returns a free/intro video
- used on the subscription/paywall screen

This means the product is not only a lead marketplace; it also includes enablement/training content for vendors.

## 16. External Integrations

### Firebase

- Firebase Core
- Firebase Cloud Messaging
- local notifications for foreground push display

### Razorpay

- plan purchase flow
- order creation
- payment verification
- webhook support

### Wistia

- tutorial and intro videos via WebView/embed HTML

### Meta / Facebook

- Facebook App Events used in onboarding/payment funnel analytics
- lead source data in SQL strongly suggests Meta campaigns feed the lead system

### In-app updates

- Android Play Store update checks

### SharedPreferences

- used as the main local session/cache layer

## 17. Operational / Runtime Behavior

### Splash responsibilities

On app launch, splash handles:

- forced version check via backend
- optional Play Store update
- auth/session check
- status/level gate
- initial route decision

### Notification behavior

- requests notification permissions
- stores FCM token locally
- uploads FCM token once logged in
- handles foreground and background push flows

### Connectivity behavior

Several pages explicitly handle:

- no internet state
- retry UI
- session-expired UI

## 18. Important Business Assumptions an AI Should Keep in Mind

1. This is a revenue-driven lead-access product, not just a CRM.
2. Subscription state is central to app behavior.
3. Role-based UX is significant: artist and telecaller are different products inside one shell.
4. Category matching matters for artist lead access.
5. `level` is not cosmetic; it drives permissions and limits.
6. Database-driven UI config means some UI text/points are not hardcoded.
7. Telecaller features use a separate tracking/status model from artist claims.

## 19. Known Inconsistencies / Risks / Caveats

These are important for any AI modifying this project.

### Mixed payment history

Both Razorpay and older payment endpoints exist. Avoid assuming every payment path is active.

### Security concerns

Observed concerns in the repo:

- hardcoded Razorpay secret in backend code
- Firebase service account JSON stored in repo
- token auth is simple and endpoint-local

Any security-sensitive refactor should be handled carefully.

### Architecture style

The backend is procedural and tightly coupled to schema. Changes often require coordinated updates across:

- Flutter request payloads
- endpoint logic
- database fields
- local shared preference assumptions

## 20. Best Mental Model for Another AI

If another AI needs to work on this project, it should think of BBM as:

"A Flutter mobile client for a subscription-based bridal/event vendor lead marketplace, backed by a procedural PHP API and MySQL database, where artists pay to unlock category-matched leads and telecallers run an internal assignment/tracking workflow on the same lead pool."

## 21. High-Confidence File Map

Frontend:

- `lib/main.dart`
- `lib/splash_page.dart`
- `lib/main_shell.dart`
- `lib/login_page.dart`
- `lib/register_page.dart`
- `lib/dashboard_page.dart`
- `lib/available_leads_page.dart`
- `lib/my_claims_page.dart`
- `lib/new_lead_details.dart`
- `lib/settings_page.dart`
- `lib/subscription.dart`
- `lib/resources_page.dart`
- `lib/telecaller_dashboard_page.dart`
- `lib/telecaller_leads_page.dart`
- `lib/telecaller_report_page.dart`
- `lib/assign_artist_page.dart`
- `lib/config/api_config.dart`

Backend:

- `mobile_api/auth.php`
- `mobile_api/register.php`
- `mobile_api/get_profile.php`
- `mobile_api/all_leads.php`
- `mobile_api/claim_leads.php`
- `mobile_api/lead_details.php`
- `mobile_api/update_status.php`
- `mobile_api/telecaller_dashboard.php`
- `mobile_api/telecaller_my_leads.php`
- `mobile_api/assign_artist.php`
- `mobile_api/get_ui_config.php`
- `mobile_api/tutorial_videos.php`
- `mobile_api/subscriptions/get_subscription_plans.php`
- `mobile_api/subscriptions/confirm_razorpay_payment.php`

Supporting project docs:

- `README.md`
- `API_README.md`
- `BBM_INTEGRATION_GUIDE.md`
- `u888578780_bbm.sql`

## 22. Suggested Usage

If this file is being fed into another AI system, it should be used as:

- primary project briefing/context
- onboarding context before code changes
- a checklist for tracing auth, subscriptions, roles, and lead behavior

It should not be treated as a perfect source of truth over runtime production data. For schema-level changes, another AI should still verify against the current backend code and any live database migrations.

# BBM Mobile API Summary

A PHP API powering the BBM mobile app. It authenticates users, manages artist profiles, lead availability/claiming, status updates, subscriptions/payments, UI config, tutorial resources, and FCM notifications. It connects directly to the BBM MySQL database via `app/config/database.php`.

## Core Endpoints
- `auth.php`: Login. Verifies password, issues API token, stores token + 30‑day expiry.
- `register.php`: Registers artist as `inactive` level 5, inserts `artist_profiles`, generates token, sends admin email.
- `get_profile.php`: Returns artist profile + user info; maps `is_active` to `Active/Inactive`.
- `update_artist_profile.php`: Updates username (unique) and allowed profile fields with validation.
- `get_ui_config.php`: Returns key/value UI config by screen.

### Leads
- `all_leads.php`: Returns available leads filtered by user category, visibility delay, max claims, and exclusion of previously claimed leads; auto-resets expired claims.
- `claim_leads.php`: Enforces per‑day and per‑lead claim limits, locks lead, logs claim + status history.
- `stats.php`: Aggregates lead stats based on `lead_status_history`.
- `lead_details.php`: Returns lead detail with normalized event type/requirements and release status.
- `update_status.php`: Validates ownership (current or previous), updates status, logs history, applies lock rules.
- `release.php`: Releases claimed lead (clears claim fields).

### Resources
- `tutorial_videos.php`: Returns paid videos with per‑user access control.
- `subscription-intro-video.php`: Returns the first free tutorial video.

### Notifications
- `save_fcm_token.php`: Stores FCM token on user record.
- `send_fcm.php`: Sends FCM notifications to all or category‑matched users (uses service account).
- `check_new_leads.php`: Marks new leads as notified and triggers FCM sends.
- `test_push.php`: Manual FCM test sender.

### Subscriptions (Razorpay)
- `subscriptions/get_subscription_plans.php`: Lists active plans.
- `subscriptions/create_order.php`: Creates Razorpay order and inserts pending transaction.
- `subscriptions/confirm_razorpay_payment.php`: Verifies signature, marks transaction success, activates user/artist level.
- `subscriptions/razorpay_webhook.php`: Marks transaction success on Razorpay webhook.

### Other (PhonePe-style)
- `create_order.php`, `check_order_status.php`, `payment_callback.php`: PhonePe-style order lifecycle (sandbox + callback).

## Notable Implementation Details
- Tokens are stored in `users.api_token` with `token_expires`.
- Several endpoints set server timezone to `Asia/Kolkata`.
- Lead claiming uses `system_settings` (e.g., max claims per day, lock duration).
- Razorpay keys are hardcoded in API (live key/secret).
- Firebase service account JSON is stored in `mobile_api/firebase-service-account.json`.

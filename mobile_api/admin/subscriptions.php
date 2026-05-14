<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['GET']);
admin_require_user(['admin', 'lead_manager']);

$pdo = admin_get_pdo();

$plans = $pdo->query(
    "SELECT id, slug, name, price_integer, currency, description, active, duration_days, artist_level
     FROM subscription_plans
     ORDER BY artist_level ASC, id ASC"
)->fetchAll();

$settingsRows = $pdo->query(
    "SELECT setting_key, user_level, setting_value
     FROM system_settings
     WHERE setting_key IN ('max_total_claims', 'max_claims_per_day', 'can_claim_leads', 'lead_visibility_delay_hours', 'claim_lock_duration_hours', 'auto_release_inactive_hours', 'max_claims_per_lead', 'notification_email_enabled')"
)->fetchAll();

$settingsMap = [];
foreach ($settingsRows as $row) {
    $settingsMap[$row['setting_key']][(int)$row['user_level']] = $row['setting_value'];
}

$subscriberCounts = $pdo->query(
    "SELECT plan_id, COUNT(*) AS subscribers
     FROM subscription_history
     WHERE status = 'active'
     GROUP BY plan_id"
)->fetchAll();

$subscribersByPlan = [];
foreach ($subscriberCounts as $row) {
    $subscribersByPlan[(int)$row['plan_id']] = (int)$row['subscribers'];
}

$formattedPlans = array_map(
    static function (array $plan) use ($settingsMap, $subscribersByPlan): array {
        $level = (int)$plan['artist_level'];
        return [
            'id' => (int)$plan['id'],
            'slug' => (string)$plan['slug'],
            'name' => (string)$plan['name'],
            'level' => $level,
            'price' => (int)round(((int)$plan['price_integer']) / 100),
            'duration_days' => (int)$plan['duration_days'],
            'total_claims' => (int)($settingsMap['max_total_claims'][$level] ?? 0),
            'daily_claims' => (int)($settingsMap['max_claims_per_day'][$level] ?? 0),
            'visibility_delay_hours' => (int)($settingsMap['lead_visibility_delay_hours'][$level] ?? $settingsMap['lead_visibility_delay_hours'][3] ?? 0),
            'claim_lock_duration_hours' => (int)($settingsMap['claim_lock_duration_hours'][$level] ?? $settingsMap['claim_lock_duration_hours'][3] ?? 0),
            'auto_release_hours' => (int)($settingsMap['auto_release_inactive_hours'][$level] ?? $settingsMap['auto_release_inactive_hours'][3] ?? 0),
            'can_claim' => ((string)($settingsMap['can_claim_leads'][$level] ?? '0')) === '1',
            'active' => ((int)$plan['active']) === 1,
            'subscribers' => $subscribersByPlan[(int)$plan['id']] ?? 0,
        ];
    },
    $plans
);

$historyRows = $pdo->query(
    "SELECT sh.id, sh.plan_name, sh.amount_paid, sh.start_date, sh.end_date, sh.status, sh.payment_id,
            COALESCE(ap.contact_person_name, ap.business_name, u.username) AS display_name
     FROM subscription_history sh
     INNER JOIN users u ON u.id = sh.user_id
     LEFT JOIN artist_profiles ap ON ap.user_id = u.id
     ORDER BY sh.created_at DESC, sh.id DESC
     LIMIT 150"
)->fetchAll();

$history = array_map(
    static function (array $row): array {
        return [
            'id' => 'SUB' . $row['id'],
            'user' => $row['display_name'] ?: 'Subscriber',
            'plan' => (string)$row['plan_name'],
            'amount' => (int)round((float)$row['amount_paid']),
            'date' => admin_format_datetime($row['start_date']) ?? '',
            'status' => (string)$row['status'],
            'payment_id' => $row['payment_id'],
            'expiry' => admin_format_datetime($row['end_date']) ?? '',
        ];
    },
    $historyRows
);

$globalSettings = [
    'lead_auto_release_hours' => (int)($settingsMap['auto_release_inactive_hours'][3] ?? 0),
    'lead_visibility_delay_hours' => (int)($settingsMap['lead_visibility_delay_hours'][3] ?? 0),
    'claim_lock_duration_hours' => (int)($settingsMap['claim_lock_duration_hours'][3] ?? 0),
    'max_claims_per_lead' => (int)($settingsMap['max_claims_per_lead'][3] ?? 0),
    'fcm_push_notifications' => ((string)($settingsMap['notification_email_enabled'][3] ?? '1')) === '1',
];

admin_success([
    'plans' => $formattedPlans,
    'history' => $history,
    'global_settings' => $globalSettings,
]);

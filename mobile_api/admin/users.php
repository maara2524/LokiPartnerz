<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['GET']);
admin_require_user(['admin', 'lead_manager']);

$pdo = admin_get_pdo();

$sql = "
    SELECT
        u.id,
        u.username,
        u.email,
        u.role,
        u.status,
        u.level,
        u.created_at,
        ap.business_name,
        ap.contact_person_name,
        ap.whatsapp_number,
        ap.location,
        ap.category,
        t.display_name AS team_display_name,
        t.phone AS team_phone,
        t.email AS team_email,
        sh.plan_name,
        sh.total_leads_claimed,
        sh.status AS subscription_status,
        sh.end_date
    FROM users u
    LEFT JOIN artist_profiles ap ON ap.user_id = u.id
    LEFT JOIN teams t ON t.user_id = u.id AND t.role = 'telecaller'
    LEFT JOIN (
        SELECT sh1.*
        FROM subscription_history sh1
        INNER JOIN (
            SELECT user_id, MAX(id) AS max_id
            FROM subscription_history
            GROUP BY user_id
        ) latest ON latest.max_id = sh1.id
    ) sh ON sh.user_id = u.id
    WHERE u.role IN ('artist', 'telecaller', 'admin', 'lead_manager')
    ORDER BY u.created_at DESC, u.id DESC
";

$rows = $pdo->query($sql)->fetchAll();

$users = array_map(
    static function (array $row): array {
        $role = (string)($row['role'] ?? 'artist');
        $name = $role === 'telecaller'
            ? trim((string)($row['team_display_name'] ?? ''))
            : trim((string)($row['contact_person_name'] ?? ''));
        if ($name === '') {
            $name = trim((string)($row['business_name'] ?? ''));
        }
        if ($name === '') {
            $name = (string)($row['username'] ?? ('User #' . $row['id']));
        }

        $subscriptionStatus = (string)($row['subscription_status'] ?? '');
        $planName = (string)($row['plan_name'] ?? '');
        if ($role === 'telecaller') {
            $planName = 'Staff';
        } elseif ($planName === '') {
            $planName = $subscriptionStatus === 'expired' ? 'Expired' : 'None';
        }

        $business = $role === 'telecaller'
            ? 'BBM Internal'
            : (string)($row['business_name'] ?? '');
        $phone = $role === 'telecaller'
            ? (string)($row['team_phone'] ?? '')
            : (string)($row['whatsapp_number'] ?? '');

        return [
            'id' => (int)$row['id'],
            'username' => (string)$row['username'],
            'name' => $name,
            'email' => $role === 'telecaller' ? ($row['team_email'] ?: $row['email']) : $row['email'],
            'role' => $role,
            'status' => (string)$row['status'],
            'level' => (int)$row['level'],
            'category' => $role === 'artist' ? admin_normalize_category($row['category'] ?? 'Makeup') : '-',
            'business' => $business,
            'location' => (string)($row['location'] ?? ''),
            'phone' => $phone,
            'claims' => (int)($row['total_leads_claimed'] ?? 0),
            'plan' => $planName,
            'joined' => admin_format_datetime($row['created_at']) ?? '',
            'subscription_status' => $subscriptionStatus,
            'subscription_end_date' => $row['end_date'],
        ];
    },
    $rows
);

admin_success(['users' => $users]);

<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['GET']);
admin_require_user(['admin', 'lead_manager']);

$pdo = admin_get_pdo();

$stats = [
    'totalUsers' => (int)$pdo->query('SELECT COUNT(*) FROM users')->fetchColumn(),
    'activeArtists' => (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'artist' AND status = 'active'")->fetchColumn(),
    'inactiveArtists' => (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'artist' AND status = 'inactive'")->fetchColumn(),
    'totalLeads' => (int)$pdo->query('SELECT COUNT(*) FROM leads')->fetchColumn(),
    'openLeads' => (int)$pdo->query("SELECT COUNT(*) FROM leads WHERE status = 'new' AND (claimed_by IS NULL OR claimed_by = 0)")->fetchColumn(),
    'claimedLeads' => (int)$pdo->query("SELECT COUNT(*) FROM leads WHERE claimed_by IS NOT NULL AND claimed_by != 0 AND status IN ('new', 'contacted', 'follow_up')")->fetchColumn(),
    'bookedLeads' => (int)$pdo->query("SELECT COUNT(*) FROM leads WHERE status = 'booked'")->fetchColumn(),
    'revenue' => (float)$pdo->query("SELECT COALESCE(SUM(amount_paid), 0) FROM subscription_history")->fetchColumn(),
    'activeSubscriptions' => (int)$pdo->query("SELECT COUNT(*) FROM subscription_history WHERE status = 'active'")->fetchColumn(),
    'expiredSubscriptions' => (int)$pdo->query("SELECT COUNT(*) FROM subscription_history WHERE status IN ('expired', 'limit_reached', 'cancelled')")->fetchColumn(),
    'telecallers' => (int)$pdo->query("SELECT COUNT(*) FROM teams WHERE role = 'telecaller' AND active = 1")->fetchColumn(),
];

$activityRows = [];

$userActivity = $pdo->query(
    "SELECT created_at AS activity_at, username AS name, role
     FROM users
     ORDER BY created_at DESC
     LIMIT 6"
)->fetchAll();

foreach ($userActivity as $row) {
    $activityRows[] = [
        'type' => 'new_user',
        'name' => $row['name'] ?: 'New user',
        'detail' => 'Registered as ' . ucfirst((string)$row['role']),
        'time' => admin_humanize_relative($row['activity_at']),
        'activity_at' => $row['activity_at'],
    ];
}

$leadActivity = $pdo->query(
    "SELECT created_at AS activity_at, customer_name, services_required, id
     FROM leads
     ORDER BY created_at DESC
     LIMIT 6"
)->fetchAll();

foreach ($leadActivity as $row) {
    $services = json_decode((string)($row['services_required'] ?? ''), true);
    $serviceLabel = is_array($services) && !empty($services) ? implode(', ', $services) : 'Lead';
    $activityRows[] = [
        'type' => 'lead',
        'name' => $row['customer_name'] ?: 'Lead #' . $row['id'],
        'detail' => 'Lead #' . $row['id'] . ' created for ' . $serviceLabel,
        'time' => admin_humanize_relative($row['activity_at']),
        'activity_at' => $row['activity_at'],
    ];
}

$subscriptionActivity = $pdo->query(
    "SELECT sh.created_at AS activity_at, sh.plan_name, sh.amount_paid,
            COALESCE(ap.contact_person_name, u.username) AS display_name
     FROM subscription_history sh
     INNER JOIN users u ON u.id = sh.user_id
     LEFT JOIN artist_profiles ap ON ap.user_id = u.id
     ORDER BY sh.created_at DESC
     LIMIT 6"
)->fetchAll();

foreach ($subscriptionActivity as $row) {
    $activityRows[] = [
        'type' => 'subscription',
        'name' => $row['display_name'] ?: 'Subscriber',
        'detail' => 'Subscribed to ' . $row['plan_name'] . ' - Rs ' . number_format((float)$row['amount_paid'], 2),
        'time' => admin_humanize_relative($row['activity_at']),
        'activity_at' => $row['activity_at'],
    ];
}

usort(
    $activityRows,
    static fn(array $a, array $b): int => strtotime((string)$b['activity_at']) <=> strtotime((string)$a['activity_at'])
);

$recentActivity = array_map(
    static function (array $row): array {
        unset($row['activity_at']);
        return $row;
    },
    array_slice($activityRows, 0, 8)
);

$categoryRows = $pdo->query(
    "SELECT TRIM(category) AS category, COUNT(*) AS artist_count
     FROM artist_profiles
     WHERE is_active = 1
     GROUP BY TRIM(category)
     ORDER BY artist_count DESC"
)->fetchAll();

$categoryTotal = array_sum(array_map(static fn(array $row): int => (int)$row['artist_count'], $categoryRows));
$categoryBreakdown = [];

foreach ($categoryRows as $row) {
    $count = (int)$row['artist_count'];
    $categoryBreakdown[] = [
        'category' => admin_normalize_category($row['category'] ?? 'Makeup'),
        'count' => $count,
        'pct' => $categoryTotal > 0 ? round($count / $categoryTotal, 4) : 0,
    ];
}

admin_success([
    'stats' => $stats,
    'recent_activity' => $recentActivity,
    'category_breakdown' => $categoryBreakdown,
]);

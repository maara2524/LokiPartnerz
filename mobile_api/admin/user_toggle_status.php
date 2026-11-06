<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);
$input = admin_get_input();

$userId = (int)($input['id'] ?? 0);
$status = trim((string)($input['status'] ?? ''));

if ($userId <= 0 || !in_array($status, ['active', 'inactive'], true)) {
    admin_error('Invalid status update request');
}

$pdo = admin_get_pdo();
$stmt = $pdo->prepare('SELECT id, role FROM users WHERE id = ? LIMIT 1');
$stmt->execute([$userId]);
$user = $stmt->fetch();

if (!$user) {
    admin_error('User not found', 404);
}

$level = null;
if ($user['role'] === 'artist') {
    $level = 5;

    if ($status === 'active') {
        $subscriptionStmt = $pdo->prepare("
            SELECT COALESCE(NULLIF(sp.artist_level, 0), u.level) AS artist_level,
                   sh.total_leads_claimed,
                   COALESCE(
                       NULLIF(sh.max_claim_limit, 0),
                       CAST(ss.setting_value AS UNSIGNED),
                       0
                   ) AS max_claim_limit
            FROM users u
            INNER JOIN subscription_history sh
                ON sh.user_id = u.id
               AND sh.status = 'active'
               AND sh.end_date > NOW()
            LEFT JOIN subscription_plans sp ON sp.id = sh.plan_id
            LEFT JOIN system_settings ss
                ON ss.setting_key = 'max_total_claims'
               AND ss.user_level = COALESCE(NULLIF(sp.artist_level, 0), u.level)
            WHERE u.id = ?
            ORDER BY sh.start_date DESC, sh.id DESC
            LIMIT 1
        ");
        $subscriptionStmt->execute([$userId]);
        $subscription = $subscriptionStmt->fetch();

        if (!$subscription
            || (int)$subscription['max_claim_limit'] <= (int)$subscription['total_leads_claimed']) {
            admin_error('Grant an active subscription before activating this artist');
        }

        $level = (int)$subscription['artist_level'];
        if ($level <= 0 || $level === 5) {
            admin_error('The active subscription has an invalid artist level');
        }
    }
}

$pdo->beginTransaction();

try {
    if ($level !== null) {
        $updateUser = $pdo->prepare('UPDATE users SET status = ?, level = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
        $updateUser->execute([$status, $level, $userId]);

        $updateProfile = $pdo->prepare('UPDATE artist_profiles SET is_active = ?, artist_level = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?');
        $updateProfile->execute([$status === 'active' ? 1 : 0, (string)$level, $userId]);
    } else {
        $updateUser = $pdo->prepare('UPDATE users SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
        $updateUser->execute([$status, $userId]);

        $updateTeam = $pdo->prepare('UPDATE teams SET active = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?');
        $updateTeam->execute([$status === 'active' ? 1 : 0, $userId]);
    }

    $pdo->commit();
    admin_success(['message' => 'User status updated']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    admin_error($e->getMessage(), 400);
}

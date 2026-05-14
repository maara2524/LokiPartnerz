<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
$adminUser = admin_require_user(['admin']);

$input = admin_get_input();
$userId = (int)($input['id'] ?? 0);
$planSlug = trim((string)($input['plan_slug'] ?? ''));

if ($userId <= 0 || $planSlug === '') {
    admin_error('User and plan are required');
}

if (!in_array($planSlug, ['trial', 'basic', 'extended_basic'], true)) {
    admin_error('Unsupported plan selected');
}

$pdo = admin_get_pdo();
$planStmt = $pdo->prepare('SELECT id, name, duration_days, price_integer, currency, artist_level FROM subscription_plans WHERE slug = ? LIMIT 1');
$planStmt->execute([$planSlug]);
$plan = $planStmt->fetch();

if (!$plan) {
    admin_error('Plan not found', 404);
}

$limitStmt = $pdo->prepare('SELECT setting_value FROM system_settings WHERE setting_key = ? AND user_level = ? LIMIT 1');
$limitStmt->execute(['max_total_claims', (int)$plan['artist_level']]);
$maxClaimLimit = (int)($limitStmt->fetchColumn() ?: 0);

$pdo->beginTransaction();

try {
    $pdo->prepare("UPDATE subscription_history SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND status = 'active'")
        ->execute([$userId]);

    $startDate = new DateTimeImmutable('now');
    $endDate = $startDate->modify('+' . (int)$plan['duration_days'] . ' days');

    $insertHistory = $pdo->prepare(
        'INSERT INTO subscription_history
            (user_id, plan_id, plan_name, subscription_type, start_date, end_date, total_leads_claimed, amount_paid, currency, status, created_at, updated_at, max_claim_limit)
         VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?)'
    );
    $insertHistory->execute([
        $userId,
        $plan['id'],
        $plan['name'],
        $planSlug === 'trial' ? 'trial' : 'paid',
        $startDate->format('Y-m-d H:i:s'),
        $endDate->format('Y-m-d H:i:s'),
        (float)$plan['price_integer'],
        $plan['currency'] ?: 'INR',
        'active',
        $maxClaimLimit,
    ]);

    $pdo->prepare("UPDATE users SET status = 'active', level = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?")
        ->execute([(int)$plan['artist_level'], $userId]);

    $pdo->prepare("UPDATE artist_profiles SET is_active = 1, artist_level = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?")
        ->execute([(string)$plan['artist_level'], $userId]);

    $pdo->commit();

    admin_success(['message' => $plan['name'] . ' granted successfully']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log('Admin grant plan failed: ' . $e->getMessage());
    admin_error('Unable to grant plan. Please try again.', 500);
}

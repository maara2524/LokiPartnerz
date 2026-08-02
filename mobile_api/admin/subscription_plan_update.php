<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
$adminUser = admin_require_user(['admin']);
$input = admin_get_input();

$planId = (int)($input['id'] ?? 0);
$name = trim((string)($input['name'] ?? ''));
$price = (int)($input['price'] ?? 0);
$durationDays = (int)($input['duration_days'] ?? 0);
$totalClaims = (int)($input['total_claims'] ?? 0);
$dailyClaims = (int)($input['daily_claims'] ?? 0);
$visibilityDelay = (int)($input['visibility_delay_hours'] ?? 0);
$lockDuration = (int)($input['claim_lock_duration_hours'] ?? 0);
$autoRelease = (int)($input['auto_release_hours'] ?? 0);
$canClaim = !empty($input['can_claim']) ? '1' : '0';
$active = !empty($input['active']) ? 1 : 0;

if ($planId <= 0 || $name === '' || $durationDays < 0) {
    admin_error('Invalid subscription plan payload');
}

$pdo = admin_get_pdo();
$planStmt = $pdo->prepare('SELECT id, artist_level FROM subscription_plans WHERE id = ? LIMIT 1');
$planStmt->execute([$planId]);
$plan = $planStmt->fetch();

if (!$plan) {
    admin_error('Plan not found', 404);
}

$level = (int)$plan['artist_level'];

$pdo->beginTransaction();

try {
    $updatePlan = $pdo->prepare(
        'UPDATE subscription_plans
         SET name = ?, price_integer = ?, duration_days = ?, active = ?, description = ?
         WHERE id = ?'
    );
    $updatePlan->execute([
        $name,
        $price * 100,
        $durationDays,
        $active,
        $name . ' - managed from admin UI',
        $planId,
    ]);

    admin_upsert_system_setting($pdo, 'max_total_claims', (string)$totalClaims, (int)$adminUser['id'], $level, 'Plan total claim limit');
    admin_upsert_system_setting($pdo, 'max_claims_per_day', (string)$dailyClaims, (int)$adminUser['id'], $level, 'Plan daily claim limit');
    admin_upsert_system_setting($pdo, 'can_claim_leads', $canClaim, (int)$adminUser['id'], $level, 'Plan can claim leads');
    admin_upsert_system_setting($pdo, 'lead_visibility_delay_hours', (string)$visibilityDelay, (int)$adminUser['id'], $level, 'Lead visibility delay');
    admin_upsert_system_setting($pdo, 'claim_lock_duration_hours', (string)$lockDuration, (int)$adminUser['id'], $level, 'Claim lock duration');
    admin_upsert_system_setting($pdo, 'auto_release_inactive_hours', (string)$autoRelease, (int)$adminUser['id'], $level, 'Auto release hours');

    $pdo->commit();
    admin_success(['message' => 'Plan updated successfully']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    admin_error($e->getMessage(), 400);
}

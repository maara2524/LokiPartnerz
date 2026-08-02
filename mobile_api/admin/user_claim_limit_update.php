<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);

$input = admin_get_input();
$userId = (int)($input['id'] ?? 0);
$maxClaimLimit = (int)($input['max_claim_limit'] ?? -1);

if ($userId <= 0 || $maxClaimLimit < 0) {
    admin_error('User and lead allowance are required');
}

$pdo = admin_get_pdo();
$pdo->beginTransaction();

try {
    $userStmt = $pdo->prepare('SELECT id, role, status, level FROM users WHERE id = ? FOR UPDATE');
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch();

    if (!$user) {
        throw new RuntimeException('User not found');
    }

    if (($user['role'] ?? '') !== 'artist') {
        throw new RuntimeException('Lead allowance can only be updated for artists');
    }

    $subscriptionStmt = $pdo->prepare(
        'SELECT id, plan_id, plan_name, status, end_date, total_leads_claimed, max_claim_limit
         FROM subscription_history
         WHERE user_id = ?
         ORDER BY id DESC
         LIMIT 1
         FOR UPDATE'
    );
    $subscriptionStmt->execute([$userId]);
    $subscription = $subscriptionStmt->fetch();

    if (!$subscription) {
        throw new RuntimeException('Grant a plan before giving extra leads');
    }

    $claimed = (int)$subscription['total_leads_claimed'];
    if ($maxClaimLimit < $claimed) {
        throw new RuntimeException('Allowance cannot be lower than already claimed leads');
    }

    $status = (string)$subscription['status'];
    if ($status !== 'active') {
        if (!in_array($status, ['expired', 'limit_reached'], true)) {
            throw new RuntimeException('Grant a new plan before changing this subscription');
        }

        $endDate = strtotime((string)$subscription['end_date']);
        if ($endDate !== false && $endDate < time()) {
            throw new RuntimeException('Subscription period has ended. Grant a new plan first');
        }

        if ($maxClaimLimit <= $claimed) {
            throw new RuntimeException('Allowance must be greater than claimed leads to reactivate');
        }
    }

    $planLevel = (int)$user['level'];
    if ((int)$subscription['plan_id'] > 0) {
        $planStmt = $pdo->prepare('SELECT artist_level FROM subscription_plans WHERE id = ? LIMIT 1');
        $planStmt->execute([(int)$subscription['plan_id']]);
        $planLevel = (int)($planStmt->fetchColumn() ?: $planLevel);
    }

    $newStatus = $maxClaimLimit > $claimed ? 'active' : $status;

    $updateSubscription = $pdo->prepare(
        'UPDATE subscription_history
         SET max_claim_limit = ?, status = ?, updated_at = CURRENT_TIMESTAMP
         WHERE id = ?'
    );
    $updateSubscription->execute([$maxClaimLimit, $newStatus, (int)$subscription['id']]);

    if ($newStatus === 'active') {
        $pdo->prepare('UPDATE users SET status = ? , level = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
            ->execute(['active', $planLevel, $userId]);
        $pdo->prepare('UPDATE artist_profiles SET is_active = 1, artist_level = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?')
            ->execute([(string)$planLevel, $userId]);
    }

    $pdo->commit();

    admin_success([
        'message' => 'Lead allowance updated',
        'subscription' => [
            'id' => (int)$subscription['id'],
            'plan' => (string)$subscription['plan_name'],
            'status' => $newStatus,
            'total_leads_claimed' => $claimed,
            'max_claim_limit' => $maxClaimLimit,
            'balance' => max(0, $maxClaimLimit - $claimed),
            'level' => $planLevel,
        ],
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    admin_error($e->getMessage(), 400);
}

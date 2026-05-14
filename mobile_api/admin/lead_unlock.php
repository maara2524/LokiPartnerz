<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin', 'lead_manager']);

$input = admin_get_input();
$leadId = (int)($input['id'] ?? 0);

if ($leadId <= 0) {
    admin_error('Invalid lead id');
}

$pdo = admin_get_pdo();
$leadStmt = $pdo->prepare(
    'SELECT id, claimed_by
     FROM leads
     WHERE id = ?
     LIMIT 1'
);
$leadStmt->execute([$leadId]);
$lead = $leadStmt->fetch();

if (!$lead) {
    admin_error('Lead not found', 404);
}

$pdo->beginTransaction();
try {
    $claimedBy = (int)($lead['claimed_by'] ?? 0);
    if ($claimedBy > 0) {
        $releaseLog = $pdo->prepare(
            "UPDATE claimed_leads_log
             SET release_time = NOW(), release_reason = 'admin_unlock'
             WHERE lead_id = ? AND user_id = ? AND release_time IS NULL"
        );
        $releaseLog->execute([$leadId, $claimedBy]);
    }

    $stmt = $pdo->prepare(
        'UPDATE leads
         SET is_locked = 0, is_claimed = 0, claimed_by = NULL, claim_time = NULL, claim_expiry = NULL, updated_at = CURRENT_TIMESTAMP
         WHERE id = ?'
    );
    $stmt->execute([$leadId]);

    $pdo->commit();
    admin_success(['message' => 'Lead unlocked successfully']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log('Admin lead unlock failed: ' . $e->getMessage());
    admin_error('Unable to unlock lead. Please try again.', 500);
}

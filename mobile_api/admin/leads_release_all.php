<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);

$pdo = admin_get_pdo();
$pdo->beginTransaction();

try {
    $lockedStmt = $pdo->query(
        'SELECT id, claimed_by
         FROM leads
         WHERE is_locked = 1 AND claimed_by IS NOT NULL AND claimed_by != 0'
    );
    $lockedClaims = $lockedStmt->fetchAll();

    $releaseLog = $pdo->prepare(
        "UPDATE claimed_leads_log
         SET release_time = NOW(), release_reason = 'admin_release_all'
         WHERE lead_id = ? AND user_id = ? AND release_time IS NULL"
    );

    foreach ($lockedClaims as $lead) {
        $releaseLog->execute([(int)$lead['id'], (int)$lead['claimed_by']]);
    }

    $stmt = $pdo->prepare(
        "UPDATE leads
         SET is_locked = 0, is_claimed = 0, claimed_by = NULL, claim_time = NULL, claim_expiry = NULL, updated_at = CURRENT_TIMESTAMP
         WHERE is_locked = 1"
    );
    $stmt->execute();
    $releasedCount = $stmt->rowCount();

    $pdo->commit();
    admin_success([
        'message' => 'All locked leads released',
        'released_count' => $releasedCount,
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log('Admin release all leads failed: ' . $e->getMessage());
    admin_error('Unable to release locked leads. Please try again.', 500);
}

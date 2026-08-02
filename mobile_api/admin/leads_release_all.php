<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);

$pdo = admin_get_pdo();
$stmt = $pdo->prepare(
    "UPDATE leads
     SET is_locked = 0, is_claimed = 0, claimed_by = NULL, claim_time = NULL, claim_expiry = NULL, updated_at = CURRENT_TIMESTAMP
     WHERE is_locked = 1"
);
$stmt->execute();

admin_success([
    'message' => 'All locked leads released',
    'released_count' => $stmt->rowCount(),
]);

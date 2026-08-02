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
$stmt = $pdo->prepare(
    'UPDATE leads
     SET is_locked = 0, is_claimed = 0, claimed_by = NULL, claim_time = NULL, claim_expiry = NULL, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?'
);
$stmt->execute([$leadId]);

admin_success(['message' => 'Lead unlocked successfully']);

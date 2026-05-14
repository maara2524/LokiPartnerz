<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
$adminUser = admin_require_user(['admin', 'lead_manager']);

$input = admin_get_input();
$leadId = (int)($input['id'] ?? 0);
$status = trim((string)($input['status'] ?? ''));
$location = trim((string)($input['location'] ?? ''));
$budget = trim((string)($input['budget'] ?? ''));
$maxClaims = (int)($input['max_claims'] ?? 0);

if ($leadId <= 0 || $status === '' || $maxClaims < 0) {
    admin_error('Invalid lead update request');
}

if (!in_array($status, ['new', 'contacted', 'claimed', 'follow_up', 'booked', 'booked_outside_bbm', 'closed'], true)) {
    admin_error('Invalid lead status');
}

$dbStatus = match ($status) {
    'claimed' => 'new',
    'booked_outside_bbm' => 'closed',
    default => $status,
};

$pdo = admin_get_pdo();
$leadStmt = $pdo->prepare(
    'SELECT id, status, claimed_by, is_claimed
     FROM leads
     WHERE id = ?
     LIMIT 1'
);
$leadStmt->execute([$leadId]);
$existingLead = $leadStmt->fetch();

if (!$existingLead) {
    admin_error('Lead not found', 404);
}

$existingClaimedBy = (int)($existingLead['claimed_by'] ?? 0);
$existingIsClaimed = (int)($existingLead['is_claimed'] ?? 0);
$oldStatus = admin_effective_lead_status(
    $existingLead['status'] ?? 'new',
    $existingClaimedBy,
    $existingIsClaimed
);

$bookingStmt = $pdo->prepare(
    "SELECT new_status
     FROM lead_status_history
     WHERE lead_id = ? AND new_status IN ('booked', 'booked_outside_bbm')
     ORDER BY id DESC
     LIMIT 1"
);
$bookingStmt->execute([$leadId]);
$latestBookingStatus = trim((string)($bookingStmt->fetchColumn() ?: ''));

if ($latestBookingStatus === 'booked' || $latestBookingStatus === 'booked_outside_bbm') {
    $oldStatus = $latestBookingStatus;
}

$dbIsClaimed = ($status === 'claimed' || $existingClaimedBy > 0 || $existingIsClaimed === 1) ? 1 : 0;

if ($status === 'new' && $existingClaimedBy <= 0) {
    $dbIsClaimed = 0;
}

$stmt = $pdo->prepare(
    'UPDATE leads
     SET status = ?, location = ?, budget_range = ?, max_claims_allowed = ?, is_claimed = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?'
);
$stmt->execute([$dbStatus, $location, $budget, $maxClaims, $dbIsClaimed, $leadId]);

if ($oldStatus !== $status) {
    $historyStmt = $pdo->prepare(
        'INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, notes, changed_at)
         VALUES (?, ?, ?, ?, ?, NOW())'
    );
    $historyStmt->execute([
        $leadId,
        $oldStatus,
        $status,
        (int)$adminUser['id'],
        'Updated from admin panel',
    ]);
}

admin_success(['message' => 'Lead updated successfully']);

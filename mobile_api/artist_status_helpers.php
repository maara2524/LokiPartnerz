<?php

function normalize_artist_status($status) {
    $status = strtolower(trim((string)$status));
    $status = str_replace(['-', ' '], '_', $status);
    $status = preg_replace('/_+/', '_', $status);

    $legacyMap = [
        'booked_outside' => 'booked_outside_bbm',
        'outside_booked' => 'booked_outside_bbm',
        'booked_outside_bbm' => 'booked_outside_bbm',
        'booked_outside_of_bbm' => 'booked_outside_bbm',
    ];

    return $legacyMap[$status] ?? $status;
}

function artist_status_label($status) {
    switch (normalize_artist_status($status)) {
        case 'booked':
            return 'Booked';
        case 'booked_inside_bbm':
            return 'Booked inside BBM';
        case 'booked_outside_bbm':
            return 'Booked outside BBM';
        case 'contacted':
            return 'Contacted';
        case 'closed':
            return 'Closed';
        case 'follow_up':
            return 'Follow Up';
        case 'new':
        default:
            return 'New';
    }
}

function get_latest_artist_status(PDO $pdo, int $leadId, int $userId) {
    $stmt = $pdo->prepare("
        SELECT new_status
        FROM lead_status_history
        WHERE lead_id = ?
          AND changed_by = ?
        ORDER BY id DESC
        LIMIT 1
    ");
    $stmt->execute([$leadId, $userId]);
    $status = $stmt->fetchColumn();

    return $status ? normalize_artist_status($status) : null;
}

function get_latest_claim_booking_outcome(PDO $pdo, int $leadId) {
    $stmt = $pdo->prepare("
        SELECT lsh.changed_by, lsh.new_status
        FROM lead_status_history lsh
        INNER JOIN (
            SELECT changed_by, MAX(id) AS latest_id
            FROM lead_status_history
            WHERE lead_id = ?
            GROUP BY changed_by
        ) latest
            ON latest.latest_id = lsh.id
        WHERE lsh.lead_id = ?
          AND lsh.new_status IN ('booked', 'booked_outside_bbm')
        ORDER BY lsh.id DESC
        LIMIT 1
    ");
    $stmt->execute([$leadId, $leadId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        return null;
    }

    return [
        'changed_by' => (int)$row['changed_by'],
        'status' => normalize_artist_status($row['new_status']),
    ];
}

function get_artist_display_status(PDO $pdo, int $leadId, int $viewerUserId, ?string $ownStatus = null) {
    $ownStatus = normalize_artist_status($ownStatus ?? get_latest_artist_status($pdo, $leadId, $viewerUserId) ?? 'new');

    if ($ownStatus === 'booked' || $ownStatus === 'booked_outside_bbm') {
        return $ownStatus;
    }

    $bookingOutcome = get_latest_claim_booking_outcome($pdo, $leadId);

    if (!$bookingOutcome) {
        return $ownStatus;
    }

    if ($bookingOutcome['status'] === 'booked_outside_bbm') {
        return 'booked_outside_bbm';
    }

    if ($bookingOutcome['status'] === 'booked' && $bookingOutcome['changed_by'] !== $viewerUserId) {
        return 'booked_inside_bbm';
    }

    return $ownStatus;
}


<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['GET']);
admin_require_user(['admin', 'lead_manager']);

$pdo = admin_get_pdo();

$sql = "
    SELECT
        l.id,
        l.customer_name,
        l.whatsapp_number,
        l.event_type,
        l.event_date,
        l.location,
        l.services_required,
        l.budget_range,
        l.status,
        l.claim_count,
        l.max_claims_allowed,
        l.is_locked,
        l.is_claimed,
        l.lead_source,
        l.claimed_by,
        COALESCE(ap.contact_person_name, ap.business_name, claimed_user.username, '-') AS claimed_by_name,
        booking.new_status AS booked_status,
        booking.changed_at AS booked_at,
        COALESCE(booking_ap.contact_person_name, booking_ap.business_name, booking_user.username, '') AS booked_by_name
    FROM leads l
    LEFT JOIN users claimed_user ON claimed_user.id = l.claimed_by
    LEFT JOIN artist_profiles ap ON ap.user_id = claimed_user.id
    LEFT JOIN (
        SELECT lsh.lead_id, lsh.changed_by, lsh.new_status, lsh.changed_at
        FROM lead_status_history lsh
        INNER JOIN (
            SELECT lead_id, MAX(id) AS latest_id
            FROM lead_status_history
            WHERE new_status IN ('booked', 'booked_outside_bbm')
            GROUP BY lead_id
        ) latest_booking ON latest_booking.latest_id = lsh.id
    ) booking ON booking.lead_id = l.id
    LEFT JOIN users booking_user ON booking_user.id = booking.changed_by
    LEFT JOIN artist_profiles booking_ap ON booking_ap.user_id = booking_user.id
    ORDER BY l.created_at DESC, l.id DESC
";

$rows = $pdo->query($sql)->fetchAll();

$leads = array_map(
    static function (array $row): array {
        $services = json_decode((string)($row['services_required'] ?? ''), true);
        $serviceLabel = is_array($services) && !empty($services) ? implode(', ', $services) : ((string)($row['services_required'] ?? ''));
        $status = admin_effective_lead_status(
            $row['status'] ?? 'new',
            isset($row['claimed_by']) ? (int)$row['claimed_by'] : null,
            isset($row['is_claimed']) ? (int)$row['is_claimed'] : null
        );
        $bookedStatus = trim((string)($row['booked_status'] ?? ''));

        if ($bookedStatus === 'booked' || $bookedStatus === 'booked_outside_bbm') {
            $status = $bookedStatus;
        }

        return [
            'id' => (int)$row['id'],
            'customer' => (string)($row['customer_name'] ?? ''),
            'phone' => (string)($row['whatsapp_number'] ?? ''),
            'event' => (string)($row['event_type'] ?? ''),
            'date' => admin_format_datetime($row['event_date']) ?? '',
            'location' => (string)($row['location'] ?? ''),
            'services' => $serviceLabel,
            'budget' => (string)($row['budget_range'] ?? ''),
            'status' => $status,
            'claimed_by' => (string)($row['claimed_by_name'] ?? '-'),
            'claimed_by_id' => isset($row['claimed_by']) ? (int)$row['claimed_by'] : null,
            'booked_by' => (string)($row['booked_by_name'] ?? ''),
            'booked_status' => $bookedStatus,
            'booked_at' => admin_format_ist_datetime($row['booked_at'] ?? null) ?? '',
            'claim_count' => (int)($row['claim_count'] ?? 0),
            'max_claims' => (int)($row['max_claims_allowed'] ?? 0),
            'source' => ucfirst((string)($row['lead_source'] ?? '')),
            'locked' => ((int)($row['is_locked'] ?? 0)) === 1,
        ];
    },
    $rows
);

admin_success(['leads' => $leads]);

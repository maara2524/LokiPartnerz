<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['GET']);
admin_require_user(['admin', 'lead_manager']);

$leadId = (int)($_GET['id'] ?? $_GET['lead_id'] ?? 0);

if ($leadId <= 0) {
    admin_error('Invalid lead id');
}

$pdo = admin_get_pdo();

function admin_lead_json_label(?string $value): string
{
    $raw = trim((string)$value);
    if ($raw === '') {
        return '';
    }

    $decoded = json_decode($raw, true);
    if (is_array($decoded)) {
        $labels = array_values(array_filter(array_map(static fn($item): string => trim((string)$item), $decoded)));
        return $labels ? implode(', ', $labels) : '';
    }

    return $raw;
}

function admin_lead_status_label(?string $status): string
{
    $value = trim((string)$status);

    return match ($value) {
        'booked_outside_bbm' => 'Booked outside app',
        'booked_inside_bbm' => 'Booked inside app',
        'follow_up' => 'Follow up',
        '' => 'Unknown',
        default => ucwords(str_replace('_', ' ', $value)),
    };
}

function admin_add_timeline_item(array &$timeline, string $type, string $title, ?string $actor, ?string $rawTime, ?string $description = null, ?string $status = null): void
{
    $timeline[] = [
        'type' => $type,
        'title' => $title,
        'actor' => $actor ?: 'Unknown',
        'time' => admin_format_ist_datetime($rawTime) ?? '',
        'description' => $description ?? '',
        'status' => $status ?? '',
        'sort_at' => $rawTime ?: '',
    ];
}

$leadStmt = $pdo->prepare(
    "SELECT
        l.id,
        l.customer_name,
        l.whatsapp_number,
        l.email,
        l.event_type,
        l.event_date,
        l.location,
        l.services_required,
        l.budget_range,
        l.additional_info,
        l.status,
        l.claim_count,
        l.max_claims_allowed,
        l.is_locked,
        l.is_claimed,
        l.lead_source,
        l.claimed_by,
        l.claim_time,
        l.claim_expiry,
        l.created_at,
        l.updated_at,
        COALESCE(ap.contact_person_name, ap.business_name, claimed_user.username, '-') AS claimed_by_name,
        booking.new_status AS booked_status,
        booking.changed_at AS booked_at,
        booking.changed_by AS booked_by_id,
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
     WHERE l.id = ?
     LIMIT 1"
);
$leadStmt->execute([$leadId]);
$lead = $leadStmt->fetch();

if (!$lead) {
    admin_error('Lead not found', 404);
}

$status = admin_effective_lead_status(
    $lead['status'] ?? 'new',
    isset($lead['claimed_by']) ? (int)$lead['claimed_by'] : null,
    isset($lead['is_claimed']) ? (int)$lead['is_claimed'] : null
);
$bookedStatus = trim((string)($lead['booked_status'] ?? ''));

if ($bookedStatus === 'booked' || $bookedStatus === 'booked_outside_bbm') {
    $status = $bookedStatus;
}

$leadPayload = [
    'id' => (int)$lead['id'],
    'customer' => (string)($lead['customer_name'] ?? ''),
    'phone' => (string)($lead['whatsapp_number'] ?? ''),
    'email' => (string)($lead['email'] ?? ''),
    'event' => admin_lead_json_label($lead['event_type'] ?? ''),
    'date' => admin_format_datetime($lead['event_date'] ?? null) ?? '',
    'location' => (string)($lead['location'] ?? ''),
    'services' => admin_lead_json_label($lead['services_required'] ?? ''),
    'budget' => (string)($lead['budget_range'] ?? ''),
    'requirements' => (string)($lead['additional_info'] ?? ''),
    'status' => $status,
    'status_label' => admin_lead_status_label($status),
    'claimed_by' => (string)($lead['claimed_by_name'] ?? '-'),
    'claimed_by_id' => isset($lead['claimed_by']) ? (int)$lead['claimed_by'] : null,
    'booked_by' => (string)($lead['booked_by_name'] ?? ''),
    'booked_by_id' => isset($lead['booked_by_id']) ? (int)$lead['booked_by_id'] : null,
    'booked_status' => $bookedStatus,
    'booked_at' => admin_format_ist_datetime($lead['booked_at'] ?? null) ?? '',
    'claim_count' => (int)($lead['claim_count'] ?? 0),
    'max_claims' => (int)($lead['max_claims_allowed'] ?? 0),
    'source' => ucfirst((string)($lead['lead_source'] ?? '')),
    'locked' => ((int)($lead['is_locked'] ?? 0)) === 1,
    'claim_time' => admin_format_ist_datetime($lead['claim_time'] ?? null) ?? '',
    'claim_expiry' => admin_format_ist_datetime($lead['claim_expiry'] ?? null) ?? '',
    'created_at' => admin_format_ist_datetime($lead['created_at'] ?? null) ?? '',
    'updated_at' => admin_format_ist_datetime($lead['updated_at'] ?? null) ?? '',
];

$timeline = [];
admin_add_timeline_item(
    $timeline,
    'lead_created',
    'Lead created',
    'System',
    $lead['created_at'] ?? null,
    trim((string)($lead['lead_source'] ?? '')) !== '' ? 'Source: ' . ucfirst((string)$lead['lead_source']) : ''
);

$claimStmt = $pdo->prepare(
    "SELECT
        cll.id,
        cll.user_id,
        cll.claim_time,
        cll.release_time,
        cll.final_status,
        cll.release_reason,
        cll.notes,
        cll.created_at,
        u.role,
        COALESCE(ap.contact_person_name, ap.business_name, u.username, CONCAT('User #', cll.user_id)) AS user_name,
        ap.business_name,
        ap.whatsapp_number,
        ap.location
     FROM claimed_leads_log cll
     LEFT JOIN users u ON u.id = cll.user_id
     LEFT JOIN artist_profiles ap ON ap.user_id = cll.user_id
     WHERE cll.lead_id = ?
     ORDER BY COALESCE(cll.claim_time, cll.created_at) DESC, cll.id DESC"
);
$claimStmt->execute([$leadId]);
$claimRows = $claimStmt->fetchAll();

$claimHistory = array_map(
    static function (array $row) use (&$timeline): array {
        $userName = (string)($row['user_name'] ?? 'Unknown');
        $claimTimeRaw = $row['claim_time'] ?? $row['created_at'] ?? null;
        $releaseTimeRaw = $row['release_time'] ?? null;

        admin_add_timeline_item(
            $timeline,
            'claim',
            'Lead claimed',
            $userName,
            $claimTimeRaw,
            trim((string)($row['business_name'] ?? '')) !== '' ? (string)$row['business_name'] : null,
            'claimed'
        );

        if (!empty($releaseTimeRaw)) {
            $releaseReason = trim((string)($row['release_reason'] ?? ''));
            $finalStatus = trim((string)($row['final_status'] ?? ''));
            $descriptionParts = [];
            if ($releaseReason !== '') {
                $descriptionParts[] = 'Reason: ' . admin_lead_status_label($releaseReason);
            }
            if ($finalStatus !== '') {
                $descriptionParts[] = 'Final status: ' . admin_lead_status_label($finalStatus);
            }
            if (trim((string)($row['notes'] ?? '')) !== '') {
                $descriptionParts[] = (string)$row['notes'];
            }

            admin_add_timeline_item(
                $timeline,
                'release',
                'Claim released',
                $userName,
                $releaseTimeRaw,
                implode(' - ', $descriptionParts),
                $finalStatus
            );
        }

        return [
            'id' => (int)$row['id'],
            'user_id' => (int)$row['user_id'],
            'user_name' => $userName,
            'role' => (string)($row['role'] ?? 'artist'),
            'business_name' => (string)($row['business_name'] ?? ''),
            'phone' => (string)($row['whatsapp_number'] ?? ''),
            'location' => (string)($row['location'] ?? ''),
            'claim_time' => admin_format_ist_datetime($claimTimeRaw) ?? '',
            'release_time' => admin_format_ist_datetime($releaseTimeRaw) ?? '',
            'final_status' => (string)($row['final_status'] ?? ''),
            'release_reason' => (string)($row['release_reason'] ?? ''),
            'notes' => (string)($row['notes'] ?? ''),
        ];
    },
    $claimRows
);

$statusStmt = $pdo->prepare(
    "SELECT
        lsh.id,
        lsh.old_status,
        lsh.new_status,
        lsh.changed_by,
        lsh.notes,
        lsh.changed_at,
        u.role,
        COALESCE(ap.contact_person_name, ap.business_name, team_by_user.display_name, team_by_id.display_name, u.username, CONCAT('User #', lsh.changed_by)) AS changed_by_name
     FROM lead_status_history lsh
     LEFT JOIN users u ON u.id = lsh.changed_by
     LEFT JOIN artist_profiles ap ON ap.user_id = u.id
     LEFT JOIN teams team_by_user ON team_by_user.user_id = u.id
     LEFT JOIN teams team_by_id ON team_by_id.team_id = lsh.changed_by
     WHERE lsh.lead_id = ?
     ORDER BY lsh.changed_at DESC, lsh.id DESC"
);
$statusStmt->execute([$leadId]);
$statusRows = $statusStmt->fetchAll();

$statusHistory = array_map(
    static function (array $row) use (&$timeline): array {
        $actor = (string)($row['changed_by_name'] ?? 'Unknown');
        $oldStatus = (string)($row['old_status'] ?? '');
        $newStatus = (string)($row['new_status'] ?? '');
        $description = $oldStatus !== ''
            ? 'Changed from ' . admin_lead_status_label($oldStatus) . ' to ' . admin_lead_status_label($newStatus)
            : 'Set to ' . admin_lead_status_label($newStatus);

        if (trim((string)($row['notes'] ?? '')) !== '') {
            $description .= ' - ' . (string)$row['notes'];
        }

        admin_add_timeline_item(
            $timeline,
            'status',
            'Status changed',
            $actor,
            $row['changed_at'] ?? null,
            $description,
            $newStatus
        );

        return [
            'id' => (int)$row['id'],
            'old_status' => $oldStatus,
            'new_status' => $newStatus,
            'old_status_label' => admin_lead_status_label($oldStatus),
            'new_status_label' => admin_lead_status_label($newStatus),
            'changed_by' => (int)$row['changed_by'],
            'changed_by_name' => $actor,
            'changed_by_role' => (string)($row['role'] ?? ''),
            'notes' => (string)($row['notes'] ?? ''),
            'changed_at' => admin_format_ist_datetime($row['changed_at'] ?? null) ?? '',
        ];
    },
    $statusRows
);

$activityStmt = $pdo->prepare(
    "SELECT
        la.activity_id,
        la.activity_type,
        la.performed_by,
        la.related_artist_id,
        la.contact_type,
        sm.status_name,
        la.activity_notes,
        la.duration_minutes,
        la.success,
        la.follow_up_date,
        la.created_at,
        performer.role AS performer_role,
        COALESCE(team_by_user.display_name, performer_ap.contact_person_name, performer_ap.business_name, performer.username, team_by_id.display_name, CONCAT('User #', la.performed_by)) AS performed_by_name,
        COALESCE(ec.name, related_ap.contact_person_name, related_ap.business_name, related_user.username, '') AS related_artist_name
     FROM team_lead_tracking tlt
     INNER JOIN lead_activity la ON la.tracking_id = tlt.tracking_id
     LEFT JOIN status_master sm ON sm.status_id = la.status_id
     LEFT JOIN users performer ON performer.id = la.performed_by
     LEFT JOIN artist_profiles performer_ap ON performer_ap.user_id = performer.id
     LEFT JOIN teams team_by_user ON team_by_user.user_id = performer.id
     LEFT JOIN teams team_by_id ON team_by_id.team_id = la.performed_by
     LEFT JOIN elite_clients ec ON ec.id = la.related_artist_id
     LEFT JOIN users related_user ON related_user.id = la.related_artist_id
     LEFT JOIN artist_profiles related_ap ON related_ap.user_id = related_user.id
     WHERE tlt.lead_id = ?
     ORDER BY la.created_at DESC, la.activity_id DESC"
);
$activityStmt->execute([$leadId]);
$activityRows = $activityStmt->fetchAll();

$activityHistory = array_map(
    static function (array $row) use (&$timeline): array {
        $actor = (string)($row['performed_by_name'] ?? 'Unknown');
        $activityType = (string)($row['activity_type'] ?? 'activity');
        $statusName = (string)($row['status_name'] ?? '');
        $notes = (string)($row['activity_notes'] ?? '');
        $relatedArtist = (string)($row['related_artist_name'] ?? '');
        $descriptionParts = [];

        if ($statusName !== '') {
            $descriptionParts[] = 'Status: ' . admin_lead_status_label($statusName);
        }
        if ($relatedArtist !== '') {
            $descriptionParts[] = 'Artist: ' . $relatedArtist;
        }
        if ($notes !== '') {
            $descriptionParts[] = $notes;
        }

        admin_add_timeline_item(
            $timeline,
            'activity',
            admin_lead_status_label($activityType),
            $actor,
            $row['created_at'] ?? null,
            implode(' - ', $descriptionParts),
            $statusName
        );

        return [
            'id' => (int)$row['activity_id'],
            'activity_type' => $activityType,
            'performed_by' => isset($row['performed_by']) ? (int)$row['performed_by'] : null,
            'performed_by_name' => $actor,
            'performed_by_role' => (string)($row['performer_role'] ?? ''),
            'related_artist_id' => isset($row['related_artist_id']) ? (int)$row['related_artist_id'] : null,
            'related_artist_name' => $relatedArtist,
            'contact_type' => (string)($row['contact_type'] ?? ''),
            'status' => $statusName,
            'status_label' => admin_lead_status_label($statusName),
            'notes' => $notes,
            'duration_minutes' => isset($row['duration_minutes']) ? (int)$row['duration_minutes'] : null,
            'success' => isset($row['success']) ? (int)$row['success'] : null,
            'follow_up_date' => admin_format_ist_datetime($row['follow_up_date'] ?? null) ?? '',
            'created_at' => admin_format_ist_datetime($row['created_at'] ?? null) ?? '',
        ];
    },
    $activityRows
);

$notesStmt = $pdo->prepare(
    "SELECT
        ln.id,
        ln.user_id,
        ln.note,
        ln.status,
        ln.created_at,
        u.role,
        COALESCE(ap.contact_person_name, ap.business_name, u.username, CONCAT('User #', ln.user_id)) AS user_name
     FROM lead_notes ln
     LEFT JOIN users u ON u.id = ln.user_id
     LEFT JOIN artist_profiles ap ON ap.user_id = ln.user_id
     WHERE ln.lead_id = ?
     ORDER BY ln.created_at DESC, ln.id DESC"
);
$notesStmt->execute([$leadId]);
$noteRows = $notesStmt->fetchAll();

$notes = array_map(
    static function (array $row) use (&$timeline): array {
        $actor = (string)($row['user_name'] ?? 'Unknown');
        $status = (string)($row['status'] ?? '');
        $note = (string)($row['note'] ?? '');

        admin_add_timeline_item(
            $timeline,
            'note',
            'Note added',
            $actor,
            $row['created_at'] ?? null,
            $note,
            $status
        );

        return [
            'id' => (int)$row['id'],
            'user_id' => (int)$row['user_id'],
            'user_name' => $actor,
            'role' => (string)($row['role'] ?? ''),
            'note' => $note,
            'status' => $status,
            'status_label' => admin_lead_status_label($status),
            'created_at' => admin_format_ist_datetime($row['created_at'] ?? null) ?? '',
        ];
    },
    $noteRows
);

usort(
    $timeline,
    static fn(array $a, array $b): int => strcmp((string)($b['sort_at'] ?? ''), (string)($a['sort_at'] ?? ''))
);

$timeline = array_map(
    static function (array $item): array {
        unset($item['sort_at']);
        return $item;
    },
    $timeline
);

admin_success([
    'lead' => $leadPayload,
    'claim_history' => $claimHistory,
    'status_history' => $statusHistory,
    'activity_history' => $activityHistory,
    'notes' => $notes,
    'timeline' => $timeline,
]);

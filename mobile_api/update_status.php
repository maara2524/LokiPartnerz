<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/artist_status_helpers.php';

function normalize_telecaller_status($status) {
    $status = strtolower(trim((string)$status));

    $legacyMap = [
        'call_later' => 'callback_needed',
        'not_interested' => 'not interested',
        'booked_outside' => 'Booked Outside',
        'booked_outside_bbm' => 'Booked Outside',
    ];

    return $legacyMap[$status] ?? $status;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

try {

    $config_file = __DIR__ . '/../app/config/database.php';

    if (!file_exists($config_file)) {
        throw new Exception('Database config not found');
    }

    include $config_file;

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->exec("SET time_zone = '+05:30'");

    $stmt = $pdo->prepare("
        SELECT setting_value
        FROM system_settings
        WHERE setting_key = 'auto_release_inactive_hours'
        LIMIT 1
    ");
    $stmt->execute();

    $autoReleaseInactiveHours = (int)($stmt->fetchColumn() ?: 48);

} catch (Exception $e) {

    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed']);
    exit();
}

$input = json_decode(file_get_contents('php://input'), true);

if (!$input) {
    $input = $_POST;
}

$token      = $input['token'] ?? '';
$lead_id    = isset($input['lead_id']) ? intval($input['lead_id']) : 0;
$new_status = strtolower(trim($input['status'] ?? ''));
$notes      = trim($input['notes'] ?? ($input['note'] ?? ''));

if (empty($token) || empty($lead_id) || empty($new_status)) {

    http_response_code(400);
    echo json_encode(['error' => 'Missing required fields']);
    exit();
}

try {

    // Validate user and get role
    $stmt = $pdo->prepare("
        SELECT id, role
        FROM users
        WHERE api_token = ?
        AND token_expires > NOW()
    ");

    $stmt->execute([$token]);

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {

        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    $user_id = (int)$user['id'];
    $role    = $user['role'];

    if ($role === 'telecaller') {
        $new_status = normalize_telecaller_status($new_status);
    } else {
        $new_status = normalize_artist_status($new_status);
    }

    // TELECALLER WORKFLOW

    if ($role === 'telecaller') {

        $pdo->beginTransaction();

        $stmt = $pdo->prepare("SELECT id FROM leads WHERE id = ? LIMIT 1");
        $stmt->execute([$lead_id]);

        if (!$stmt->fetch()) {
            $pdo->rollBack();
            http_response_code(404);
            echo json_encode(['error' => 'Lead not found']);
            exit();
        }

        // get status id
        $stmt = $pdo->prepare("
            SELECT status_id
            FROM status_master
            WHERE status_name = ?
            LIMIT 1
        ");
        $stmt->execute([$new_status]);
        $status_id = $stmt->fetchColumn();

        if (!$status_id) {

            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['error' => 'Invalid status']);
            exit();
        }

        $stmt = $pdo->prepare("
            SELECT services_required
            FROM leads
            WHERE id = ?
            LIMIT 1
        ");
        $stmt->execute([$lead_id]);

        $service_type = $stmt->fetchColumn() ?: '';

        // get tracking id
        $stmt = $pdo->prepare("
            SELECT tracking_id
            FROM team_lead_tracking
            WHERE lead_id = ?
            LIMIT 1
        ");
        $stmt->execute([$lead_id]);
        $tracking_id = $stmt->fetchColumn();

        if (!$tracking_id) {

            $stmt = $pdo->prepare("
                INSERT INTO team_lead_tracking
                (
                    lead_id,
                    service_type,
                    team_member_id,
                    created_by,
                    current_status_id,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, NOW())
            ");

            $stmt->execute([
                $lead_id,
                $service_type,
                $user_id,
                $user_id,
                $status_id
            ]);

            $tracking_id = $pdo->lastInsertId();

        } else {

            $stmt = $pdo->prepare("
                UPDATE team_lead_tracking
                SET current_status_id = ?,
                    team_member_id = ?,
                    last_updated_by = ?,
                    updated_at = NOW()
                WHERE tracking_id = ?
            ");

            $stmt->execute([
                $status_id,
                $user_id,
                $user_id,
                $tracking_id
            ]);
        }

        // insert activity
        $stmt = $pdo->prepare("
            INSERT INTO lead_activity
            (tracking_id, activity_type, performed_by, status_id, activity_notes, created_at)
            VALUES (?, 'telecaller_status', ?, ?, ?, NOW())
        ");

        $stmt->execute([
            $tracking_id,
            $user_id,
            $status_id,
            $notes
        ]);

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => 'Telecaller status updated',
            'lead_id' => $lead_id,
            'status' => $new_status
        ]);

        exit();
    }

    // ARTIST WORKFLOW 

    $valid_statuses = ['new', 'contacted', 'booked', 'booked_outside_bbm', 'closed'];

    if (!in_array($new_status, $valid_statuses)) {

        http_response_code(400);
        echo json_encode(['error' => 'Invalid status']);
        exit();
    }

    $stmt = $pdo->prepare("SELECT * FROM leads WHERE id = ?");
    $stmt->execute([$lead_id]);

    $lead = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$lead) {

        http_response_code(404);
        echo json_encode(['error' => 'Lead not found']);
        exit();
    }

    $isOwner = false;

    if ($lead['claimed_by'] == $user_id) {
        $isOwner = true;
    } else {

        $stmt = $pdo->prepare("
            SELECT COUNT(*)
            FROM claimed_leads_log
            WHERE lead_id = ?
            AND user_id = ?
        ");

        $stmt->execute([$lead_id, $user_id]);

        if ($stmt->fetchColumn() > 0) {
            $isOwner = true;
        }
    }

    if (!$isOwner) {

        http_response_code(403);
        echo json_encode([
            'error' => 'You are not authorized to update this lead (not current or previous owner)'
        ]);

        exit();
    }

    $old_status = get_latest_artist_status($pdo, $lead_id, $user_id) ?? 'new';

    $globalStatus = null;
    $claim_expiry = $lead['claim_expiry'];

    if ($new_status === 'booked') {
        $globalStatus = 'booked';
        $claim_expiry = null;
    } elseif ($new_status === 'booked_outside_bbm' || $new_status === 'closed') {
        $globalStatus = 'closed';
        $claim_expiry = null;
    } elseif ((int)$lead['claimed_by'] === $user_id) {
        $globalStatus = $new_status;
    }

    if ($globalStatus !== null) {
        $stmt = $pdo->prepare("
            UPDATE leads
            SET status = ?, claim_expiry = ?
            WHERE id = ?
        ");

        $stmt->execute([
            $globalStatus,
            $claim_expiry,
            $lead_id
        ]);
    }

    $stmt = $pdo->prepare("
        INSERT INTO lead_status_history
        (lead_id, old_status, new_status, changed_by, notes, changed_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ");

    $stmt->execute([
        $lead_id,
        $old_status,
        $new_status,
        $user_id,
        $notes
    ]);

    $displayStatus = get_artist_display_status($pdo, $lead_id, $user_id, $new_status);
    $lock_permanent = in_array($new_status, ['booked', 'booked_outside_bbm', 'closed'], true);

    echo json_encode([
        'success' => true,
        'message' => "Lead Status updated from " . artist_status_label($old_status) . " to " . artist_status_label($new_status),
        'lead_id' => $lead_id,
        'old_status' => $old_status,
        'new_status' => $new_status,
        'my_status' => $new_status,
        'display_status' => $displayStatus,
        'display_status_label' => artist_status_label($displayStatus),
        'permanent_lock' => $lock_permanent
    ]);

} catch (Exception $e) {

    http_response_code(500);

    error_log('BBM update_status failure: ' . $e->getMessage());
    echo json_encode([
        'error' => 'Unable to update status. Please try again.'
    ]);
}
?>

<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

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
    echo json_encode([
        "success" => false,
        "error" => "Method not allowed"
    ]);
    exit;
}

$config_file = __DIR__ . '/../app/config/database.php';

if (!file_exists($config_file)) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => "Database config not found"
    ]);
    exit;
}

include $config_file;

try {

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->exec("SET time_zone = '+05:30'");

} catch (Exception $e) {

    echo json_encode([
        "success" => false,
        "error" => "DB connection failed"
    ]);

    exit;
}

$input = json_decode(file_get_contents("php://input"), true);
if (!$input) {
    $input = $_POST;
}

$token   = $input["token"] ?? "";
$lead_id = isset($input["lead_id"]) ? (int)$input["lead_id"] : 0;
$note    = trim($input["note"] ?? "");
$status  = strtolower(trim($input["status"] ?? ""));

if (!$token || !$lead_id || (!$note && !$status)) {
    http_response_code(400);

    echo json_encode([
        "success" => false,
        "error" => "Note or status required"
    ]);

    exit;
}

$stmt = $pdo->prepare("
    SELECT id, role
    FROM users
    WHERE api_token = ?
    AND token_expires > NOW()
    LIMIT 1
");

$stmt->execute([$token]);

$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    http_response_code(401);

    echo json_encode([
        "success" => false,
        "error" => "Invalid token"
    ]);

    exit;
}

$user_id = (int)$user["id"];
$role    = $user["role"] ?? "";

if ($role === "telecaller") {
    $status = normalize_telecaller_status($status);
}

try {

    $pdo->beginTransaction();

    $stmt = $pdo->prepare("
        SELECT id, services_required
        FROM leads
        WHERE id = ?
        LIMIT 1
    ");
    $stmt->execute([$lead_id]);
    $lead = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$lead) {
        throw new Exception("Lead not found");
    }

    // TELECALLER WORKFLOW

    if ($role === "telecaller") {

    // get tracking id
    $stmt = $pdo->prepare("
        SELECT tracking_id, current_status_id
        FROM team_lead_tracking
        WHERE lead_id = ?
        LIMIT 1
    ");

    $stmt->execute([$lead_id]);
    $tracking = $stmt->fetch(PDO::FETCH_ASSOC);
    $tracking_id = $tracking['tracking_id'] ?? null;

    // get service type
    $service_type = $lead['services_required'] ?? '';

    // get status id
    $status_id = null;

    if ($status) {

        $stmt = $pdo->prepare("
            SELECT status_id
            FROM status_master
            WHERE status_name = ?
            LIMIT 1
        ");

        $stmt->execute([$status]);
        $status_id = $stmt->fetchColumn();

        if (!$status_id) {
            throw new Exception("Invalid follow-up status");
        }
    } elseif ($tracking_id) {
        $status_id = (int)($tracking['current_status_id'] ?? 0);

        if ($status_id <= 0) {
            $stmt = $pdo->prepare("
                SELECT status_id
                FROM status_master
                WHERE status_name = 'new'
                LIMIT 1
            ");
            $stmt->execute();
            $status_id = (int)$stmt->fetchColumn();
        }
    } else {
        $stmt = $pdo->prepare("
            SELECT status_id
            FROM status_master
            WHERE status_name = 'new'
            LIMIT 1
        ");
        $stmt->execute();
        $status_id = (int)$stmt->fetchColumn();

        if ($status_id <= 0) {
            throw new Exception("Default status not found");
        }
    }

    // create tracking record if not exists
    if (!$tracking_id) {

        $stmt = $pdo->prepare("
            INSERT INTO team_lead_tracking
            (lead_id, created_by, team_member_id, service_type, current_status_id)
            VALUES (?, ?, ?, ?, ?)
        ");

        $stmt->execute([
            $lead_id,
            $user_id,
            $user_id,
            $service_type,
            $status_id
        ]);

        $tracking_id = $pdo->lastInsertId();

    } else {

            $stmt = $pdo->prepare("
                UPDATE team_lead_tracking
                SET last_updated_by = ?, updated_at = NOW(), team_member_id = ?
                WHERE tracking_id = ?
            ");
            $stmt->execute([$user_id, $user_id, $tracking_id]);

            // update status in tracking table only when user explicitly changed it
            if (!empty($status) && $status_id) {

                $stmt = $pdo->prepare("
                    UPDATE team_lead_tracking
                    SET current_status_id = ?
                    WHERE tracking_id = ?
                ");

                $stmt->execute([
                    $status_id,                   
                    $tracking_id
                ]);
            }
        }

        $activity_type = 'note';

        if (!empty($status)) {
            $activity_type = 'call';
        } elseif (!empty($note)) {
            $activity_type = 'note';
        }

        // insert activity 
        $stmt = $pdo->prepare("
            INSERT INTO lead_activity
            (tracking_id, activity_type, performed_by, status_id, activity_notes, created_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ");

        $stmt->execute([
            $tracking_id,
            $activity_type,
            $user_id,
            $status_id,
            $note
        ]);
    }

    // NORMAL ARTIST WORKFLOW

    else {

        $stmt = $pdo->prepare("
            INSERT INTO lead_notes
            (lead_id, user_id, note, status)
            VALUES (?, ?, ?, ?)
        ");

        $stmt->execute([
            $lead_id,
            $user_id,
            $note,
            $status
        ]);
    }

    $pdo->commit();

    echo json_encode([
        "success" => true,
        "message" => "Follow-up saved successfully"
    ]);

} catch (Exception $e) {

    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log('BBM add_new_note failure: ' . $e->getMessage());
    echo json_encode([
        "success" => false,
        "error" => "Could not save note. Please try again."
    ]);
}

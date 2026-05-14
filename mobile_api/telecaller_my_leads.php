<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

$token = $_GET['token'] ?? '';

if (empty($token)) {
    http_response_code(401);
    echo json_encode(['error' => 'Authentication token required']);
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
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    if (($user['role'] ?? '') !== 'telecaller') {
        http_response_code(403);
        echo json_encode(['error' => 'Only telecallers can access this endpoint']);
        exit();
    }

    $userId = (int)$user['id'];

    $stmt = $pdo->prepare("
        SELECT
            l.id,
            l.customer_name,
            l.event_date,
            l.location,
            l.event_type,
            l.budget_range,
            COALESCE(sm.status_name, 'new') AS status,
            COALESCE(MAX(la.created_at), MAX(tlt.updated_at), MAX(tlt.created_at)) AS last_interacted_at
        FROM team_lead_tracking tlt
        INNER JOIN leads l
            ON l.id = tlt.lead_id
        LEFT JOIN status_master sm
            ON sm.status_id = tlt.current_status_id
        LEFT JOIN lead_activity la
            ON la.tracking_id = tlt.tracking_id
           AND la.performed_by = :activity_user_id
        WHERE tlt.team_member_id = :team_member_id
           OR tlt.created_by = :created_by
           OR tlt.last_updated_by = :last_updated_by
           OR la.activity_id IS NOT NULL
        GROUP BY
            l.id,
            l.customer_name,
            l.event_date,
            l.location,
            l.event_type,
            l.budget_range,
            sm.status_name
        ORDER BY last_interacted_at DESC
    ");
    $stmt->execute([
        ':activity_user_id' => $userId,
        ':team_member_id' => $userId,
        ':created_by' => $userId,
        ':last_updated_by' => $userId,
    ]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $formattedLeads = [];

    foreach ($rows as $lead) {
        $eventTypeRaw = $lead['event_type'] ?? '';
        $eventTypeFormatted = $eventTypeRaw;

        if (!empty($eventTypeRaw)) {
            $decoded = json_decode($eventTypeRaw, true);

            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $decoded = array_filter(array_map('trim', $decoded), 'strlen');
                $eventTypeFormatted = implode(', ', $decoded);
            }
        }

        $formattedLeads[] = [
            'id' => (int)$lead['id'],
            'customer_name' => $lead['customer_name'] ?: 'Unknown',
            'event_date' => $lead['event_date'] ?: '',
            'location' => $lead['location'] ?: '',
            'event_type' => $eventTypeFormatted ?: '',
            'status' => $lead['status'] ?: 'new',
            'budget_range' => $lead['budget_range'] ?: 'Not Specified',
            'last_interacted_at' => $lead['last_interacted_at'] ?: null,
        ];
    }

    echo json_encode([
        'success' => true,
        'count' => count($formattedLeads),
        'leads' => $formattedLeads,
    ]);
} catch (Exception $e) {
    http_response_code(500);
    error_log('BBM telecaller_my_leads failure: ' . $e->getMessage());
    echo json_encode([
        'error' => 'Failed to fetch telecaller leads. Please try again.'
    ]);
}

?>

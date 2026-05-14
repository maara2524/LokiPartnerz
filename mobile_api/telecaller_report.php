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
$artist_id = isset($_GET['artist_id']) ? (int)$_GET['artist_id'] : 0;
$status = strtolower(trim($_GET['status'] ?? ''));
$report_date = trim($_GET['report_date'] ?? '');
$from_date = trim($_GET['from_date'] ?? '');
$to_date = trim($_GET['to_date'] ?? '');

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
        echo json_encode(['error' => 'Only telecallers can access this report']);
        exit();
    }

    $userId = (int)$user['id'];

    if ($report_date !== '') {
        $parsedDate = DateTime::createFromFormat('Y-m-d', $report_date);
        if (!$parsedDate || $parsedDate->format('Y-m-d') !== $report_date) {
            http_response_code(400);
            echo json_encode(['error' => 'Invalid report_date format. Use YYYY-MM-DD']);
            exit();
        }
    }

    if ($from_date !== '') {
        $parsedFromDate = DateTime::createFromFormat('Y-m-d', $from_date);
        if (!$parsedFromDate || $parsedFromDate->format('Y-m-d') !== $from_date) {
            http_response_code(400);
            echo json_encode(['error' => 'Invalid from_date format. Use YYYY-MM-DD']);
            exit();
        }
    }

    if ($to_date !== '') {
        $parsedToDate = DateTime::createFromFormat('Y-m-d', $to_date);
        if (!$parsedToDate || $parsedToDate->format('Y-m-d') !== $to_date) {
            http_response_code(400);
            echo json_encode(['error' => 'Invalid to_date format. Use YYYY-MM-DD']);
            exit();
        }
    }

    if ($from_date !== '' && $to_date !== '' && $from_date > $to_date) {
        http_response_code(400);
        echo json_encode(['error' => 'from_date cannot be later than to_date']);
        exit();
    }

    if ($report_date !== '' && ($from_date !== '' || $to_date !== '')) {
        http_response_code(400);
        echo json_encode(['error' => 'Use either report_date or from_date/to_date']);
        exit();
    }

    if (($from_date !== '' && $to_date === '') || ($from_date === '' && $to_date !== '')) {
        http_response_code(400);
        echo json_encode(['error' => 'Both from_date and to_date are required for range filtering']);
        exit();
    }

    $sql = "
        SELECT
            l.id,
            l.customer_name,
            l.event_date,
            l.location,
            l.event_type,
            l.budget_range,
            DATE(tlt.updated_at) AS report_date,
            COALESCE(sm.status_name, 'new') AS status,
            COALESCE(ec.id, 0) AS assigned_artist_id,
            COALESCE(ec.name, 'Unassigned') AS assigned_artist_name,
            tlt.updated_at,
            tlt.created_at
        FROM team_lead_tracking tlt
        INNER JOIN leads l
            ON l.id = tlt.lead_id
        LEFT JOIN status_master sm
            ON sm.status_id = tlt.current_status_id
        LEFT JOIN elite_clients ec
            ON ec.id = tlt.assigned_artist_id
        WHERE (
            tlt.team_member_id = :team_member_id
            OR tlt.created_by = :created_by
            OR tlt.last_updated_by = :last_updated_by
            OR EXISTS (
                SELECT 1
                FROM lead_activity la
                WHERE la.tracking_id = tlt.tracking_id
                  AND la.performed_by = :performed_by
            )
        )
    ";

    $params = [
        ':team_member_id' => $userId,
        ':created_by' => $userId,
        ':last_updated_by' => $userId,
        ':performed_by' => $userId,
    ];

    if ($artist_id > 0) {
        $sql .= " AND tlt.assigned_artist_id = :artist_id";
        $params[':artist_id'] = $artist_id;
    }

    if ($status !== '') {
        $sql .= " AND LOWER(COALESCE(sm.status_name, 'new')) = :status";
        $params[':status'] = $status;
    }

    if ($report_date !== '') {
        $sql .= " AND DATE(tlt.updated_at) = :report_date";
        $params[':report_date'] = $report_date;
    }

    if ($from_date !== '' && $to_date !== '') {
        $sql .= " AND DATE(tlt.updated_at) BETWEEN :from_date AND :to_date";
        $params[':from_date'] = $from_date;
        $params[':to_date'] = $to_date;
    }

    $sql .= " ORDER BY tlt.updated_at DESC, l.event_date ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $leads = [];
    foreach ($rows as $row) {
        $eventTypeRaw = $row['event_type'] ?? '';
        $eventTypeFormatted = $eventTypeRaw;

        if (!empty($eventTypeRaw)) {
            $decoded = json_decode($eventTypeRaw, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $decoded = array_filter(array_map('trim', $decoded), 'strlen');
                $eventTypeFormatted = implode(', ', $decoded);
            }
        }

        $leads[] = [
            'id' => (int)$row['id'],
            'customer_name' => $row['customer_name'] ?: 'Unknown',
            'report_date' => $row['report_date'] ?: '',
            'event_date' => $row['event_date'] ?: '',
            'location' => $row['location'] ?: '',
            'event_type' => $eventTypeFormatted ?: '',
            'budget_range' => $row['budget_range'] ?: 'Not Specified',
            'status' => $row['status'] ?: 'new',
            'assigned_artist_id' => (int)$row['assigned_artist_id'],
            'assigned_artist_name' => $row['assigned_artist_name'] ?: 'Unassigned',
            'updated_at' => $row['updated_at'] ?: $row['created_at'] ?: '',
        ];
    }

    echo json_encode([
        'success' => true,
        'count' => count($leads),
        'filters' => [
            'artist_id' => $artist_id > 0 ? $artist_id : null,
            'status' => $status !== '' ? $status : null,
            'report_date' => $report_date !== '' ? $report_date : null,
            'from_date' => $from_date !== '' ? $from_date : null,
            'to_date' => $to_date !== '' ? $to_date : null,
        ],
        'leads' => $leads,
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Failed to fetch telecaller report: ' . $e->getMessage()
    ]);
}

?>

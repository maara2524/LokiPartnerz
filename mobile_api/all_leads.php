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

    // Load database config
    $config_file = __DIR__ . '/../app/config/database.php';
    if (!file_exists($config_file)) {
        throw new Exception('Database config not found');
    }
    include $config_file;

    // Create PDO connection
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Set MySQL timezone
    $pdo->exec("SET time_zone = '+05:30'");

    // Load system settings
    $stmt = $pdo->prepare("
        SELECT setting_key, setting_value
        FROM system_settings
        WHERE setting_key IN ('lead_visibility_delay_hours')
    ");
    $stmt->execute();

    $settings = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $settings[$row['setting_key']] = $row['setting_value'];
    }

    $visibilityDelay = (int)($settings['lead_visibility_delay_hours'] ?? 0);

    // Validate token
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

    $userId = (int)$user['id'];
    $userRole = $user['role'];
    $telecallerLeadStartDate = '2026-07-01 00:00:00';

    // Get artist category
    $artistCategory = null;

    if ($userRole !== 'telecaller') {

        $stmt = $pdo->prepare("
            SELECT category
            FROM artist_profiles
            WHERE user_id = ?
            LIMIT 1
        ");
        $stmt->execute([$userId]);
        $profile = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$profile || empty($profile['category'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Artist category not set for this user']);
            exit();
        }

        $artistCategory = $profile['category'];
    }

    // Reset expired leads and close the corresponding claim log entries.
    $pdo->beginTransaction();

    $expiredStmt = $pdo->query("
        SELECT id, claimed_by
        FROM leads
        WHERE claim_expiry IS NOT NULL
          AND claim_expiry < NOW()
          AND status != 'booked'
          AND status != 'closed'
          AND claimed_by IS NOT NULL
    ");

    $expiredClaims = $expiredStmt->fetchAll(PDO::FETCH_ASSOC);

    if (!empty($expiredClaims)) {
        $releaseStmt = $pdo->prepare("
            UPDATE claimed_leads_log
            SET release_time = NOW(),
                release_reason = 'expired'
            WHERE lead_id = ?
              AND user_id = ?
              AND release_time IS NULL
        ");

        foreach ($expiredClaims as $expiredClaim) {
            $releaseStmt->execute([
                (int)$expiredClaim['id'],
                (int)$expiredClaim['claimed_by']
            ]);
        }
    }

    $pdo->exec("
        UPDATE leads
        SET status = 'new',
            claimed_by = NULL,
            claim_expiry = NULL,
            is_locked = 0
        WHERE claim_expiry IS NOT NULL
          AND claim_expiry < NOW()
          AND status != 'booked'
          AND status != 'closed'
    ");

    $pdo->commit();

    // Fetch leads
    if ($userRole === 'telecaller') {

        $sql = "
            SELECT 
                l.id,
                l.customer_name,
                l.event_date,
                l.location,
                l.event_type,
                l.status,
                l.budget_range,
                l.created_at,
                COALESCE(l.claim_count,0) AS claim_count,
                l.services_required
            FROM leads l
            WHERE
            l.created_at >= :telecallerLeadStartDate
            AND
            (l.event_date IS NULL OR l.event_date > DATE_ADD(CURDATE(), INTERVAL 2 DAY))
            AND (l.created_at <= DATE_SUB(NOW(), INTERVAL :delay HOUR))
            AND NOT EXISTS (
                SELECT 1
                FROM team_lead_tracking tlt
                LEFT JOIN status_master sm
                    ON sm.status_id = tlt.current_status_id
                WHERE tlt.lead_id = l.id
                  AND (
                    (
                        LOWER(COALESCE(sm.status_name, 'new')) <> 'new'
                        AND EXISTS (
                            SELECT 1
                            FROM users owner
                            WHERE owner.role = 'telecaller'
                              AND owner.id IN (tlt.team_member_id, tlt.created_by, tlt.last_updated_by)
                        )
                    )
                    OR EXISTS (
                        SELECT 1
                        FROM lead_activity la
                        INNER JOIN users performer
                            ON performer.id = la.performed_by
                           AND performer.role = 'telecaller'
                        LEFT JOIN status_master activity_sm
                            ON activity_sm.status_id = la.status_id
                        WHERE la.tracking_id = tlt.tracking_id
                          AND (
                            la.activity_type = 'telecaller_status'
                            OR la.activity_type = 'artist_assignment'
                            OR LOWER(COALESCE(activity_sm.status_name, 'new')) <> 'new'
                          )
                    )
                  )
            )
            AND l.id NOT IN (
                SELECT lead_id FROM claimed_leads_log WHERE user_id = :userId
            )
            ORDER BY l.created_at DESC
        ";
    } else {

        $sql = "
            SELECT 
                l.id,
                l.customer_name,
                l.event_date,
                l.location,
                l.event_type,
                l.status,
                l.budget_range,
                l.created_at,
                COALESCE(l.claim_count,0) AS claim_count,
                l.services_required
            FROM leads l
            WHERE l.status = 'new'
            AND (l.claimed_by IS NULL OR l.claim_expiry < NOW())
            AND (l.event_date IS NULL OR l.event_date > DATE_ADD(CURDATE(), INTERVAL 2 DAY))
            AND (l.created_at <= DATE_SUB(NOW(), INTERVAL :delay HOUR))
            AND l.is_locked = 0
            AND COALESCE(l.claim_count,0) < l.max_claims_allowed
            AND JSON_SEARCH(
                    LOWER(l.services_required),
                    'one',
                    LOWER(:artistCategory),
                    NULL,
                    '$'
                ) IS NOT NULL
            AND l.id NOT IN (
                SELECT lead_id FROM claimed_leads_log WHERE user_id = :userId
            )
            ORDER BY l.created_at DESC
        ";
    }

    $stmt = $pdo->prepare($sql);

    $stmt->bindValue(':delay', $visibilityDelay, PDO::PARAM_INT);
    $stmt->bindValue(':userId', $userId, PDO::PARAM_INT);

    if ($userRole === 'telecaller') {
        $stmt->bindValue(':telecallerLeadStartDate', $telecallerLeadStartDate, PDO::PARAM_STR);
    } else {
        $stmt->bindValue(':artistCategory', $artistCategory, PDO::PARAM_STR);
    }

    $stmt->execute();
    $leads = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Format output
    $formattedLeads = [];

    foreach ($leads as $lead) {

        $budget = 'Not Specified';

        if (!empty($lead['created_at'])) {

            $leadDate = date('Y-m-d', strtotime($lead['created_at']));
            $budgetStartDate = '2026-03-10';

            if ($leadDate >= $budgetStartDate) {
                $budget = $lead['budget_range'] ?: 'Not Specified';
            }
        }

        // Format event_type field
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
            'id'            => (int)$lead['id'],
            'customer_name' => $lead['customer_name'] ?: 'Unknown',
            'event_date'    => $lead['event_date'] ?: '',
            'location'      => $lead['location'] ?: '',
            'event_type'    => $eventTypeFormatted,
            'status'        => $lead['status'] ?: 'new',
            'budget_range'  => $budget,
            'claim_count'   => (int)$lead['claim_count'],
            'locked_until'  => null
        ];
    }

    echo json_encode([
        'success' => true,
        'leads'   => $formattedLeads,
        'count'   => count($formattedLeads)
    ]);

} catch (Exception $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    http_response_code(500);
    error_log('BBM all_leads failure: ' . $e->getMessage());
    echo json_encode(['error' => 'Failed to fetch leads. Please try again.']);
}

?>

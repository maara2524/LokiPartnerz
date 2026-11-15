<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

$data = json_decode(file_get_contents('php://input'), true);
if (!$data) $data = $_POST;

$leadId = isset($data['lead_id']) ? intval($data['lead_id']) : 0;
$token  = $data['token'] ?? '';

if (empty($leadId) || empty($token)) {
    http_response_code(400);
    echo json_encode(['error' => 'Lead ID and token required']);
    exit();
}

try {
    // Database config
    include __DIR__ . '/../app/config/database.php';

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->exec("SET time_zone = '+05:30'");

    // Validate user token
    $stmt = $pdo->prepare("
        SELECT id, level
        FROM users
        WHERE api_token = ?
          AND token_expires > NOW()
          AND status = 'active'
        LIMIT 1
    ");
    $stmt->execute([$token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    $userId    = (int)$user['id'];
    $userLevel = (int)$user['level'];

    // Keep the claim allowance in sync with stats: use max_claim_limit when
    // set, otherwise fall back to the default for this subscription's plan.
    $stmt = $pdo->prepare("
        SELECT sh.id, sh.total_leads_claimed, sh.end_date,
               sh.max_claim_limit, sp.artist_level
        FROM subscription_history sh
        LEFT JOIN subscription_plans sp ON sp.id = sh.plan_id
        WHERE sh.user_id = ?
          AND sh.status IN ('active', 'expired')
        ORDER BY (sh.status = 'active' AND sh.end_date > NOW()) DESC,
                 sh.start_date DESC, sh.id DESC
        LIMIT 1
    ");
    $stmt->execute([$userId]);
    $subscription = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$subscription) {
        http_response_code(403);
        echo json_encode(['error' => 'No active subscription']);
        exit();
    }

    $subscriptionId     = (int)$subscription['id'];
    $totalLeadsClaimed  = (int)$subscription['total_leads_claimed'];

    $maxTotalClaims = (int)($subscription['max_claim_limit'] ?? 0);
    if ($maxTotalClaims <= 0) {
        // Match stats: use the plan's artist level for the default allowance.
        $stmt = $pdo->prepare("
            SELECT setting_value
            FROM system_settings
            WHERE setting_key = 'max_total_claims'
              AND user_level = ?
            LIMIT 1
        ");
        $planLevel = (int)($subscription['artist_level'] ?? 0);
        $stmt->execute([$planLevel > 0 ? $planLevel : $userLevel]);
        $maxTotalClaims = (int)$stmt->fetchColumn();
    }

    if ($maxTotalClaims <= 0) {
        http_response_code(403);
        echo json_encode(['error' => 'Claim limit is not configured']);
        exit();
    }

    if ($totalLeadsClaimed >= $maxTotalClaims) {
        $pdo->prepare("
            UPDATE subscription_history
            SET status = 'expired'
            WHERE id = ?
        ")->execute([$subscriptionId]);

        // Mark user inactive
        $pdo->prepare("
            UPDATE users
            SET status = 'inactive', level = 5
            WHERE id = ?
        ")->execute([$userId]);

        http_response_code(403);
        echo json_encode(['error' => 'Subscription limit reached']);
        exit();
    }

    // Fetch daily claim limit
    $stmt = $pdo->prepare("
        SELECT setting_value
        FROM system_settings
        WHERE setting_key = 'max_claims_per_day'
          AND user_level = ?
        LIMIT 1
    ");
    $stmt->execute([$userLevel]);
    $maxClaimsPerDay = (int)$stmt->fetchColumn();
    if ($maxClaimsPerDay <= 0) $maxClaimsPerDay = 4;

    // Begin transaction
    $pdo->beginTransaction();

    // Lock lead row for atomic claim
    $stmt = $pdo->prepare("
        SELECT id, event_date, status, is_locked, claimed_by, claim_count, max_claims_allowed
        FROM leads
        WHERE id = ?
        FOR UPDATE
    ");
    $stmt->execute([$leadId]);
    $lead = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$lead) {
        $pdo->rollBack();
        http_response_code(404);
        echo json_encode(['error' => 'Lead not found']);
        exit();
    }

    if (in_array($lead['status'], ['booked', 'closed'], true)) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead already booked or closed']);
        exit();
    }

    // Single active claimer rule: if already locked/claimed by another user, reject.
    if ((int)$lead['is_locked'] === 1 && (int)$lead['claimed_by'] !== $userId) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead already claimed by another user']);
        exit();
    }

    if ((int)$lead['claim_count'] >= (int)$lead['max_claims_allowed']) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead fully claimed']);
        exit();
    }

    // Event date validation
    if (!empty($lead['event_date']) && strtotime($lead['event_date']) < strtotime('+2 day')) {
        $pdo->rollBack();
        http_response_code(404);
        echo json_encode(['error' => 'Event too close or expired']);
        exit();
    }

    // Daily claim count
    $stmt = $pdo->prepare("
        SELECT COUNT(*)
        FROM claimed_leads_log
        WHERE user_id = ?
          AND DATE(claim_time) = CURDATE()
    ");
    $stmt->execute([$userId]);
    $claimsToday = (int)$stmt->fetchColumn();

    if ($claimsToday >= $maxClaimsPerDay) {
        $pdo->rollBack();
        http_response_code(429);
        echo json_encode(['error' => 'Daily claim limit reached']);
        exit();
    }

    // Check if this user has ever claimed this lead.
    $stmt = $pdo->prepare("
        SELECT id
        FROM claimed_leads_log
        WHERE lead_id = ?
          AND user_id = ?
        LIMIT 1
    ");
    $stmt->execute([$leadId, $userId]);
    if ($stmt->fetch()) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead already claimed']);
        exit();
    }

    // Fetch claim lock duration (in hours)
    $stmt = $pdo->prepare("
        SELECT setting_value
        FROM system_settings
        WHERE setting_key = 'claim_lock_duration_hours'
        AND user_level = 3
        LIMIT 1
    ");
    $stmt->execute();
    $lockDurationHours = (int)$stmt->fetchColumn();

    // fallback (safety)
    if ($lockDurationHours <= 0) {
        $lockDurationHours = 48;
    }

    // Insert claim log
    $stmt = $pdo->prepare("
        INSERT INTO claimed_leads_log (lead_id, user_id, claim_time)
        VALUES (?, ?, NOW())
    ");
    $stmt->execute([$leadId, $userId]);
    $claimId = $pdo->lastInsertId();

    // Lead status history
    $stmt = $pdo->prepare("
        INSERT INTO lead_status_history
        (lead_id, old_status, new_status, changed_by, changed_at)
        VALUES (?, NULL, 'new', ?, NOW())
    ");
    $stmt->execute([$leadId, $userId]);

    // Update lead metadata
    $stmt = $pdo->prepare("
        UPDATE leads
        SET claim_count = COALESCE(claim_count,0) + 1,
            claimed_by = ?,
            claim_time = NOW(),
            claim_expiry = DATE_ADD(NOW(), INTERVAL ? HOUR),
            is_locked = 1
        WHERE id = ?
        AND (is_locked = 0 OR claimed_by = ?)
    ");
    $stmt->execute([$userId, $lockDurationHours, $leadId, $userId]);

    if ($stmt->rowCount() === 0) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead already claimed by another user']);
        exit();
    }

    // Increment usage only while allowance remains, preventing concurrent
    // claims from exceeding the plan limit.
    $stmt = $pdo->prepare("
        UPDATE subscription_history
        SET total_leads_claimed = total_leads_claimed + 1
        WHERE id = ? AND total_leads_claimed < ?
    ");
    $stmt->execute([$subscriptionId, $maxTotalClaims]);

    if ($stmt->rowCount() === 0) {
        $pdo->rollBack();
        $pdo->prepare("
            UPDATE subscription_history
            SET status = 'expired'
            WHERE id = ? AND total_leads_claimed >= ?
        ")->execute([$subscriptionId, $maxTotalClaims]);
        $pdo->prepare("
            UPDATE users
            SET status = 'inactive', level = 5
            WHERE id = ? AND EXISTS (
                SELECT 1
                FROM subscription_history
                WHERE id = ? AND total_leads_claimed >= ?
            )
        ")->execute([$userId, $subscriptionId, $maxTotalClaims]);
        http_response_code(403);
        echo json_encode(['error' => 'Subscription limit reached']);
        exit();
    }

    if ($totalLeadsClaimed + 1 >= $maxTotalClaims) {
        $pdo->prepare("
            UPDATE subscription_history
            SET status = 'expired'
            WHERE id = ?
        ")->execute([$subscriptionId]);
        $pdo->prepare("
            UPDATE users
            SET status = 'inactive', level = 5
            WHERE id = ?
        ")->execute([$userId]);
    }

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Lead claimed successfully',
        'lead_id' => $leadId,
        'claim_id' => $claimId
    ]);
    exit();

} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    echo json_encode(['error' => 'Server error']);
    exit();
}

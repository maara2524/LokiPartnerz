<?php
/**
 * Return the caller's current subscription entitlement.
 *
 * The iOS app uses this to restore a currently active entitlement to the
 * signed-in Loki Partnerz account. Non-renewing subscription access is tracked
 * by the app's account and fixed term, not by automatic renewal.
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

date_default_timezone_set('Asia/Kolkata');

$input = [];
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $decoded = json_decode(file_get_contents('php://input'), true);
    if (is_array($decoded)) {
        $input = $decoded;
    } else {
        $input = $_POST;
    }
} else {
    $input = $_GET;
}

$token = trim((string)($input['token'] ?? ''));
if ($token === '') {
    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (stripos($authorization, 'Bearer ') === 0) {
        $token = trim(substr($authorization, 7));
    }
}

if ($token === '') {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Authentication token required']);
    exit();
}

try {
    require __DIR__ . '/../../app/config/database.php';

    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $pdo->exec("SET time_zone = '+05:30'");

    $stmt = $pdo->prepare("
        SELECT id, username, role, status, level
        FROM users
        WHERE api_token = ? AND token_expires > NOW()
        LIMIT 1
    ");
    $stmt->execute([$token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['success' => false, 'error' => 'Invalid or expired token']);
        exit();
    }

    $userId = (int)$user['id'];

    $stmt = $pdo->prepare("
        SELECT sh.plan_id, sh.plan_name, sh.start_date, sh.end_date,
               sh.total_leads_claimed, sh.max_claim_limit, sp.slug
        FROM subscription_history sh
        LEFT JOIN subscription_plans sp ON sp.id = sh.plan_id
        WHERE sh.user_id = ?
          AND sh.status = 'active'
          AND sh.end_date > NOW()
        ORDER BY sh.start_date DESC, sh.id DESC
        LIMIT 1
    ");
    $stmt->execute([$userId]);
    $subscription = $stmt->fetch(PDO::FETCH_ASSOC);

    $level = (int)$user['level'];
    $status = (string)$user['status'];

    echo json_encode([
        'success' => true,
        'has_active_subscription' => (bool)$subscription,
        'user' => [
            'id' => $userId,
            'status' => $status,
            'level' => $level,
        ],
        'subscription' => $subscription ? [
            'plan_id' => (int)$subscription['plan_id'],
            'plan_name' => $subscription['plan_name'],
            'slug' => $subscription['slug'],
            'start_date' => $subscription['start_date'],
            'end_date' => $subscription['end_date'],
            'total_leads_claimed' => (int)$subscription['total_leads_claimed'],
            'max_claim_limit' => (int)$subscription['max_claim_limit'],
        ] : null,
    ]);
} catch (Throwable $e) {
    error_log('[APPLE_IAP] get_my_subscription: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Could not load subscription status']);
}

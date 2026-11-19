<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function respond(array $payload, int $statusCode = 200): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit();
}

function get_input(): array
{
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw ?: '', true);

    return is_array($decoded) ? $decoded : $_POST;
}

function get_bearer_token(array $input): ?string
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if (is_string($authHeader) && preg_match('/Bearer\s+(.+)/i', $authHeader, $matches)) {
        return trim($matches[1]);
    }

    $token = $_GET['token'] ?? $input['token'] ?? $input['api_token'] ?? null;
    return is_string($token) && trim($token) !== '' ? trim($token) : null;
}

function table_exists(PDO $pdo, string $table): bool
{
    $stmt = $pdo->prepare(
        'SELECT COUNT(*)
         FROM INFORMATION_SCHEMA.TABLES
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = ?'
    );
    $stmt->execute([$table]);

    return (int)$stmt->fetchColumn() > 0;
}

function run_if_table_exists(PDO $pdo, string $table, string $sql, array $params): void
{
    if (!table_exists($pdo, $table)) {
        return;
    }

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(['success' => false, 'message' => 'Method not allowed'], 405);
}

$input = get_input();
$token = get_bearer_token($input);

if ($token === null) {
    respond(['success' => false, 'message' => 'Authentication token required'], 401);
}

try {
    require __DIR__ . '/../app/config/database.php';

    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    $pdo->exec("SET time_zone = '+05:30'");

    $stmt = $pdo->prepare(
        'SELECT id, role
         FROM users
         WHERE api_token = ?
           AND token_expires > NOW()
         LIMIT 1'
    );
    $stmt->execute([$token]);
    $user = $stmt->fetch();

    if (!$user) {
        respond(['success' => false, 'message' => 'Invalid or expired token'], 401);
    }

    if (($user['role'] ?? '') === 'admin') {
        respond(['success' => false, 'message' => 'Admin accounts cannot be deleted from the mobile app'], 403);
    }

    $userId = (int)$user['id'];

    $pdo->beginTransaction();

    try {
        run_if_table_exists(
            $pdo,
            'leads',
            'UPDATE leads
             SET claimed_by = NULL,
                 claim_time = NULL,
                 claim_expiry = NULL,
                 is_locked = 0,
                 is_claimed = 0
             WHERE claimed_by = ?',
            [$userId]
        );

        run_if_table_exists(
            $pdo,
            'lead_activity',
            'UPDATE lead_activity SET performed_by = NULL WHERE performed_by = ?',
            [$userId]
        );

        run_if_table_exists(
            $pdo,
            'system_settings',
            'UPDATE system_settings SET updated_by = NULL WHERE updated_by = ?',
            [$userId]
        );

        run_if_table_exists(
            $pdo,
            'team_lead_tracking',
            'UPDATE team_lead_tracking SET last_updated_by = NULL WHERE last_updated_by = ?',
            [$userId]
        );

        foreach ([
            'lead_notes' => 'user_id',
            'lead_status_history' => 'changed_by',
            'lead_assignments' => 'assigned_by',
            'claimed_leads_log' => 'user_id',
            'notifications' => 'user_id',
            'user_claim_limits' => 'user_id',
            'user_video_access' => 'user_id',
            'subscription_history' => 'user_id',
            'subscription_transactions' => 'user_id',
            'teams' => 'user_id',
            'artist_profiles' => 'user_id',
        ] as $table => $column) {
            run_if_table_exists(
                $pdo,
                $table,
                "DELETE FROM {$table} WHERE {$column} = ?",
                [$userId]
            );
        }

        $deleteUser = $pdo->prepare('DELETE FROM users WHERE id = ?');
        $deleteUser->execute([$userId]);

        $pdo->commit();

        respond([
            'success' => true,
            'message' => 'Account deleted successfully',
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        error_log('Account deletion failed for user ' . $userId . ': ' . $e->getMessage());
        respond(['success' => false, 'message' => 'Unable to delete account. Please contact support.'], 500);
    }
} catch (Throwable $e) {
    error_log('Account deletion bootstrap failed: ' . $e->getMessage());
    respond(['success' => false, 'message' => 'Account deletion failed. Please try again.'], 500);
}

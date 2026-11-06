<?php

declare(strict_types=1);

require_once __DIR__ . '/subscriptions/apple_iap_helpers.php';

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
        'SELECT u.id, u.role, ap.whatsapp_number
         FROM users u
         LEFT JOIN artist_profiles ap ON ap.user_id = u.id
         WHERE u.api_token = ?
           AND u.token_expires > NOW()
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
    $whatsappNumber = trim((string)($user['whatsapp_number'] ?? ''));

    $pdo->beginTransaction();

    try {
        if (!table_exists($pdo, 'account_deletion_audit')
            || !table_exists($pdo, 'account_deletion_apple_transaction_hashes')) {
            throw new RuntimeException('Account deletion migration has not been applied');
        }

        $pdo->exec('INSERT INTO account_deletion_audit () VALUES ()');
        $deletionAuditId = (int)$pdo->lastInsertId();

        $teamIds = [];
        if (table_exists($pdo, 'teams')) {
            $stmt = $pdo->prepare('SELECT team_id FROM teams WHERE user_id = ?');
            $stmt->execute([$userId]);
            $teamIds = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
        }

        foreach ($teamIds as $teamId) {
            run_if_table_exists(
                $pdo,
                'artist_assignment_history',
                'DELETE FROM artist_assignment_history WHERE changed_by = ?',
                [$teamId]
            );
            run_if_table_exists(
                $pdo,
                'call_log',
                'DELETE FROM call_log WHERE logged_by = ?',
                [$teamId]
            );
            run_if_table_exists(
                $pdo,
                'follow_up_reminders',
                'DELETE FROM follow_up_reminders WHERE created_by = ? OR completed_by = ?',
                [$teamId, $teamId]
            );
            run_if_table_exists(
                $pdo,
                'lead_assignment_history',
                'DELETE FROM lead_assignment_history
                 WHERE assigned_by = ?
                    OR assigned_from_team_id = ?
                    OR assigned_to_team_id = ?',
                [$teamId, $teamId, $teamId]
            );
            run_if_table_exists(
                $pdo,
                'team_lead_notes',
                'DELETE FROM team_lead_notes WHERE team_member_id = ?',
                [$teamId]
            );
            run_if_table_exists(
                $pdo,
                'team_lead_tracking',
                'UPDATE team_lead_tracking
                 SET team_member_id = NULL,
                     last_updated_by = NULL
                 WHERE team_member_id = ? OR last_updated_by = ?',
                [$teamId, $teamId]
            );
        }

        if (table_exists($pdo, 'subscription_transactions')) {
            $stmt = $pdo->prepare(
                "SELECT apple_transaction_id
                 FROM subscription_transactions
                 WHERE user_id = ?
                   AND provider = 'apple'
                   AND apple_transaction_id IS NOT NULL"
            );
            $stmt->execute([$userId]);
            $insertHash = $pdo->prepare(
                'INSERT INTO account_deletion_apple_transaction_hashes
                    (transaction_hash, deletion_audit_id)
                 VALUES (?, ?)'
            );
            foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) as $transactionId) {
                $insertHash->execute([
                    apple_transaction_tombstone_hash((string)$transactionId),
                    $deletionAuditId,
                ]);
            }
        }

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
            'DELETE FROM lead_activity WHERE performed_by = ?',
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
            'UPDATE team_lead_tracking
             SET created_by = NULL,
                 last_updated_by = NULL
             WHERE created_by = ? OR last_updated_by = ?',
            [$userId, $userId]
        );

        run_if_table_exists(
            $pdo,
            'loki_eventz_check_ins',
            'DELETE FROM loki_eventz_check_ins WHERE user_id = ?',
            [$userId]
        );

        if ($whatsappNumber !== '') {
            run_if_table_exists(
                $pdo,
                'password_resets',
                'DELETE FROM password_resets WHERE mobile = ?',
                [$whatsappNumber]
            );
            run_if_table_exists(
                $pdo,
                'otp_requests',
                'DELETE FROM otp_requests WHERE phone = ?',
                [$whatsappNumber]
            );
        }

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

        error_log('Account deletion failed: ' . $e->getMessage());
        respond(['success' => false, 'message' => 'Unable to delete account. Please contact support.'], 500);
    }
} catch (Throwable $e) {
    error_log('Account deletion bootstrap failed: ' . $e->getMessage());
    respond(['success' => false, 'message' => 'Account deletion failed. Please try again.'], 500);
}

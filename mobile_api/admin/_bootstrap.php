<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

date_default_timezone_set('Asia/Kolkata');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function admin_respond(array $payload, int $statusCode = 200): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit();
}

function admin_success(array $payload = [], int $statusCode = 200): void
{
    admin_respond(array_merge(['success' => true], $payload), $statusCode);
}

function admin_error(string $message, int $statusCode = 400, array $extra = []): void
{
    admin_respond(array_merge(['success' => false, 'error' => $message], $extra), $statusCode);
}

function admin_require_method(array $allowedMethods): void
{
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    if (!in_array($method, $allowedMethods, true)) {
        admin_error('Method not allowed', 405);
    }
}

function admin_get_input(): array
{
    static $input = null;

    if ($input !== null) {
        return $input;
    }

    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw ?: '', true);

    if (is_array($decoded)) {
        $input = $decoded;
        return $input;
    }

    $input = $_POST;
    return $input;
}

function admin_get_bearer_token(): ?string
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if (is_string($authHeader) && preg_match('/Bearer\s+(.+)/i', $authHeader, $matches)) {
        return trim($matches[1]);
    }

    $input = admin_get_input();
    $token = $_GET['token'] ?? $input['token'] ?? $input['api_token'] ?? null;
    return is_string($token) && trim($token) !== '' ? trim($token) : null;
}

function admin_get_pdo(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $configFile = __DIR__ . '/../../app/config/database.php';
    if (!file_exists($configFile)) {
        admin_error('Database configuration not found', 500);
    }

    include $configFile;

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

    return $pdo;
}

function admin_require_user(array $allowedRoles = ['admin']): array
{
    $token = admin_get_bearer_token();
    if ($token === null) {
        admin_error('Authentication token required', 401);
    }

    $pdo = admin_get_pdo();
    $stmt = $pdo->prepare(
        'SELECT id, username, email, role, status, level, api_token, token_expires
         FROM users
         WHERE api_token = ?
         LIMIT 1'
    );
    $stmt->execute([$token]);
    $user = $stmt->fetch();

    if (!$user) {
        admin_error('Invalid or expired token', 401);
    }

    $tokenExpires = $user['token_expires'] ?? null;
    if (!empty($tokenExpires) && strtotime((string)$tokenExpires) < time()) {
        admin_error('Session expired. Please login again.', 401);
    }

    if (($user['status'] ?? '') !== 'active') {
        admin_error('Your account is inactive', 403);
    }

    if (!in_array($user['role'] ?? '', $allowedRoles, true)) {
        admin_error('You do not have permission to access this resource', 403);
    }

    return $user;
}

function admin_normalize_category(?string $category): string
{
    $value = strtolower(trim((string)$category));

    return match ($value) {
        'events', 'events (dance, catering etc.)' => 'Events',
        'photography' => 'Photography',
        'others', 'other' => 'Others',
        default => 'Makeup',
    };
}

function admin_format_datetime(?string $value): ?string
{
    if (!$value) {
        return null;
    }

    $timestamp = strtotime($value);
    if ($timestamp === false) {
        return null;
    }

    return date('j M Y', $timestamp);
}

function admin_format_ist_datetime(?string $value): ?string
{
    if (!$value) {
        return null;
    }

    $timestamp = strtotime($value);
    if ($timestamp === false) {
        return null;
    }

    return date('j M Y, g:i A', $timestamp);
}

function admin_humanize_relative(?string $value): string
{
    if (!$value) {
        return 'just now';
    }

    $timestamp = strtotime($value);
    if ($timestamp === false) {
        return 'just now';
    }

    $delta = max(0, time() - $timestamp);
    if ($delta < 60) {
        return 'just now';
    }
    if ($delta < 3600) {
        return floor($delta / 60) . 'm ago';
    }
    if ($delta < 86400) {
        return floor($delta / 3600) . 'h ago';
    }

    return floor($delta / 86400) . 'd ago';
}

function admin_effective_lead_status(?string $status, ?int $claimedBy = null, ?int $isClaimed = null): string
{
    $rawStatus = trim((string)$status);

    if ($rawStatus === 'new' && (($claimedBy ?? 0) > 0 || ($isClaimed ?? 0) === 1)) {
        return 'claimed';
    }

    return $rawStatus !== '' ? $rawStatus : 'new';
}

function admin_upsert_system_setting(PDO $pdo, string $key, string $value, ?int $updatedBy = null, int $userLevel = 3, ?string $description = null): void
{
    $select = $pdo->prepare('SELECT id FROM system_settings WHERE setting_key = ? AND user_level = ? LIMIT 1');
    $select->execute([$key, $userLevel]);
    $existing = $select->fetch();

    if ($existing) {
        $update = $pdo->prepare(
            'UPDATE system_settings
             SET setting_value = ?, description = COALESCE(?, description), updated_by = ?, updated_at = CURRENT_TIMESTAMP
             WHERE id = ?'
        );
        $update->execute([$value, $description, $updatedBy, $existing['id']]);
        return;
    }

    $insert = $pdo->prepare(
        'INSERT INTO system_settings (setting_key, user_level, setting_value, description, updated_by)
         VALUES (?, ?, ?, ?, ?)'
    );
    $insert->execute([$key, $userLevel, $value, $description, $updatedBy]);
}

function admin_upsert_app_ui_config(PDO $pdo, ?int $id, string $screen, string $keyName, string $value, int $status = 1): int
{
    if ($id !== null) {
        $update = $pdo->prepare(
            'UPDATE app_ui_config
             SET screen = ?, key_name = ?, value = ?, status = ?
             WHERE id = ?'
        );
        $update->execute([$screen, $keyName, $value, $status, $id]);
        return $id;
    }

    $insert = $pdo->prepare(
        'INSERT INTO app_ui_config (screen, key_name, value, status)
         VALUES (?, ?, ?, ?)'
    );
    $insert->execute([$screen, $keyName, $value, $status]);

    return (int)$pdo->lastInsertId();
}

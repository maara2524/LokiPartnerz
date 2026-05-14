<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);
$input = admin_get_input();

$id = isset($input['id']) ? (int)$input['id'] : null;
$screen = trim((string)($input['screen'] ?? ''));
$key = trim((string)($input['key'] ?? ''));
$value = trim((string)($input['value'] ?? ''));
$status = isset($input['status']) ? (int)$input['status'] : 1;

if ($screen === '' || $key === '') {
    admin_error('Screen and key are required');
}

$pdo = admin_get_pdo();
$savedId = admin_upsert_app_ui_config($pdo, $id, $screen, $key, $value, $status);

admin_success([
    'message' => 'UI config updated',
    'id' => $savedId,
]);

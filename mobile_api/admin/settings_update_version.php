<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);
$input = admin_get_input();

$latestVersion = trim((string)($input['latest_version'] ?? ''));
$minimumVersion = trim((string)($input['minimum_version'] ?? ''));
$updateRequired = !empty($input['update_required']) ? 1 : 0;
$message = trim((string)($input['update_message'] ?? 'A new version is available. Please update to continue.'));

if ($latestVersion === '' || $minimumVersion === '') {
    admin_error('Latest and minimum versions are required');
}

$pdo = admin_get_pdo();
$stmt = $pdo->prepare(
    "UPDATE app_version_config
     SET latest_version = ?, minimum_version = ?, update_required = ?, update_message = ?
     WHERE platform = 'android'"
);
$stmt->execute([$latestVersion, $minimumVersion, $updateRequired, $message]);

admin_success(['message' => 'Version config updated']);

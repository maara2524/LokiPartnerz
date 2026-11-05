<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);
$input = admin_get_input();

$platform = strtolower(trim((string)($input['platform'] ?? 'android')));
if (!in_array($platform, ['android', 'ios'], true)) {
    admin_error('Platform must be android or ios');
}

$latestVersion = trim((string)($input['latest_version'] ?? ''));
$minimumVersion = trim((string)($input['minimum_version'] ?? ''));
$updateRequired = !empty($input['update_required']) ? 1 : 0;
$message = trim((string)($input['update_message'] ?? 'A new version is available. Please update to continue.'));
$storeUrl = trim((string)($input['store_url'] ?? $input['playstore_url'] ?? ''));

if ($latestVersion === '' || $minimumVersion === '') {
    admin_error('Latest and minimum versions are required');
}

$pdo = admin_get_pdo();

$find = $pdo->prepare(
    "SELECT id FROM app_version_config
     WHERE platform = ?
     ORDER BY id DESC
     LIMIT 1"
);
$find->execute([$platform]);
$existingId = $find->fetchColumn();

if ($existingId !== false && $existingId !== null) {
    $stmt = $pdo->prepare(
        "UPDATE app_version_config
         SET latest_version = ?, minimum_version = ?, update_required = ?,
             update_message = ?, playstore_url = ?
         WHERE id = ?"
    );
    $stmt->execute([
        $latestVersion,
        $minimumVersion,
        $updateRequired,
        $message,
        $storeUrl,
        (int)$existingId,
    ]);
} else {
    $insert = $pdo->prepare(
        "INSERT INTO app_version_config
         (platform, latest_version, minimum_version, update_required, update_message, playstore_url, status)
         VALUES (?, ?, ?, ?, ?, ?, 1)"
    );
    $insert->execute([
        $platform,
        $latestVersion,
        $minimumVersion,
        $updateRequired,
        $message,
        $storeUrl,
    ]);
}

admin_success(['message' => ucfirst($platform) . ' version config updated']);

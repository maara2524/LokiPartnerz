<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
$adminUser = admin_require_user(['admin']);
$input = admin_get_input();

$map = [
    'fcm_enabled' => ['notification_email_enabled', 3, 'Email/push style notifications enabled'],
    'meta_events_enabled' => ['meta_events_enabled', 3, 'Meta events tracking enabled'],
    'lead_lock_enabled' => ['lead_claim_lock_enabled', 3, 'Lead claim lock enabled'],
    'auto_release_enabled' => ['auto_release_enabled', 3, 'Auto release enabled'],
    'subscription_intro_video' => ['subscription_intro_video_enabled', 3, 'Subscription intro video enabled'],
    'maintenance_mode' => ['maintenance_mode', 3, 'Enable maintenance mode'],
    'api_base_url' => ['api_base_url', 3, 'Admin configured API base URL'],
];

$pdo = admin_get_pdo();
$pdo->beginTransaction();

try {
    foreach ($map as $requestKey => [$settingKey, $userLevel, $description]) {
        if (!array_key_exists($requestKey, $input)) {
            continue;
        }

        $value = $input[$requestKey];
        if (is_bool($value)) {
            $storedValue = $value ? '1' : '0';
            if ($requestKey === 'maintenance_mode') {
                $storedValue = $value ? 'true' : 'false';
            }
        } else {
            $storedValue = trim((string)$value);
        }

        admin_upsert_system_setting($pdo, $settingKey, $storedValue, (int)$adminUser['id'], (int)$userLevel, $description);
    }

    $pdo->commit();
    admin_success(['message' => 'System settings updated']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    admin_error($e->getMessage(), 400);
}

<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['GET']);
admin_require_user(['admin']);

$pdo = admin_get_pdo();

$version = $pdo->query(
    "SELECT id, latest_version, minimum_version, update_required, update_message, playstore_url
     FROM app_version_config
     WHERE platform = 'android'
     ORDER BY id DESC
     LIMIT 1"
)->fetch();

$settingsRows = $pdo->query(
    "SELECT setting_key, setting_value
     FROM system_settings
     WHERE user_level = 3"
)->fetchAll();
$settings = [];
foreach ($settingsRows as $row) {
    $settings[$row['setting_key']] = $row['setting_value'];
}

$uiConfig = $pdo->query(
    'SELECT id, screen, key_name, value, status
     FROM app_ui_config
     ORDER BY screen ASC, id ASC'
)->fetchAll();

$telecallers = $pdo->query(
    "SELECT t.team_id, t.username, t.display_name, t.phone, t.active, t.user_id
     FROM teams t
     WHERE t.role = 'telecaller'
     ORDER BY t.created_at DESC, t.team_id DESC"
)->fetchAll();

admin_success([
    'version' => [
        'id' => (int)($version['id'] ?? 0),
        'latest_version' => (string)($version['latest_version'] ?? ''),
        'minimum_version' => (string)($version['minimum_version'] ?? ''),
        'update_required' => !empty($version['update_required']),
        'update_message' => (string)($version['update_message'] ?? ''),
        'playstore_url' => (string)($version['playstore_url'] ?? ''),
    ],
    'toggles' => [
        'fcm_enabled' => (($settings['notification_email_enabled'] ?? '1') === '1'),
        'meta_events_enabled' => (($settings['meta_events_enabled'] ?? '1') === '1'),
        'lead_lock_enabled' => (($settings['lead_claim_lock_enabled'] ?? '1') === '1'),
        'auto_release_enabled' => (($settings['auto_release_enabled'] ?? '1') === '1'),
        'subscription_intro_video' => (($settings['subscription_intro_video_enabled'] ?? '1') === '1'),
        'maintenance_mode' => (($settings['maintenance_mode'] ?? 'false') === 'true'),
    ],
    'ui_config' => array_map(
        static fn(array $row): array => [
            'id' => (int)$row['id'],
            'screen' => (string)$row['screen'],
            'key' => (string)$row['key_name'],
            'value' => (string)$row['value'],
            'status' => (int)$row['status'],
        ],
        $uiConfig
    ),
    'telecallers' => array_map(
        static fn(array $row): array => [
            'id' => (int)$row['team_id'],
            'user_id' => $row['user_id'] ? (int)$row['user_id'] : null,
            'name' => (string)$row['display_name'],
            'username' => (string)$row['username'],
            'phone' => (string)$row['phone'],
            'status' => ((int)$row['active']) === 1 ? 'active' : 'inactive',
        ],
        $telecallers
    ),
    'api' => [
        'base_url' => (string)($settings['api_base_url'] ?? 'https://bbm.lokiwebvibe.com'),
    ],
]);

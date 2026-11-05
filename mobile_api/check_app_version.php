<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$version = $_GET['version'] ?? '';
$platform = strtolower(trim((string)($_GET['platform'] ?? 'android')));

if (!in_array($platform, ['android', 'ios', 'web'], true)) {
    $platform = 'android';
}

if (empty($version)) {
    http_response_code(400);
    echo json_encode(['error' => 'Version required']);
    exit();
}

try {

    include __DIR__ . '/../app/config/database.php';

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $stmt = $pdo->prepare("
        SELECT latest_version, minimum_version, update_required,
               update_message, playstore_url
        FROM app_version_config
        WHERE platform = ?
        AND status = 1
        ORDER BY id DESC
        LIMIT 1
    ");

    $stmt->execute([$platform]);

    $config = $stmt->fetch(PDO::FETCH_ASSOC);

    // No row for this platform (for example iOS before its first release)
    // must not block the app. Return a successful, non-blocking response.
    if (!$config) {
        echo json_encode([
            "success" => true,
            "platform" => $platform,
            "latest_version" => $version,
            "minimum_version" => $version,
            "force_update" => false,
            "update_required" => false,
            "message" => "",
            "store_url" => "",
            "playstore_url" => ""
        ]);
        exit();
    }

    $forceUpdate = version_compare($version, $config['minimum_version'], '<');
    $storeUrl = (string)($config['playstore_url'] ?? '');

    echo json_encode([
        "success" => true,
        "platform" => $platform,
        "latest_version" => $config['latest_version'],
        "minimum_version" => $config['minimum_version'],
        "force_update" => $forceUpdate,
        "update_required" => (bool)$config['update_required'],
        "message" => $config['update_message'],
        // store_url is the generic field used by the app. For iOS the value is
        // the App Store URL; for Android it is the Play Store URL.
        "store_url" => $storeUrl,
        "playstore_url" => $storeUrl
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        "error" => $e->getMessage()
    ]);
}

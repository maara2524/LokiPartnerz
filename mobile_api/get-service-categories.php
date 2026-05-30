<?php

ob_start();

// Set JSON headers first
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Only allow GET requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

try {

    // Direct database connection using LPZ config
    $config_file = __DIR__ . '/../app/config/database.php';

    if (!file_exists($config_file)) {
        throw new Exception('Database config not found');
    }

    include $config_file;

    // Create PDO connection directly
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Fetch active service categories
    $stmt = $pdo->prepare("
        SELECT value
        FROM app_ui_config
        WHERE screen = ?
        AND key_name = ?
        AND status = 1
        ORDER BY id ASC
    ");

    $stmt->execute([
        'registration',
        'service_category'
    ]);

    $categories = $stmt->fetchAll(PDO::FETCH_COLUMN);

    if (ob_get_length()) {
        ob_clean();
    }

    echo json_encode([
        'success' => true,
        'categories' => $categories
    ]);

} catch (Throwable $e) {

    http_response_code(500);

    if (ob_get_length()) {
        ob_clean();
    }

    error_log('Service Category API Error: ' . $e->getMessage());

    echo json_encode([
        'error' => 'Failed to load service categories'
    ]);
}
?>
<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit();
}

function sendWhatsAppOTP($mobile, $otp)
{
    $token = "EAAplKykTsQEBQ0IlVWtcTr8EmVld3wE8Q1ZBVXtb2ZAi3QE0ritQimicyW8GPqjZAbe1brHsbyBaEUsI9MS51EsQROTHhAA1R3G5aSiKv2dsvu6OKOKuIILxIH8IbtkNbfyA130P9yCbwOvNeiZACT91nwSkbXHLngGT4ZCqeTnlJjw1PRXHGpZAP9rZCvZABrH1xgZDZD";
    $phone_number_id = "923588530831063";

    $url = "https://graph.facebook.com/v22.0/$phone_number_id/messages";

    $data = [
        "messaging_product" => "whatsapp",
        "to" => "91".$mobile,
        "type" => "template",
        "template" => [
            "name" => "bbm_forgot_password",
            "language" => [
                "code" => "en_US"
            ],
            "components" => [
                [
                    "type" => "body",
                    "parameters" => [
                        [
                            "type" => "text",
                            "text" => (string)$otp
                        ]
                    ]
                ],
                [
                    "type" => "button",
                    "sub_type" => "url",
                    "index" => "0",
                    "parameters" => [
                        [
                            "type" => "text",
                            "text" => (string)$otp
                        ]
                    ]
                ]
            ]
        ]
    ];


    $headers = [
        "Authorization: Bearer $token",
        "Content-Type: application/json"
    ];

    $ch = curl_init($url);

    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    $response = curl_exec($ch);

    curl_close($ch);

    return $response;
}

try {

    require __DIR__ . '/../../app/config/database.php';

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $input = json_decode(file_get_contents("php://input"), true);

    $mobile = $input['mobile'] ?? '';

    if (empty($mobile)) {
        echo json_encode([
            'success' => false,
            'message' => 'Mobile number required'
        ]);
        exit();
    }

    if (!preg_match('/^[0-9]{10}$/', $mobile)) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid mobile number'
        ]);
        exit();
    }

    $stmt = $pdo->prepare("
        SELECT user_id
        FROM artist_profiles
        WHERE whatsapp_number = ?
    ");
    $stmt->execute([$mobile]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode([
            'success' => false,
            'message' => 'Mobile number not registered'
        ]);
        exit();
    }

    $otp = rand(100000, 999999);

    $stmt = $pdo->prepare("
        INSERT INTO password_resets (mobile, otp, expires_at)
        VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 5 MINUTE))
    ");
    $stmt->execute([$mobile, $otp]);

    $whatsappResponse = sendWhatsAppOTP($mobile, $otp);

    echo json_encode([
        'success' => true,
        'message' => 'OTP sent successfully',
        'whatsapp_response' => $whatsappResponse
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'message' => 'Server error',
        'error' => $e->getMessage()
    ]);
}

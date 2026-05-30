<?php
if (!function_exists('send_email_notification')) {
function send_email_notification($userData) {
    try {
        $to = 'rep123hel@gmail.com'; // Admin email
        $isPaymentSuccess = ($userData['notification_type'] ?? '') === 'payment_success';
        $subject = $isPaymentSuccess
            ? 'Payment Successful - BridalBooker Machine'
            : 'New Artist Registration - BridalBooker Machine';

        $escape = function ($value) {
            return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
        };

        $username   = $escape($userData['username'] ?? 'N/A');
        $whatsapp   = $escape($userData['whatsapp'] ?? 'N/A');
        $business   = $escape($userData['business_name'] ?? 'N/A');
        $contact    = $escape($userData['contact_person'] ?? 'N/A');
        $instagram  = $escape($userData['instagram'] ?? 'N/A');
        $category   = $escape($userData['category'] ?? 'N/A');
        $couponRaw  = $userData['coupon_code'] ?? '';
        $coupon     = $escape($couponRaw !== '' && $couponRaw !== null ? $couponRaw : 'Not Applied');
        $title      = $isPaymentSuccess ? 'Payment Successful' : 'New Artist Registered';
        $accountStatus = $escape(
            $userData['account_status'] ?? ($isPaymentSuccess ? 'Active' : 'Inactive (Level 5)')
        );

        $paymentDetails = '';
        if ($isPaymentSuccess) {
            $planName = $escape($userData['plan_name'] ?? 'N/A');
            $amountPaid = $escape($userData['amount_paid'] ?? 'N/A');
            $paymentId = $escape($userData['payment_id'] ?? 'N/A');
            $orderId = $escape($userData['order_id'] ?? 'N/A');

            $paymentDetails = "
                    <div class='field'>
                        <div class='label'>Plan</div>
                        <div class='value'>{$planName}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Amount Paid</div>
                        <div class='value'>{$amountPaid}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Razorpay Payment ID</div>
                        <div class='value'>{$paymentId}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Razorpay Order ID</div>
                        <div class='value'>{$orderId}</div>
                    </div>";
        }

        $message = "
        <html>
        <head>
            <title>{$title}</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                }
                .container {
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 20px;
                    text-align: center;
                    border-radius: 10px 10px 0 0;
                }
                .content {
                    background: #f9f9f9;
                    padding: 20px;
                    border-radius: 0 0 10px 10px;
                }
                .field {
                    margin-bottom: 12px;
                }
                .label {
                    font-weight: bold;
                    color: #555;
                }
                .value {
                    background: #ffffff;
                    padding: 8px;
                    border-radius: 5px;
                    margin-top: 4px;
                }
            </style>
        </head>
        <body>
            <div class='container'>
                <div class='header'>
                    <h2>{$title}</h2>
                    <p>BridalBooker Machine</p>
                </div>
                <div class='content'>
                    <div class='field'>
                        <div class='label'>Login ID (Username)</div>
                        <div class='value'>{$username}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Business Name</div>
                        <div class='value'>{$business}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Contact Person</div>
                        <div class='value'>{$contact}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>WhatsApp Number</div>
                        <div class='value'>+91 {$whatsapp}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Instagram Handle</div>
                        <div class='value'>{$instagram}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Category</div>
                        <div class='value'>{$category}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Coupon Code</div>
                        <div class='value'>{$coupon}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Account Status</div>
                        <div class='value'>{$accountStatus}</div>
                    </div>
                    {$paymentDetails}
                </div>
            </div>
        </body>
        </html>
        ";

        $headers  = "MIME-Version: 1.0\r\n";
        $headers .= "Content-type:text/html;charset=UTF-8\r\n";
        $headers .= "From: BridalBooker Machine <noreply@bridalbookermachine.com>\r\n";
        $headers .= "Reply-To: noreply@bridalbookermachine.com\r\n";

        $mail_sent = mail($to, $subject, $message, $headers);

        if ($mail_sent) {
            error_log("Email notification sent successfully for WhatsApp: " . $whatsapp);
        } else {
            error_log("Failed to send email notification for WhatsApp: " . $whatsapp);
        }
    } catch (Exception $e) {
        error_log("Email Error: " . $e->getMessage());
    }
}
}

if (defined('BBM_REGISTER_HELPERS_ONLY')) {
    return;
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

$input = file_get_contents('php://input');
$data = json_decode($input, true);
if (!$data) $data = $_POST;

// Extract fields
$whatsapp   = trim($data['whatsapp'] ?? '');
$password   = $whatsapp; // Password is WhatsApp number initially during registration
$business   = trim($data['business_name'] ?? '');
$contact    = trim($data['contact_person'] ?? '');
$instagram  = trim($data['instagram'] ?? '');
$category   = trim($data['category'] ?? '');
$coupon     = trim($data['coupon_code'] ?? '');

$errors = [];

// Validate WhatsApp
if (!preg_match('/^[0-9]{10}$/', $whatsapp)) {
    $errors['whatsapp'] = "WhatsApp number must be exactly 10 digits.";
}

// Validate other required fields
if (empty($business))  $errors['business_name'] = "Business name is required.";
if (empty($contact))   $errors['contact_person'] = "Contact person name is required.";
if (empty($instagram)) $errors['instagram'] = "Instagram handle is required.";

try {
    $config_file = __DIR__ . '/../app/config/database.php';
    if (!file_exists($config_file)) throw new Exception('Database config not found');
    include $config_file;

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->exec("SET time_zone = '+05:30'");

    // Ensure artist_profiles has `category` and `coupon_code` columns (add if missing)
    $colsToEnsure = [
        'category' => "VARCHAR(255) NOT NULL DEFAULT ''",
        'coupon_code' => "VARCHAR(100) DEFAULT NULL"
    ];
    foreach ($colsToEnsure as $col => $def) {
        $colStmt = $pdo->prepare("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?");
        $colStmt->execute([DB_NAME, 'artist_profiles', $col]);
        if ($colStmt->fetchColumn() == 0) {
            $pdo->exec("ALTER TABLE artist_profiles ADD COLUMN `$col` $def");
        }
    }

    // Check duplicates (WhatsApp number must not be registered as a username or in artist profiles)
    if (empty($errors)) {
        $stmt = $pdo->prepare("
            SELECT COUNT(*) FROM users WHERE username = ?
            UNION ALL
            SELECT COUNT(*) FROM artist_profiles WHERE whatsapp_number = ?
        ");
        $stmt->execute([$whatsapp, $whatsapp]);
        $counts = $stmt->fetchAll(PDO::FETCH_COLUMN);
        if (array_sum($counts) > 0) {
            $errors['whatsapp'] = "This WhatsApp number is already registered.";
        }
    }

    if (!empty($errors)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'errors' => $errors]);
        exit();
    }

    $password_hash = password_hash($password, PASSWORD_DEFAULT);

    $pdo->beginTransaction();

    // Generate unique LPZ user ID
    $lpzStmt = $pdo->prepare("SELECT username FROM users WHERE username LIKE 'LPZ%' ORDER BY username DESC LIMIT 1");
    $lpzStmt->execute();
    $lastLpz = $lpzStmt->fetchColumn();
    if ($lastLpz) {
        $lastNum = (int)substr($lastLpz, 3);
        $nextNum = $lastNum + 1;
    } else {
        // Fallback: count all users with role = 'artist' to bridge existing database members
        $countStmt = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'artist'");
        $artistCount = (int)$countStmt->fetchColumn();
        $nextNum = $artistCount + 1;
    }
    $newUsername = 'LPZ' . str_pad($nextNum, 4, '0', STR_PAD_LEFT);

    $stmt = $pdo->prepare("
        INSERT INTO users (username, password_hash, role, status, created_at, level)
        VALUES (?, ?, 'artist', 'inactive', NOW(), 5)
    ");
    $stmt->execute([$newUsername, $password_hash]);
    
    $user_id = $pdo->lastInsertId();

    // Generate an unguessable API token for this session.
    $token = bin2hex(random_bytes(32));
    $stmt = $pdo->prepare("
        UPDATE users 
        SET api_token = ?, token_expires = DATE_ADD(NOW(), INTERVAL 30 DAY) 
        WHERE id = ?
    ");
    $stmt->execute([$token, $user_id]);

    // Insert into artist_profiles with level = 5 (store category & coupon_code)
    $stmt = $pdo->prepare("
        INSERT INTO artist_profiles (user_id, contact_person_name, business_name, instagram_handle, whatsapp_number, category, coupon_code, is_active, artist_level, created_at, updated_at) 
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, '5', NOW(), NOW())
    ");
    $couponParam = $coupon !== '' ? $coupon : null;
    $stmt->execute([$user_id, $contact, $business, $instagram, $whatsapp, $category, $couponParam]);

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Registration successful',
        'token' => $token,
        'user' => [
            'id' => (int)$user_id,
            'username' => $newUsername,
            'role' => 'artist',
            'status' => 'inactive',
            'business_name' => $business,
            'level' => (int)5       
        ]
    ]);

    // Send email notification to admin with generated username
    $data['username'] = $newUsername;
    send_email_notification($data);

} catch (Exception $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    error_log('BBM registration failure: ' . $e->getMessage());
    echo json_encode(['error' => 'Registration failed. Please try again.']);
}
?>

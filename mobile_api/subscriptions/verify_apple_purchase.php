<?php
/**
 * Verify a StoreKit 2 transaction and activate the matching subscription plan.
 *
 * The iOS app sends the signed transaction (JWS) returned by StoreKit in
 * PurchaseDetails.verificationData.serverVerificationData. This endpoint
 * verifies the JWS signature and certificate chain against Apple's pinned
 * root certificate (no App Store Server API key required), then writes the
 * same rows that confirm_razorpay_payment.php writes for Android/web.
 *
 * Product type in App Store Connect must be NON-RENEWING SUBSCRIPTION.
 */

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
    echo json_encode(['success' => false, 'error_code' => 'METHOD_NOT_ALLOWED', 'message' => 'Method not allowed']);
    exit();
}

date_default_timezone_set('Asia/Kolkata');

if (!defined('BBM_REGISTER_HELPERS_ONLY')) {
    define('BBM_REGISTER_HELPERS_ONLY', true);
}
require_once __DIR__ . '/../register.php';

// ---------------------------------------------------------------------------
// Apple configuration
// ---------------------------------------------------------------------------

define('APPLE_IAP_BUNDLE_ID', 'com.lwv.bridalbookermachine');
define('APPLE_IAP_ALLOWED_ENVIRONMENT', getenv('APPLE_IAP_ALLOWED_ENVIRONMENT') ?: 'Production');
define('APPLE_ROOT_CA_SHA256', '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179');

// Apple Root CA - G3 (public certificate, valid until 2039-04-30).
define('APPLE_ROOT_CA_PEM', <<<'PEM'
-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9v
dCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UE
CgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2
WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmlj
YXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqG
SM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxE
tX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNC
MEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0P
AQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3m
eoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkL
F1vLUagM6BgD56KyKA==
-----END CERTIFICATE-----
PEM);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function apple_b64url_decode(string $value): string
{
    $value = strtr($value, '-_', '+/');
    $padding = strlen($value) % 4;
    if ($padding > 0) {
        $value .= str_repeat('=', 4 - $padding);
    }

    $decoded = base64_decode($value, true);
    if ($decoded === false) {
        throw new RuntimeException('MALFORMED_JWS');
    }

    return $decoded;
}

function apple_der_to_pem(string $der): string
{
    return "-----BEGIN CERTIFICATE-----\n"
        . chunk_split(base64_encode($der), 64, "\n")
        . "-----END CERTIFICATE-----\n";
}

function apple_normalize_fingerprint(string $fingerprint): string
{
    return strtolower(str_replace(':', '', trim($fingerprint)));
}

function apple_der_length(int $length): string
{
    if ($length < 0x80) {
        return chr($length);
    }

    $bytes = ltrim(pack('N', $length), "\x00");

    return chr(0x80 | strlen($bytes)) . $bytes;
}

/**
 * OpenSSL expects a DER-encoded ECDSA signature, while JWS uses the raw
 * fixed-width R || S form.
 */
function apple_ecdsa_raw_to_der(string $signature): string
{
    $length = strlen($signature);
    if ($length % 2 !== 0) {
        throw new RuntimeException('MALFORMED_SIGNATURE');
    }

    $half = intdiv($length, 2);
    $r = ltrim(substr($signature, 0, $half), "\x00");
    $s = ltrim(substr($signature, $half), "\x00");

    if ($r === '') {
        $r = "\x00";
    }
    if ($s === '') {
        $s = "\x00";
    }
    if (ord($r[0]) & 0x80) {
        $r = "\x00" . $r;
    }
    if (ord($s[0]) & 0x80) {
        $s = "\x00" . $s;
    }

    $sequence = "\x02" . apple_der_length(strlen($r)) . $r
        . "\x02" . apple_der_length(strlen($s)) . $s;

    return "\x30" . apple_der_length(strlen($sequence)) . $sequence;
}

/**
 * Verify a StoreKit JWS and return its decoded payload.
 *
 * @throws RuntimeException with a stable error code
 */
function apple_verify_jws(string $jws): array
{
    $parts = explode('.', $jws);
    if (count($parts) !== 3) {
        throw new RuntimeException('MALFORMED_JWS');
    }

    [$encodedHeader, $encodedPayload, $encodedSignature] = $parts;

    $header = json_decode(apple_b64url_decode($encodedHeader), true);
    $payload = json_decode(apple_b64url_decode($encodedPayload), true);
    if (!is_array($header) || !is_array($payload)) {
        throw new RuntimeException('MALFORMED_JWS');
    }

    $algorithm = strtoupper((string)($header['alg'] ?? ''));
    $algorithms = [
        'ES256' => OPENSSL_ALGO_SHA256,
        'ES384' => OPENSSL_ALGO_SHA384,
        'ES512' => OPENSSL_ALGO_SHA512,
    ];
    if (!isset($algorithms[$algorithm])) {
        throw new RuntimeException('UNSUPPORTED_JWS_ALGORITHM');
    }

    $chain = $header['x5c'] ?? null;
    if (!is_array($chain) || count($chain) < 2) {
        throw new RuntimeException('MISSING_CERTIFICATE_CHAIN');
    }

    $certificates = [];
    foreach ($chain as $index => $entry) {
        if (!is_string($entry) || $entry === '') {
            throw new RuntimeException('MALFORMED_CERTIFICATE_CHAIN');
        }
        $der = base64_decode($entry, true);
        if ($der === false) {
            throw new RuntimeException('MALFORMED_CERTIFICATE_CHAIN');
        }
        $pem = apple_der_to_pem($der);
        $parsed = openssl_x509_parse($pem);
        if ($parsed === false) {
            throw new RuntimeException('MALFORMED_CERTIFICATE_CHAIN');
        }
        $certificates[$index] = [
            'pem' => $pem,
            'parsed' => $parsed,
        ];
    }

    $now = time();
    foreach ($certificates as $certificate) {
        if (($certificate['parsed']['validFrom_time_t'] ?? 0) > $now
            || ($certificate['parsed']['validTo_time_t'] ?? 0) < $now) {
            throw new RuntimeException('CERTIFICATE_EXPIRED');
        }
    }

    // Verify each certificate was signed by the next certificate in the chain.
    $certificateCount = count($certificates);
    for ($i = 0; $i < $certificateCount - 1; $i++) {
        if (openssl_x509_verify($certificates[$i]['pem'], $certificates[$i + 1]['pem']) !== 1) {
            throw new RuntimeException('INVALID_CERTIFICATE_CHAIN');
        }
    }

    // The last certificate must chain to Apple's pinned root.
    $lastCertificate = $certificates[$certificateCount - 1]['pem'];
    $lastFingerprint = apple_normalize_fingerprint(
        (string)openssl_x509_fingerprint($lastCertificate, 'sha256')
    );

    if (!hash_equals(APPLE_ROOT_CA_SHA256, $lastFingerprint)) {
        if (openssl_x509_verify($lastCertificate, APPLE_ROOT_CA_PEM) !== 1) {
            throw new RuntimeException('UNTRUSTED_CERTIFICATE_CHAIN');
        }
    }

    $publicKey = openssl_pkey_get_public($certificates[0]['pem']);
    if ($publicKey === false) {
        throw new RuntimeException('INVALID_CERTIFICATE_CHAIN');
    }

    $signature = apple_b64url_decode($encodedSignature);
    $verified = openssl_verify(
        $encodedHeader . '.' . $encodedPayload,
        apple_ecdsa_raw_to_der($signature),
        $publicKey,
        $algorithms[$algorithm]
    );

    if ($verified !== 1) {
        throw new RuntimeException('INVALID_JWS_SIGNATURE');
    }

    return $payload;
}

function apple_date_from_milliseconds($milliseconds): ?string
{
    if (!is_numeric($milliseconds)) {
        return null;
    }

    return date('Y-m-d H:i:s', (int)floor(((int)$milliseconds) / 1000));
}

// ---------------------------------------------------------------------------
// Request handling
// ---------------------------------------------------------------------------

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = $_POST;
}

$apiToken = trim((string)($input['token'] ?? ''));
if ($apiToken === '') {
    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (stripos($authorization, 'Bearer ') === 0) {
        $apiToken = trim(substr($authorization, 7));
    }
}

$signedTransaction = trim((string)($input['signed_transaction_info'] ?? ''));
$requestedProductId = trim((string)($input['product_id'] ?? ''));

if ($apiToken === '') {
    http_response_code(401);
    echo json_encode(['success' => false, 'error_code' => 'AUTH_REQUIRED', 'message' => 'Authentication token required']);
    exit();
}

if ($signedTransaction === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error_code' => 'MISSING_TRANSACTION', 'message' => 'Missing signed transaction']);
    exit();
}

try {
    require __DIR__ . '/../app/config/database.php';

    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $pdo->exec("SET time_zone = '+05:30'");

    // Authenticate the account that will receive the entitlement.
    $stmt = $pdo->prepare("
        SELECT u.id, u.username, u.role, u.status, u.level
        FROM users u
        WHERE u.api_token = ? AND u.token_expires > NOW()
        LIMIT 1
    ");
    $stmt->execute([$apiToken]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['success' => false, 'error_code' => 'INVALID_TOKEN', 'message' => 'Invalid or expired token']);
        exit();
    }
    if (($user['role'] ?? '') !== 'artist') {
        http_response_code(403);
        echo json_encode(['success' => false, 'error_code' => 'ACCOUNT_NOT_ELIGIBLE', 'message' => 'This account cannot purchase an artist plan']);
        exit();
    }

    $userId = (int)$user['id'];

    // ---- Verify the StoreKit transaction ----
    try {
        $payload = apple_verify_jws($signedTransaction);
    } catch (RuntimeException $verificationError) {
        error_log('[APPLE_IAP] JWS verification failed: ' . $verificationError->getMessage());
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error_code' => $verificationError->getMessage(),
            'message' => 'Apple transaction could not be verified',
        ]);
        exit();
    }

    $bundleId = (string)($payload['bundleId'] ?? '');
    $productId = (string)($payload['productId'] ?? '');
    $transactionId = (string)($payload['transactionId'] ?? '');
    $originalTransactionId = (string)($payload['originalTransactionId'] ?? '');
    $transactionType = (string)($payload['type'] ?? '');
    $environment = (string)($payload['environment'] ?? '');
    $revocationDate = $payload['revocationDate'] ?? null;

    if ($bundleId !== APPLE_IAP_BUNDLE_ID) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error_code' => 'BUNDLE_MISMATCH', 'message' => 'Transaction belongs to another app']);
        exit();
    }

    if ($productId === '' || $transactionId === '' || $originalTransactionId === '') {
        http_response_code(400);
        echo json_encode(['success' => false, 'error_code' => 'INCOMPLETE_TRANSACTION', 'message' => 'Transaction is missing required fields']);
        exit();
    }

    if ($requestedProductId !== '' && $requestedProductId !== $productId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error_code' => 'PRODUCT_MISMATCH', 'message' => 'Product does not match the transaction']);
        exit();
    }

    if ($revocationDate !== null && $revocationDate !== '') {
        http_response_code(409);
        echo json_encode(['success' => false, 'error_code' => 'TRANSACTION_REVOKED', 'message' => 'This purchase was refunded or revoked']);
        exit();
    }

    if ($transactionType !== 'Non-Renewing Subscription') {
        http_response_code(400);
        echo json_encode(['success' => false, 'error_code' => 'INVALID_PRODUCT_TYPE', 'message' => 'Unexpected Apple product type']);
        exit();
    }

    if ($environment !== APPLE_IAP_ALLOWED_ENVIRONMENT) {
        http_response_code(403);
        echo json_encode(['success' => false, 'error_code' => 'INVALID_ENVIRONMENT', 'message' => 'Transaction environment is not enabled']);
        exit();
    }

    // ---- Map the Apple product to a plan ----
    $stmt = $pdo->prepare("
        SELECT id, slug, name, duration_days, artist_level, price_integer, currency
        FROM subscription_plans
        WHERE apple_product_id = ? AND active = 1
        LIMIT 1
    ");
    $stmt->execute([$productId]);
    $plan = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$plan) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error_code' => 'PLAN_NOT_FOUND', 'message' => 'No plan is mapped to this Apple product']);
        exit();
    }

    $planId = (int)$plan['id'];
    $durationDays = (int)$plan['duration_days'];
    $artistLevel = (int)$plan['artist_level'];

    if ($durationDays <= 0 || $artistLevel <= 0) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error_code' => 'INVALID_PLAN_MAPPING', 'message' => 'Plan configuration is incomplete']);
        exit();
    }

    $purchaseDate = apple_date_from_milliseconds($payload['purchaseDate'] ?? null);
    $purchaseTimestamp = $purchaseDate === null ? false : strtotime($purchaseDate);
    if ($purchaseTimestamp === false || $purchaseTimestamp > time() + 300) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error_code' => 'INVALID_PURCHASE_DATE', 'message' => 'Transaction has an invalid purchase date']);
        exit();
    }
    if (strtotime('+' . $durationDays . ' days', $purchaseTimestamp) <= time()) {
        http_response_code(409);
        echo json_encode(['success' => false, 'error_code' => 'TRANSACTION_EXPIRED', 'message' => 'This fixed-term purchase has expired']);
        exit();
    }

    // ---- Idempotency / replay protection ----
    $stmt = $pdo->prepare("
        SELECT id, user_id, status
        FROM subscription_transactions
        WHERE apple_transaction_id = ?
        LIMIT 1
    ");
    $stmt->execute([$transactionId]);
    $existingTransaction = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existingTransaction) {
        if ((int)$existingTransaction['user_id'] !== $userId) {
            http_response_code(409);
            echo json_encode([
                'success' => false,
                'error_code' => 'TRANSACTION_ALREADY_LINKED',
                'message' => 'This purchase is already linked to another account',
            ]);
            exit();
        }

        // Already processed for this account: return the current state instead
        // of extending the subscription twice.
        $stmt = $pdo->prepare("
            SELECT plan_name, start_date, end_date, status, max_claim_limit
            FROM subscription_history
            WHERE payment_id = ? AND user_id = ?
            ORDER BY start_date DESC, id DESC
            LIMIT 1
        ");
        $stmt->execute([$transactionId, $userId]);
        $subscription = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
        $hasActiveSubscription = $subscription
            && $subscription['status'] === 'active'
            && strtotime((string)$subscription['end_date']) > time();

        echo json_encode([
            'success' => true,
            'already_processed' => true,
            'message' => 'Purchase already applied to this account',
            'has_active_subscription' => (bool)$hasActiveSubscription,
            'plan' => [
                'id' => $planId,
                'slug' => $plan['slug'],
                'name' => $plan['name'],
                'duration_days' => $durationDays,
                'artist_level' => $artistLevel,
            ],
            'subscription' => $subscription,
            'level' => $hasActiveSubscription ? $artistLevel : 5,
            'status' => $hasActiveSubscription ? 'active' : 'inactive',
        ]);
        exit();
    }

    // ---- Fetch the plan claim limit (same source as the Razorpay flow) ----
    $limitStmt = $pdo->prepare("
        SELECT setting_value
        FROM system_settings
        WHERE setting_key = 'max_total_claims' AND user_level = ?
        LIMIT 1
    ");
    $limitStmt->execute([$artistLevel]);
    $maxClaimLimit = (int)($limitStmt->fetchColumn() ?: 0);

    $amountPaise = (int)($plan['price_integer'] ?? 0);
    $currency = (string)($plan['currency'] ?: 'INR');
    $pdo->beginTransaction();

    try {
        // Insert the StoreKit transaction first. The unique index on
        // apple_transaction_id makes concurrent duplicate submissions fail.
        $stmt = $pdo->prepare("
            INSERT INTO subscription_transactions
                (user_id, plan_id, provider, apple_transaction_id,
                 apple_original_transaction_id, apple_product_id,
                 apple_environment, apple_purchase_date,
                 amount, currency, status)
            VALUES (?, ?, 'apple', ?, ?, ?, ?, ?, ?, ?, 'success')
        ");
        $stmt->execute([
            $userId,
            $planId,
            $transactionId,
            $originalTransactionId,
            $productId,
            $environment,
            $purchaseDate,
            $amountPaise,
            $currency,
        ]);

        // Expire any previous active subscription, exactly like Razorpay.
        $pdo->prepare("
            UPDATE subscription_history
            SET status = 'expired'
            WHERE user_id = ? AND status = 'active'
        ")->execute([$userId]);

        $stmt = $pdo->prepare("
            INSERT INTO subscription_history
                (user_id, plan_id, plan_name, subscription_type,
                 start_date, end_date, total_leads_claimed,
                 payment_id, order_id, amount_paid, currency, status,
                 payment_mode, max_claim_limit)
            VALUES
                (?, ?, ?, 'paid', ?, DATE_ADD(?, INTERVAL ? DAY), 0,
                 ?, ?, ?, ?, 'active', 'apple_iap', ?)
        ");
        $stmt->execute([
            $userId,
            $planId,
            $plan['name'],
            $purchaseDate,
            $purchaseDate,
            $durationDays,
            $transactionId,
            $originalTransactionId,
            $amountPaise / 100,
            $currency,
            $maxClaimLimit,
        ]);

        $pdo->prepare("
            UPDATE artist_profiles
            SET artist_level = ?, is_active = 1
            WHERE user_id = ?
        ")->execute([$artistLevel, $userId]);

        $pdo->prepare("
            UPDATE users
            SET status = 'active', level = ?
            WHERE id = ?
        ")->execute([$artistLevel, $userId]);

        $stmt = $pdo->prepare("
            SELECT start_date, end_date
            FROM subscription_history
            WHERE user_id = ?
            ORDER BY start_date DESC, id DESC
            LIMIT 1
        ");
        $stmt->execute([$userId]);
        $subscriptionWindow = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];

        $pdo->commit();
    } catch (Throwable $transactionError) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        // A concurrent request may have inserted the same transaction.
        $stmt = $pdo->prepare("
            SELECT user_id FROM subscription_transactions
            WHERE apple_transaction_id = ? LIMIT 1
        ");
        $stmt->execute([$transactionId]);
        $race = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($race && (int)$race['user_id'] === $userId) {
            $stmt = $pdo->prepare("
                SELECT plan_name, start_date, end_date, status, max_claim_limit
                FROM subscription_history
                WHERE payment_id = ? AND user_id = ?
                ORDER BY start_date DESC, id DESC
                LIMIT 1
            ");
            $stmt->execute([$transactionId, $userId]);
            $subscription = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
            $hasActiveSubscription = $subscription
                && $subscription['status'] === 'active'
                && strtotime((string)$subscription['end_date']) > time();

            echo json_encode([
                'success' => true,
                'already_processed' => true,
                'message' => 'Purchase already applied to this account',
                'has_active_subscription' => (bool)$hasActiveSubscription,
                'plan' => [
                    'id' => $planId,
                    'slug' => $plan['slug'],
                    'name' => $plan['name'],
                    'duration_days' => $durationDays,
                    'artist_level' => $artistLevel,
                ],
                'subscription' => $subscription,
                'level' => $hasActiveSubscription ? $artistLevel : 5,
                'status' => $hasActiveSubscription ? 'active' : 'inactive',
            ]);
            exit();
        }

        if ($race) {
            http_response_code(409);
            echo json_encode([
                'success' => false,
                'error_code' => 'TRANSACTION_ALREADY_LINKED',
                'message' => 'This purchase is already linked to another account',
            ]);
            exit();
        }

        throw $transactionError;
    }

    // ---- Confirmation email (same helper as Razorpay) ----
    try {
        $stmt = $pdo->prepare("
            SELECT u.username, ap.business_name, ap.contact_person_name,
                   ap.whatsapp_number, ap.instagram_handle, ap.category, ap.coupon_code
            FROM users u
            LEFT JOIN artist_profiles ap ON ap.user_id = u.id
            WHERE u.id = ?
            LIMIT 1
        ");
        $stmt->execute([$userId]);
        $profile = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];

        send_email_notification([
            'notification_type' => 'payment_success',
            'whatsapp' => $profile['whatsapp_number'] ?? '',
            'username' => $profile['username'] ?? $user['username'],
            'business_name' => $profile['business_name'] ?? 'N/A',
            'contact_person' => $profile['contact_person_name'] ?? 'N/A',
            'instagram' => $profile['instagram_handle'] ?? 'N/A',
            'category' => $profile['category'] ?? 'N/A',
            'coupon_code' => $profile['coupon_code'] ?? '',
            'account_status' => 'Active (Level ' . $artistLevel . ')',
            'plan_name' => $plan['name'],
            'amount_paid' => $currency . ' ' . number_format($amountPaise / 100, 2),
            'payment_id' => $transactionId,
            'order_id' => $originalTransactionId,
        ]);
    } catch (Throwable $notificationError) {
        error_log('[APPLE_IAP] Email notification failed: ' . $notificationError->getMessage());
    }

    echo json_encode([
        'success' => true,
        'has_active_subscription' => true,
        'already_processed' => false,
        'message' => 'Subscription activated',
        'plan' => [
            'id' => $planId,
            'slug' => $plan['slug'],
            'name' => $plan['name'],
            'duration_days' => $durationDays,
            'artist_level' => $artistLevel,
        ],
        'subscription' => [
            'plan_name' => $plan['name'],
            'status' => 'active',
            'start_date' => $subscriptionWindow['start_date'] ?? null,
            'end_date' => $subscriptionWindow['end_date'] ?? null,
        ],
        'level' => $artistLevel,
        'status' => 'active',
    ]);
} catch (Throwable $e) {
    error_log('[APPLE_IAP] ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error_code' => 'SERVER_ERROR',
        'message' => 'Could not activate the subscription. Please try again.',
    ]);
}

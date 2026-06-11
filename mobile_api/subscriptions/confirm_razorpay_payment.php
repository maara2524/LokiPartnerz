<?php

header("Content-Type: application/json");
require __DIR__ . "/../../app/config/database.php";
if (!defined('BBM_REGISTER_HELPERS_ONLY')) {
    define('BBM_REGISTER_HELPERS_ONLY', true);
}
require_once __DIR__ . "/../register.php";

define("RAZORPAY_SECRET", "CgGKEpIYqs5xmMyUzaM8pKnc");

// Toggle debug mode
$DEBUG_MODE = true;
$debug = [];

function log_debug(&$debug, $msg) {
    global $DEBUG_MODE;
    if ($DEBUG_MODE) {
        $debug[] = $msg;
        error_log("[PAYMENT] " . $msg);
    }
}

try {

    $input = json_decode(file_get_contents("php://input"), true);
    log_debug($debug, "Incoming: " . json_encode($input));

    $userId    = $input["user_id"] ?? null;
    $planId    = $input["plan_id"] ?? null;
    $paymentId = $input["razorpay_payment_id"] ?? null;
    $orderId   = $input["razorpay_order_id"] ?? null;
    $signature = $input["razorpay_signature"] ?? null;

    // Validation
    if (!$paymentId || !$orderId || !$signature || !$userId) {
        echo json_encode([
            "success" => false,
            "error_code" => "MISSING_FIELDS",
            "message" => "Required fields missing",
            "debug" => $debug
        ]);
        exit();
    }

    // Signature Verification
    $generated = hash_hmac(
        "sha256",
        $orderId . "|" . $paymentId,
        RAZORPAY_SECRET
    );

    log_debug($debug, "Generated signature: $generated");
    log_debug($debug, "Received signature: $signature");

    if (!hash_equals($generated, $signature)) {
        echo json_encode([
            "success" => false,
            "error_code" => "INVALID_SIGNATURE",
            "message" => "Payment verification failed",
            "debug" => $debug
        ]);
        exit();
    }

    log_debug($debug, "Signature verified");

    // DB Connection
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->beginTransaction();

    // Update transaction
    $stmt = $pdo->prepare("
        UPDATE subscription_transactions
        SET razorpay_payment_id = ?, status = 'success'
        WHERE razorpay_order_id = ? AND status = 'pending'
    ");
    $stmt->execute([$paymentId, $orderId]);

    log_debug($debug, "Transaction rows updated: " . $stmt->rowCount());

    if ($stmt->rowCount() === 0) {
        throw new Exception("ORDER_ALREADY_PROCESSED");
    }

    // Fetch the plan from the stored transaction instead of trusting
    // the client payload. This keeps level mapping aligned with the
    // actual order that was created for the user.
    $stmt = $pdo->prepare("
        SELECT
            sp.id,
            sp.slug,
            sp.name,
            sp.duration_days,
            sp.artist_level,
            st.amount,
            st.currency,
            u.username,
            ap.business_name,
            ap.contact_person_name,
            ap.whatsapp_number,
            ap.instagram_handle,
            ap.category,
            ap.coupon_code
        FROM subscription_transactions st
        INNER JOIN subscription_plans sp ON sp.id = st.plan_id
        INNER JOIN users u ON u.id = st.user_id
        LEFT JOIN artist_profiles ap ON ap.user_id = st.user_id
        WHERE st.razorpay_order_id = ?
          AND st.user_id = ?
        LIMIT 1
    ");
    $stmt->execute([$orderId, $userId]);
    $plan = $stmt->fetch(PDO::FETCH_ASSOC);

    log_debug($debug, "Plan data: " . json_encode($plan));
    log_debug($debug, "Client plan_id: " . json_encode($planId));

    if (!$plan) {
        throw new Exception("INVALID_PLAN");
    }

    $resolvedPlanId = (int)$plan['id'];
    $durationDays = (int)$plan['duration_days'];

    // Expire old
    $pdo->prepare("
        UPDATE subscription_history
        SET status = 'expired'
        WHERE user_id = ? AND status = 'active'
    ")->execute([$userId]);

    log_debug($debug, "Old subscriptions expired");

    // Insert new subscription
    $stmt = $pdo->prepare("
        INSERT INTO subscription_history
        (
            user_id, plan_id, plan_name, subscription_type,
            start_date, end_date, total_leads_claimed,
            amount_paid, payment_id, order_id, status
        )
        SELECT
            :user_id, :plan_id, sp.name, 'paid',
            NOW(),
            DATE_ADD(NOW(), INTERVAL :duration DAY),
            0,
            st.amount,
            :payment_id,
            :order_id,
            'active'
        FROM subscription_transactions st
        JOIN subscription_plans sp ON sp.id = st.plan_id
        WHERE st.razorpay_order_id = :order_id
        LIMIT 1
    ");

    $stmt->execute([
        ':duration' => $durationDays,
        ':user_id' => $userId,
        ':plan_id' => $resolvedPlanId,
        ':payment_id' => $paymentId,
        ':order_id' => $orderId
    ]);

    log_debug($debug, "Subscription inserted");

    // Artist level mapping
    if (!isset($plan['artist_level']) || $plan['artist_level'] === '') {
        throw new Exception("INVALID_PLAN_MAPPING");
    }

    $artistLevel = (int)$plan['artist_level'];

    log_debug($debug, "Artist level: " . $artistLevel);

    // Update artist profile
    $pdo->prepare("
        UPDATE artist_profiles
        SET artist_level = ?, is_active = 1
        WHERE user_id = ?
    ")->execute([$artistLevel, $userId]);

    // Update user
    $pdo->prepare("
        UPDATE users
        SET status = 'active', level = ?
        WHERE id = ?
    ")->execute([$artistLevel, $userId]);

    $pdo->commit();

    $currency = $plan['currency'] ?: 'INR';
    $amountPaid = 'N/A';
    if ($plan['amount'] !== null && $plan['amount'] !== '') {
        $amountPaid = $currency . ' ' . number_format(((float)$plan['amount']) / 100, 2);
    }

    send_email_notification([
        'notification_type' => 'payment_success',
        'whatsapp' => $plan['whatsapp_number'],
        'username' => $plan['username'],
        'business_name' => $plan['business_name'] ?: 'N/A',
        'contact_person' => $plan['contact_person_name'] ?: 'N/A',
        'instagram' => $plan['instagram_handle'] ?: 'N/A',
        'category' => $plan['category'] ?: 'N/A',
        'coupon_code' => $plan['coupon_code'] ?: '',
        'account_status' => 'Active (Level ' . $artistLevel . ')',
        'plan_name' => $plan['name'] ?: $plan['slug'],
        'amount_paid' => $amountPaid,
        'payment_id' => $paymentId,
        'order_id' => $orderId
    ]);

    log_debug($debug, "Payment success email notification triggered");

    echo json_encode([
        "success" => true,
        "message" => "Payment successful",
        "debug" => $debug
    ]);

} catch (Exception $e) {

    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    $errorCode = $e->getMessage();

    log_debug($debug, "Exception: " . $errorCode);

    echo json_encode([
        "success" => false,
        "error_code" => $errorCode,
        "message" => match ($errorCode) {
            "ORDER_ALREADY_PROCESSED" => "Order already processed",
            "INVALID_PLAN" => "Invalid subscription plan",
            "INVALID_PLAN_MAPPING" => "Plan mapping error",
            default => "Server error occurred"
        },
        "debug" => $debug
    ]);
}

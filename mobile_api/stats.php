<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/artist_status_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

$periodMode = ($_GET['period'] ?? '') === 'subscription';
$requestedSubscriptionId = null;
if ($periodMode && isset($_GET['subscription_id'])) {
    $requestedSubscriptionId = filter_var($_GET['subscription_id'], FILTER_VALIDATE_INT);
    if ($requestedSubscriptionId === false || $requestedSubscriptionId <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid subscription period']);
        exit();
    }
}

$token = $_GET['token'] ?? '';
if (empty($token)) {
    http_response_code(401);
    echo json_encode(['error' => 'Authentication token required']);
    exit();
}

try {
    // Load DB config
    $config_file = __DIR__ . '/../app/config/database.php';
    if (!file_exists($config_file)) {
        throw new Exception('Database config not found');
    }
    include $config_file;

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    if ($periodMode) {
        $pdo->exec("SET time_zone = '+05:30'");
    }

    // Fetch max_claims_per_day from system_settings (for future stats logic)
    $stmt = $pdo->prepare("SELECT setting_value FROM system_settings WHERE setting_key = 'max_claims_per_day' LIMIT 1");
    $stmt->execute();
    $maxClaimsPerDay = (int)($stmt->fetchColumn() ?: 4);

    // Validate token
    $stmt = $pdo->prepare("
        SELECT id, level, status
        FROM users
        WHERE api_token = ?
          AND token_expires > NOW()
    ");
    $stmt->execute([$token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }
    $userId = (int)$user['id'];
    $userLevel = (int)$user['level'];

    $subscriptionPeriods = [];
    $selectedSubscriptionId = null;
    if ($periodMode) {
        $stmt = $pdo->prepare("
            SELECT sh.id, sh.plan_id, sh.plan_name, sh.start_date,
                   sh.end_date, sh.status, sh.total_leads_claimed,
                   sh.max_claim_limit, sp.artist_level,
                   (sh.status = 'active' AND sh.end_date > NOW()) AS has_active_subscription
            FROM subscription_history sh
            LEFT JOIN subscription_plans sp ON sp.id = sh.plan_id
            WHERE sh.user_id = ?
            ORDER BY has_active_subscription DESC, sh.start_date DESC, sh.id DESC
        ");
        $stmt->execute([$userId]);
        $subscriptionPeriods = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if ($requestedSubscriptionId !== null) {
            foreach ($subscriptionPeriods as $period) {
                if ((int)$period['id'] === $requestedSubscriptionId) {
                    $selectedSubscriptionId = $requestedSubscriptionId;
                    break;
                }
            }

            if ($selectedSubscriptionId === null) {
                http_response_code(404);
                echo json_encode(['error' => 'Subscription period not found']);
                exit();
            }
        } elseif ($subscriptionPeriods) {
            $selectedSubscriptionId = (int)$subscriptionPeriods[0]['id'];
        }

        foreach ($subscriptionPeriods as &$period) {
            $period['id'] = (int)$period['id'];
            $period['total_leads_claimed'] = (int)$period['total_leads_claimed'];
            $period['max_claim_limit'] = (int)$period['max_claim_limit'];
        }
        unset($period);
    }

    // Prefer the current entitlement, but retain the last plan's usage after
    // expiry so the dashboard does not make an artist's history disappear.
    $subscriptionSql = "
        SELECT sh.id, sh.plan_id, sh.plan_name, sh.start_date,
               sh.end_date, sh.status, sh.total_leads_claimed,
               sh.max_claim_limit, sp.artist_level,
               (sh.status = 'active' AND sh.end_date > NOW()) AS has_active_subscription
        FROM subscription_history sh
        LEFT JOIN subscription_plans sp ON sp.id = sh.plan_id
        WHERE sh.user_id = ?
    ";
    $subscriptionParams = [$userId];
    if ($periodMode && $selectedSubscriptionId !== null) {
        $subscriptionSql .= " AND sh.id = ?";
        $subscriptionParams[] = $selectedSubscriptionId;
    }
    $subscriptionSql .= "
        ORDER BY has_active_subscription DESC, sh.start_date DESC, sh.id DESC
        LIMIT 1
    ";
    $stmt = $pdo->prepare($subscriptionSql);
    $stmt->execute($subscriptionParams);
    $subscription = $stmt->fetch(PDO::FETCH_ASSOC);

    $totalAllowedClaims = 0;
    $claimed = 0;
    $balance = 0;
    $hasActiveSubscription = false;

    if ($subscription) {
        $hasActiveSubscription = (bool)$subscription['has_active_subscription'];
        $totalAllowedClaims = (int)($subscription['max_claim_limit'] ?? 0);
        if ($totalAllowedClaims <= 0) {
            $stmt = $pdo->prepare("
                SELECT setting_value
                FROM system_settings
                WHERE setting_key = 'max_total_claims'
                  AND user_level = ?
                LIMIT 1
            ");
            $planLevel = (int)($subscription['artist_level'] ?? 0);
            $stmt->execute([$planLevel > 0 ? $planLevel : $userLevel]);
            $totalAllowedClaims = (int)($stmt->fetchColumn() ?: 0);
        }

        $claimed = (int)$subscription['total_leads_claimed'];
        $balance = max(0, $totalAllowedClaims - $claimed);
    }

    // Keep the dashboard's lead list all-time; only its stat counts use the
    // selected subscription window.
    $stmt = $pdo->prepare("
        SELECT lsh.lead_id,
               lsh.new_status,
               lsh.changed_at,
               l.customer_name,
               l.event_date,
               l.claim_expiry,
               l.is_locked,
               l.claimed_by
        FROM lead_status_history lsh
        INNER JOIN (
            SELECT lead_id, MAX(id) as latest_id
            FROM lead_status_history
            WHERE changed_by = ?
            GROUP BY lead_id
        ) latest
          ON latest.latest_id = lsh.id
         AND lsh.changed_by = ?
        INNER JOIN leads l ON l.id = lsh.lead_id
        ORDER BY lsh.changed_at DESC, lsh.id DESC
    ");
    $stmt->execute([$userId, $userId]);
    $allTimeRows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $periodRows = null;
    if ($periodMode && $subscription) {
        $stmt = $pdo->prepare("
            SELECT lsh.lead_id,
                   lsh.new_status,
                   lsh.changed_at,
                   l.customer_name,
                   l.event_date,
                   l.claim_expiry,
                   l.is_locked,
                   l.claimed_by
            FROM lead_status_history lsh
            INNER JOIN (
                SELECT period_status.lead_id, MAX(period_status.id) AS latest_id
                FROM lead_status_history period_status
                INNER JOIN claimed_leads_log cl
                  ON cl.lead_id = period_status.lead_id
                 AND cl.user_id = ?
                 AND cl.claim_time >= ?
                 AND cl.claim_time < ?
                WHERE period_status.changed_by = ?
                  AND period_status.changed_at >= ?
                  AND period_status.changed_at < ?
                GROUP BY period_status.lead_id
            ) latest
              ON latest.latest_id = lsh.id
             AND lsh.changed_by = ?
            INNER JOIN leads l ON l.id = lsh.lead_id
            ORDER BY lsh.changed_at DESC, lsh.id DESC
        ");
        $stmt->execute([
            $userId,
            $subscription['start_date'],
            $subscription['end_date'],
            $userId,
            $subscription['start_date'],
            $subscription['end_date'],
            $userId,
        ]);
        $periodRows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    $formatLeads = static function (array $rows) use ($pdo, $userId): array {
        $formattedLeads = [];
        foreach ($rows as $lead) {
            $isReleased = 0;
            if ((int)$lead['claimed_by'] !== $userId) {
                $isReleased = 1;
            } elseif ((int)$lead['is_locked'] === 0) {
                $isReleased = 1;
            } elseif ($lead['claim_expiry'] !== null && strtotime($lead['claim_expiry']) < time()) {
                $isReleased = 1;
            }

            $myStatus = normalize_artist_status($lead['new_status'] ?: 'new');
            $displayStatus = get_artist_display_status($pdo, (int)$lead['lead_id'], $userId, $myStatus);

            $formattedLeads[] = [
                'id' => (int)$lead['lead_id'],
                'customer_name' => $lead['customer_name'] ?: 'Unknown',
                'name' => $lead['customer_name'] ?: 'Unknown',
                'event_date' => $lead['event_date'] ?: '',
                'date' => $lead['event_date'] ? date('Y-m-d', strtotime($lead['event_date'])) : '',
                'status' => $displayStatus,
                'my_status' => $myStatus,
                'display_status' => $displayStatus,
                'display_status_label' => artist_status_label($displayStatus),
                'last_updated' => $lead['changed_at'],
                'released' => $isReleased,
            ];
        }
        return $formattedLeads;
    };

    $formattedAllLeads = $formatLeads($allTimeRows);
    $statsRows = $periodRows ?? $allTimeRows;

    // Count statuses from the selected rows.
    $total_claims     = count($statsRows);
    $new_claims       = 0;
    $contacted_claims = 0;
    $booked_claims    = 0;

    foreach ($statsRows as $lead) {
        $myStatus = normalize_artist_status($lead['new_status'] ?: 'new');
        switch (strtolower($myStatus)) {
            case 'new':
                $new_claims++;
                break;
            case 'contacted':
                $contacted_claims++;
                break;
            case 'booked':
                $booked_claims++;
                break;
        }
    }

    $bookedClaims = $booked_claims;

    // Recent = last 10 claimed/updated leads
    $recentLeads = array_slice($formattedAllLeads, 0, 10);

    $response = [
        'success'          => true,
        'total_allowed'    => $totalAllowedClaims,
        'claimed'          => $claimed,
        'balance'          => $balance,
        'has_active_subscription' => $hasActiveSubscription,
        'booked_claims'    => $bookedClaims,
        'total_claims'     => $total_claims,
        'new_claims'       => $new_claims,
        'contacted_claims' => $contacted_claims,
        'recent_leads'     => $recentLeads,
        'claimed_leads'    => $formattedAllLeads
    ];
    if ($periodMode) {
        $response['subscription_periods'] = array_map(static function ($period) {
            return [
                'id' => $period['id'],
                'plan_name' => $period['plan_name'],
                'start_date' => $period['start_date'],
                'end_date' => $period['end_date'],
                'status' => $period['status'],
            ];
        }, $subscriptionPeriods);
        $response['selected_subscription_id'] = $selectedSubscriptionId;
    }
    echo json_encode($response);

} catch (Exception $e) {
    http_response_code(500);
    error_log('BBM stats failure: ' . $e->getMessage());
    echo json_encode(['error' => 'Failed to fetch stats. Please try again.']);
}

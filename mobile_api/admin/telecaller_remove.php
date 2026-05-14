<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);
$input = admin_get_input();

$teamId = (int)($input['id'] ?? 0);
$userId = (int)($input['user_id'] ?? 0);

if ($teamId <= 0) {
    admin_error('Invalid telecaller id');
}

$pdo = admin_get_pdo();
$pdo->beginTransaction();

try {
    $pdo->prepare('UPDATE teams SET active = 0, updated_at = CURRENT_TIMESTAMP WHERE team_id = ?')
        ->execute([$teamId]);

    if ($userId > 0) {
        $pdo->prepare("UPDATE users SET status = 'inactive', updated_at = CURRENT_TIMESTAMP WHERE id = ?")
            ->execute([$userId]);
    }

    $pdo->commit();
    admin_success(['message' => 'Telecaller access revoked']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log('Admin telecaller remove failed: ' . $e->getMessage());
    admin_error('Unable to revoke telecaller access. Please try again.', 500);
}

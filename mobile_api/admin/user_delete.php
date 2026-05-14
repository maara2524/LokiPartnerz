<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);

$input = admin_get_input();
$userId = (int)($input['id'] ?? 0);

if ($userId <= 0) {
    admin_error('Invalid user id');
}

$pdo = admin_get_pdo();
$pdo->beginTransaction();

try {
    $pdo->prepare('DELETE FROM teams WHERE user_id = ?')->execute([$userId]);
    $pdo->prepare('DELETE FROM artist_profiles WHERE user_id = ?')->execute([$userId]);
    $pdo->prepare('DELETE FROM subscription_history WHERE user_id = ?')->execute([$userId]);
    $pdo->prepare('DELETE FROM subscription_transactions WHERE user_id = ?')->execute([$userId]);
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$userId]);

    $pdo->commit();
    admin_success(['message' => 'User deleted successfully']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log('Admin user delete failed: ' . $e->getMessage());
    admin_error('Unable to delete user. Please try again.', 500);
}

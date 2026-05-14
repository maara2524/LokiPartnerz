<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);
$input = admin_get_input();

$userId = (int)($input['id'] ?? 0);
$status = trim((string)($input['status'] ?? ''));

if ($userId <= 0 || !in_array($status, ['active', 'inactive'], true)) {
    admin_error('Invalid status update request');
}

$pdo = admin_get_pdo();
$stmt = $pdo->prepare('SELECT id, role FROM users WHERE id = ? LIMIT 1');
$stmt->execute([$userId]);
$user = $stmt->fetch();

if (!$user) {
    admin_error('User not found', 404);
}

$level = null;
if ($user['role'] === 'artist') {
    $level = $status === 'active' ? 3 : 5;
}

$pdo->beginTransaction();

try {
    if ($level !== null) {
        $updateUser = $pdo->prepare('UPDATE users SET status = ?, level = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
        $updateUser->execute([$status, $level, $userId]);

        $updateProfile = $pdo->prepare('UPDATE artist_profiles SET is_active = ?, artist_level = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?');
        $updateProfile->execute([$status === 'active' ? 1 : 0, (string)$level, $userId]);
    } else {
        $updateUser = $pdo->prepare('UPDATE users SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
        $updateUser->execute([$status, $userId]);

        $updateTeam = $pdo->prepare('UPDATE teams SET active = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?');
        $updateTeam->execute([$status === 'active' ? 1 : 0, $userId]);
    }

    $pdo->commit();
    admin_success(['message' => 'User status updated']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log('Admin user status update failed: ' . $e->getMessage());
    admin_error('Unable to update user status. Please try again.', 500);
}

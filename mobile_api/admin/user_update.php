<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);
$input = admin_get_input();

$userId = (int)($input['id'] ?? 0);
$name = trim((string)($input['name'] ?? ''));
$phone = trim((string)($input['phone'] ?? ''));
$business = trim((string)($input['business'] ?? ''));
$location = trim((string)($input['location'] ?? ''));
$level = (int)($input['level'] ?? 0);

if ($userId <= 0 || $name === '' || $phone === '') {
    admin_error('Invalid request payload');
}

$pdo = admin_get_pdo();
$userStmt = $pdo->prepare('SELECT id, role FROM users WHERE id = ? LIMIT 1');
$userStmt->execute([$userId]);
$user = $userStmt->fetch();

if (!$user) {
    admin_error('User not found', 404);
}

$pdo->beginTransaction();

try {
    if ($user['role'] === 'artist') {
        if ($level < 1 || $level > 5) {
            throw new RuntimeException('Artist level must be between 1 and 5');
        }

        $updateUser = $pdo->prepare('UPDATE users SET level = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
        $updateUser->execute([$level, $userId]);

        $updateProfile = $pdo->prepare(
            'UPDATE artist_profiles
             SET contact_person_name = ?, whatsapp_number = ?, business_name = ?, location = ?, artist_level = ?, updated_at = CURRENT_TIMESTAMP
             WHERE user_id = ?'
        );
        $updateProfile->execute([$name, $phone, $business, $location, (string)$level, $userId]);
    } else {
        $updateTeam = $pdo->prepare(
            'UPDATE teams
             SET display_name = ?, phone = ?, updated_at = CURRENT_TIMESTAMP
             WHERE user_id = ?'
        );
        $updateTeam->execute([$name, $phone, $userId]);
    }

    $pdo->commit();
    admin_success(['message' => 'User updated successfully']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    admin_error($e->getMessage(), 400);
}

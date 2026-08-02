<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);

$input = admin_get_input();

$name = trim((string)($input['name'] ?? ''));
$username = trim((string)($input['username'] ?? ''));
$phone = trim((string)($input['phone'] ?? ''));
$business = trim((string)($input['business'] ?? ''));
$role = trim((string)($input['role'] ?? 'artist'));
$category = admin_normalize_category($input['category'] ?? 'Makeup');

if ($name === '' || $username === '' || $phone === '') {
    admin_error('Name, username and phone are required');
}

if (!in_array($role, ['artist', 'telecaller'], true)) {
    admin_error('Invalid role supplied');
}

$pdo = admin_get_pdo();
$pdo->beginTransaction();

try {
    $check = $pdo->prepare('SELECT COUNT(*) FROM users WHERE username = ?');
    $check->execute([$username]);
    if ((int)$check->fetchColumn() > 0) {
        throw new RuntimeException('Username already exists');
    }

    $temporaryPassword = $phone;
    $passwordHash = password_hash($temporaryPassword, PASSWORD_DEFAULT);
    $level = $role === 'artist' ? 5 : 1;

    $insertUser = $pdo->prepare(
        "INSERT INTO users (username, email, password_hash, role, status, level, created_at, updated_at)
         VALUES (?, NULL, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    );
    $userStatus = $role === 'telecaller' ? 'active' : 'inactive';
    $insertUser->execute([$username, $passwordHash, $role, $userStatus, $level]);
    $userId = (int)$pdo->lastInsertId();

    if ($role === 'artist') {
        $insertProfile = $pdo->prepare(
            "INSERT INTO artist_profiles
                (user_id, business_name, contact_person_name, whatsapp_number, location, artist_level, package_details, is_active, category, created_at, updated_at)
             VALUES (?, ?, ?, ?, '', ?, '', 0, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
        );
        $insertProfile->execute([$userId, $business, $name, $phone, (string)$level, $category]);
    } else {
        $teamUsername = preg_replace('/[^a-z0-9.]/', '.', strtolower($username));
        $insertTeam = $pdo->prepare(
            "INSERT INTO teams
                (username, password_hash, display_name, phone, role, active, is_on_leave, created_at, updated_at, user_id)
             VALUES (?, ?, ?, ?, 'telecaller', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?)"
        );
        $insertTeam->execute([$teamUsername, $passwordHash, $name, $phone, $userId]);
    }

    $pdo->commit();

    admin_success([
        'message' => 'User created successfully',
        'temporary_password' => $temporaryPassword,
        'user_id' => $userId,
    ], 201);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    admin_error($e->getMessage(), 400);
}

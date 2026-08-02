<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);
$input = admin_get_input();

$name = trim((string)($input['name'] ?? ''));
$phone = trim((string)($input['phone'] ?? ''));

if ($name === '' || $phone === '') {
    admin_error('Name and phone are required');
}

$baseUsername = strtolower(preg_replace('/[^a-z0-9]+/', '.', $name) ?: 'telecaller');
$username = trim($baseUsername, '.');
if ($username === '') {
    $username = 'telecaller';
}

$pdo = admin_get_pdo();
$counter = 0;
$candidate = $username;

do {
    $check = $pdo->prepare('SELECT COUNT(*) FROM users WHERE username = ?');
    $check->execute([$candidate]);
    $exists = (int)$check->fetchColumn() > 0;
    if ($exists) {
        $counter++;
        $candidate = $username . $counter;
    }
} while ($exists);

$temporaryPassword = $phone;
$passwordHash = password_hash($temporaryPassword, PASSWORD_DEFAULT);

$pdo->beginTransaction();

try {
    $pdo->prepare(
        "INSERT INTO users (username, password_hash, role, status, level, created_at, updated_at)
         VALUES (?, ?, 'telecaller', 'active', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    )->execute([$candidate, $passwordHash]);

    $userId = (int)$pdo->lastInsertId();

    $pdo->prepare(
        "INSERT INTO teams (username, password_hash, display_name, phone, role, active, is_on_leave, created_at, updated_at, user_id)
         VALUES (?, ?, ?, ?, 'telecaller', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?)"
    )->execute([$candidate, $passwordHash, $name, $phone, $userId]);

    $pdo->commit();

    admin_success([
        'message' => 'Telecaller created successfully',
        'username' => $candidate,
        'temporary_password' => $temporaryPassword,
    ], 201);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    admin_error($e->getMessage(), 400);
}

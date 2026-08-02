<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

admin_require_method(['POST']);
admin_require_user(['admin']);

$input = admin_get_input();
$leadId = (int)($input['id'] ?? 0);

if ($leadId <= 0) {
    admin_error('Invalid lead id');
}

$pdo = admin_get_pdo();
$pdo->beginTransaction();

try {
    foreach (['lead_notes', 'lead_activity', 'lead_status_history'] as $table) {
        $pdo->prepare("DELETE FROM {$table} WHERE lead_id = ?")->execute([$leadId]);
    }

    $pdo->prepare('DELETE FROM leads WHERE id = ?')->execute([$leadId]);

    $pdo->commit();
    admin_success(['message' => 'Lead deleted successfully']);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    admin_error($e->getMessage(), 400);
}

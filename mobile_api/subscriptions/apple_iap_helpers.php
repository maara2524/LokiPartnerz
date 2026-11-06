<?php

declare(strict_types=1);

function apple_transaction_tombstone_hash(string $transactionId): string
{
    $key = getenv('APPLE_IAP_TOMBSTONE_HMAC_KEY');
    if (!is_string($key) || strlen($key) < 32) {
        throw new RuntimeException('APPLE_IAP_TOMBSTONE_HMAC_KEY must be configured with at least 32 characters');
    }

    return hash_hmac('sha256', $transactionId, $key);
}

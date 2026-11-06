-- Minimal, non-account-linked deletion audit and Apple purchase replay protection.
-- Run once after 2026_11_06_add_apple_iap.sql.

CREATE TABLE `account_deletion_audit` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `deleted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `account_deletion_apple_transaction_hashes` (
    `transaction_hash` CHAR(64) NOT NULL,
    `deletion_audit_id` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`transaction_hash`),
    KEY `idx_deletion_audit_id` (`deletion_audit_id`),
    CONSTRAINT `fk_deletion_apple_transaction_audit`
        FOREIGN KEY (`deletion_audit_id`)
        REFERENCES `account_deletion_audit` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Preserve team-lead records while removing the deleted user's creator identity.
ALTER TABLE `team_lead_tracking`
    MODIFY `created_by` INT(11) DEFAULT NULL
    COMMENT 'Which team member created this tracking record';

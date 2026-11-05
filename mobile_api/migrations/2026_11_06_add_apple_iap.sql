-- StoreKit (Apple In-App Purchase) support.
--
-- Product type in App Store Connect: NON-RENEWING SUBSCRIPTION.
-- Each Apple product maps to one existing subscription_plans row, so the
-- Android/web Razorpay flow and the iOS StoreKit flow share the same plans,
-- levels, claim limits and subscription_history records.
--
-- Run this migration ONCE against the production database.

ALTER TABLE `subscription_plans`
    ADD COLUMN `apple_product_id` VARCHAR(100) DEFAULT NULL AFTER `description`,
    ADD UNIQUE KEY `uniq_subscription_plans_apple_product_id` (`apple_product_id`);

ALTER TABLE `subscription_transactions`
    ADD COLUMN `provider` VARCHAR(20) NOT NULL DEFAULT 'razorpay' AFTER `plan_id`,
    ADD COLUMN `apple_transaction_id` VARCHAR(120) DEFAULT NULL AFTER `razorpay_payment_id`,
    ADD COLUMN `apple_original_transaction_id` VARCHAR(120) DEFAULT NULL AFTER `apple_transaction_id`,
    ADD COLUMN `apple_product_id` VARCHAR(100) DEFAULT NULL AFTER `apple_original_transaction_id`,
    ADD COLUMN `apple_environment` VARCHAR(20) DEFAULT NULL AFTER `apple_product_id`,
    ADD COLUMN `apple_purchase_date` DATETIME DEFAULT NULL AFTER `apple_environment`,
    ADD UNIQUE KEY `uniq_subscription_transactions_apple_txn` (`apple_transaction_id`);

-- Map the live plans to the App Store Connect product IDs.
-- The SKU/product ID must match exactly what is created in App Store Connect.
UPDATE `subscription_plans`
SET `apple_product_id` = 'com.lwv.bridalbookermachine.basic'
WHERE `slug` = 'basic';

UPDATE `subscription_plans`
SET `apple_product_id` = 'com.lwv.bridalbookermachine.extended'
WHERE `slug` = 'extended_basic';

-- Trial and admin-only test plans are intentionally not offered as Apple products.

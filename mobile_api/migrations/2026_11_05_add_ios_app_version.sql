-- Add an iOS row to app_version_config.
--
-- The mobile API already filters by platform. Until this row exists,
-- check_app_version.php returns a non-blocking response for iOS.
--
-- IMPORTANT: replace the empty playstore_url with the real App Store URL
-- (https://apps.apple.com/app/id<APP_ID>) once the App Store record exists.
-- For the iOS row, playstore_url stores the App Store URL; the column name is
-- kept for backwards compatibility with the existing Android setup.

INSERT INTO app_version_config
    (platform, latest_version, minimum_version, update_required, update_message, playstore_url, status)
SELECT
    'ios',
    '3.2.15',
    '3.2.15',
    0,
    'A new version is available. Please update to continue.',
    '',
    1
WHERE NOT EXISTS (
    SELECT 1 FROM app_version_config WHERE platform = 'ios'
);

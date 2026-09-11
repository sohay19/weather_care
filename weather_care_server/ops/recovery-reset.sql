-- DESTRUCTIVE. Only after explicit incident approval, maintenance and drain.
-- Not a migration. Never run during deployment or normal application startup.
-- Apply reviewed current migrations first. On ANY error remain in maintenance.
DELETE FROM notification_history;
DELETE FROM notification_settings;
DELETE FROM installation_warning_state;
DELETE FROM installation_ownership_challenges;
DELETE FROM legacy_installation_ownership;
DELETE FROM installation_activity;
DELETE FROM installations;
DELETE FROM installation_credentials;
DELETE FROM active_regions;

-- Read-only. Every count must be zero before resuming. Unknown tables need review.
SELECT 'installations' AS table_name, COUNT(*) AS remaining FROM installations;
SELECT 'notification_settings' AS table_name, COUNT(*) AS remaining FROM notification_settings;
SELECT 'notification_history' AS table_name, COUNT(*) AS remaining FROM notification_history;
SELECT 'installation_warning_state' AS table_name, COUNT(*) AS remaining FROM installation_warning_state;
SELECT 'installation_credentials' AS table_name, COUNT(*) AS remaining FROM installation_credentials;
SELECT 'installation_activity' AS table_name, COUNT(*) AS remaining FROM installation_activity;
SELECT 'installation_ownership_challenges' AS table_name, COUNT(*) AS remaining FROM installation_ownership_challenges;
SELECT 'legacy_installation_ownership' AS table_name, COUNT(*) AS remaining FROM legacy_installation_ownership;
SELECT 'active_regions' AS table_name, COUNT(*) AS remaining FROM active_regions;
SELECT name AS unreviewed_table FROM sqlite_schema WHERE type = 'table'
AND name NOT GLOB 'sqlite_*'
AND name NOT IN ('_cf_KV', '_cf_METADATA', 'd1_migrations', 'installations', 'notification_settings',
'notification_history', 'installation_warning_state', 'installation_credentials',
'installation_activity', 'installation_ownership_challenges', 'legacy_installation_ownership',
'active_regions', 'weather_cache', 'daily_weather_snapshots', 'weekly_forecast_records',
'api_usage_daily', 'grid_observation_snapshots', 'nationwide_forecast_fields',
'administrative_boundary_dataset', 'administrative_boundary_features', 'administrative_boundary_grid_regions');
PRAGMA foreign_key_check;

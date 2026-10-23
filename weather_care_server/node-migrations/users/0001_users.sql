-- Node 분리 DB 최초 스키마. 기존 통합 DB는 node:db:split으로 전환한다.

CREATE TABLE IF NOT EXISTS installations (
  installation_id TEXT PRIMARY KEY,
  fcm_token TEXT,
  nx INTEGER NOT NULL,
  ny INTEGER NOT NULL,
  region_topic TEXT NOT NULL,
  location_mode TEXT NOT NULL,
  platform TEXT,
  app_version TEXT,
  timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS active_regions (
  region_id TEXT PRIMARY KEY,
  topic TEXT NOT NULL,
  nx INTEGER NOT NULL,
  ny INTEGER NOT NULL,
  subscriber_count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS notification_settings (
  installation_id TEXT PRIMARY KEY,
  notification_enabled INTEGER NOT NULL DEFAULT 1,
  notification_time TEXT NOT NULL DEFAULT '07:00',
  umbrella_enabled INTEGER NOT NULL DEFAULT 1,
  parasol_enabled INTEGER NOT NULL DEFAULT 1,
  heavy_snow_enabled INTEGER NOT NULL DEFAULT 1,
  outerwear_enabled INTEGER NOT NULL DEFAULT 1,
  mask_enabled INTEGER NOT NULL DEFAULT 1,
  water_enabled INTEGER NOT NULL DEFAULT 1,
  sunscreen_enabled INTEGER NOT NULL DEFAULT 1,
  daily_weather_enabled INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS notification_history (
  installation_id TEXT NOT NULL,
  target_date TEXT NOT NULL,
  notification_key TEXT NOT NULL,
  sent_at TEXT NOT NULL,
  payload_hash TEXT,
  PRIMARY KEY (installation_id, target_date, notification_key)
);

ALTER TABLE notification_settings
  ADD COLUMN heavy_rain_enabled INTEGER NOT NULL DEFAULT 1;

ALTER TABLE notification_settings
  ADD COLUMN heatwave_enabled INTEGER NOT NULL DEFAULT 1;

ALTER TABLE notification_settings
  ADD COLUMN cold_wave_enabled INTEGER NOT NULL DEFAULT 1;

ALTER TABLE notification_settings
  ADD COLUMN shower_light_rain_enabled INTEGER NOT NULL DEFAULT 1;

ALTER TABLE installations ADD COLUMN latitude REAL;
ALTER TABLE installations ADD COLUMN longitude REAL;
ALTER TABLE installations
  ADD COLUMN current_rain_state INTEGER NOT NULL DEFAULT 0;
ALTER TABLE installations ADD COLUMN current_rain_observed_at TEXT;

CREATE TABLE IF NOT EXISTS installation_warning_state (
  installation_id TEXT NOT NULL,
  warning_type TEXT NOT NULL,
  warning_name TEXT NOT NULL,
  level_code TEXT NOT NULL,
  level_name TEXT NOT NULL,
  region_name TEXT NOT NULL,
  effective_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (installation_id, warning_type),
  FOREIGN KEY (installation_id) REFERENCES installations(installation_id)
    ON DELETE CASCADE
);

ALTER TABLE installations
  ADD COLUMN road_ice_level INTEGER NOT NULL DEFAULT 0;
ALTER TABLE installations ADD COLUMN road_ice_link_id TEXT;
ALTER TABLE installations ADD COLUMN road_ice_observed_at TEXT;

ALTER TABLE installations ADD COLUMN road_control_event_key TEXT;
ALTER TABLE installations ADD COLUMN road_control_kind TEXT;
ALTER TABLE installations ADD COLUMN road_control_started_at TEXT;

-- Credentials are separate from registrations: an interrupted enrollment never
-- stores a push token, coordinates or notification preferences.
CREATE TABLE installation_credentials (
  installation_id TEXT PRIMARY KEY,
  secret_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE installation_ownership_challenges (
  installation_id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL,
  secret_hash TEXT NOT NULL,
  proof_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  FOREIGN KEY (installation_id) REFERENCES installations(installation_id) ON DELETE CASCADE
);

-- Freeze the pre-authentication delivery route. In-flight old Worker requests
-- must not redirect the ownership proof by replacing a registration token.
CREATE TABLE legacy_installation_ownership (
  installation_id TEXT PRIMARY KEY,
  fcm_token TEXT,
  FOREIGN KEY (installation_id) REFERENCES installations(installation_id) ON DELETE CASCADE
);
INSERT INTO legacy_installation_ownership SELECT installation_id, fcm_token FROM installations;

-- Also defend against in-flight requests running the previous Worker version.
CREATE TRIGGER installation_insert_requires_owner BEFORE INSERT ON installations
WHEN NOT EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = NEW.installation_id)
BEGIN SELECT RAISE(ABORT, 'installation authentication required'); END;
CREATE TRIGGER settings_insert_requires_owner BEFORE INSERT ON notification_settings
WHEN NOT EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = NEW.installation_id)
BEGIN SELECT RAISE(ABORT, 'installation authentication required'); END;
CREATE TRIGGER history_requires_installation BEFORE INSERT ON notification_history
WHEN NOT EXISTS (SELECT 1 FROM installations WHERE installation_id = NEW.installation_id)
BEGIN SELECT RAISE(IGNORE); END;
CREATE TRIGGER warning_state_requires_installation BEFORE INSERT ON installation_warning_state
WHEN NOT EXISTS (SELECT 1 FROM installations WHERE installation_id = NEW.installation_id)
BEGIN SELECT RAISE(IGNORE); END;

-- Do not infer app activity from updated_at: the notification scheduler writes it.
CREATE TABLE installation_activity (
  installation_id TEXT PRIMARY KEY,
  last_active_at TEXT NOT NULL
);

-- No reliable historic last-use timestamp exists. Start the first retention
-- window at rollout for existing registrations, settings and credentials.
INSERT INTO installation_activity (installation_id, last_active_at)
SELECT installation_id, strftime('%Y-%m-%dT%H:%M:%fZ', 'now') FROM (
  SELECT installation_id FROM installations
  UNION SELECT installation_id FROM notification_settings
  UNION SELECT installation_id FROM installation_credentials
);

-- One calendar year in Korea; February 29 expires on February 28 next year.
CREATE INDEX installation_activity_expiry ON installation_activity
  (julianday(last_active_at, '+9 hours', '+1 year', 'floor', '-9 hours'));
CREATE INDEX notification_history_expiry ON notification_history
  (julianday(sent_at, '+9 hours', '+1 year', 'floor', '-9 hours'));

-- Removing an expired anchor atomically removes every related row. No permanent
-- deletion marker is retained. Trigger errors roll back the whole statement.
CREATE TRIGGER activity_delete_clears_installation AFTER DELETE ON installation_activity
BEGIN
  DELETE FROM notification_history WHERE installation_id = OLD.installation_id;
  DELETE FROM notification_settings WHERE installation_id = OLD.installation_id;
  DELETE FROM installation_warning_state WHERE installation_id = OLD.installation_id;
  DELETE FROM installation_ownership_challenges WHERE installation_id = OLD.installation_id;
  DELETE FROM legacy_installation_ownership WHERE installation_id = OLD.installation_id;
  DELETE FROM installations WHERE installation_id = OLD.installation_id;
  DELETE FROM installation_credentials WHERE installation_id = OLD.installation_id;
END;

-- Also clean the activity marker when the previous Worker handles a user delete.
CREATE TRIGGER credential_delete_clears_activity AFTER DELETE ON installation_credentials
WHEN NOT EXISTS (SELECT 1 FROM installations WHERE installation_id = OLD.installation_id)
  AND NOT EXISTS (SELECT 1 FROM notification_settings WHERE installation_id = OLD.installation_id)
BEGIN DELETE FROM installation_activity WHERE installation_id = OLD.installation_id; END;

-- Existing registrations are deliberately left unconfirmed. They cannot receive
-- notifications until a current app session passes the local 14+ gate and
-- registers again with the current policy assertion.
ALTER TABLE installations ADD COLUMN minimum_age_confirmed_at TEXT;
ALTER TABLE installations ADD COLUMN age_policy_version INTEGER NOT NULL DEFAULT 0;

CREATE INDEX installations_minimum_age_policy
  ON installations(age_policy_version, minimum_age_confirmed_at);

CREATE INDEX IF NOT EXISTS idx_installations_weather_target
  ON installations (nx, ny, latitude, longitude);

ALTER TABLE notification_settings ADD COLUMN lightning_enabled INTEGER NOT NULL DEFAULT 1;

CREATE TABLE lightning_notification_claims (
  installation_id TEXT NOT NULL REFERENCES installations(installation_id) ON DELETE CASCADE,
  notification_key TEXT NOT NULL,
  lease_until TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  sent_at TEXT,
  PRIMARY KEY (installation_id, notification_key)
);

CREATE INDEX idx_lightning_claims_expiry ON lightning_notification_claims(expires_at);

-- 이동 감시 세션과 측정 시각. 이동 경로 이력은 저장하지 않는다.
ALTER TABLE installations ADD COLUMN background_location_revision TEXT;
ALTER TABLE installations ADD COLUMN location_measured_at TEXT;

CREATE TRIGGER disable_background_location_when_alerts_off
AFTER UPDATE OF notification_enabled ON notification_settings
WHEN NEW.notification_enabled = 0
BEGIN
  UPDATE installations SET background_location_revision = NULL
  WHERE installation_id = NEW.installation_id;
END;

-- 구버전의 기본 lightning_enabled=1을 새 기능 지원으로 간주하지 않는다.
-- 낙뢰 설정 필드를 실제로 저장한 앱만 전용 알림을 받을 수 있다.
ALTER TABLE notification_settings ADD COLUMN lightning_supported INTEGER NOT NULL DEFAULT 0;

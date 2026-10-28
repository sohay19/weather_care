-- 기존 설치는 구독 설정 행이 없으므로 단일 지역 발송을 유지한다.
CREATE TABLE notification_region_preferences (
  installation_id TEXT PRIMARY KEY REFERENCES installation_credentials(installation_id) ON DELETE CASCADE,
  updated_at TEXT NOT NULL
);
CREATE TABLE notification_regions (
  installation_id TEXT NOT NULL REFERENCES notification_region_preferences(installation_id) ON DELETE CASCADE,
  region_key TEXT NOT NULL,
  scope_id TEXT NOT NULL,
  enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
  nx INTEGER, ny INTEGER, region_name TEXT,
  latitude REAL, longitude REAL,
  PRIMARY KEY(installation_id,region_key)
);
CREATE TABLE notification_region_state (
  installation_id TEXT NOT NULL REFERENCES notification_region_preferences(installation_id) ON DELETE CASCADE,
  scope_id TEXT NOT NULL,
  current_rain_state INTEGER NOT NULL DEFAULT 0,
  road_ice_level INTEGER NOT NULL DEFAULT 0, road_ice_link_id TEXT,
  road_control_event_key TEXT, road_control_kind TEXT,
  PRIMARY KEY(installation_id,scope_id)
);
CREATE TABLE notification_region_warning_state (
  installation_id TEXT NOT NULL REFERENCES notification_region_preferences(installation_id) ON DELETE CASCADE,
  scope_id TEXT NOT NULL, warning_type TEXT NOT NULL, warning_name TEXT NOT NULL,
  level_code TEXT NOT NULL, level_name TEXT NOT NULL, region_name TEXT NOT NULL,
  effective_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  PRIMARY KEY(installation_id,scope_id,warning_type)
);
-- 앱의 조회 구역이 수동 지역으로 바뀌어도 마지막 GPS 구역은 보존한다.
CREATE TRIGGER notification_regions_gps_update AFTER UPDATE ON installations
WHEN NEW.location_mode='GPS'
BEGIN
  UPDATE notification_regions SET
    scope_id=CASE WHEN nx IS NOT NEW.nx OR ny IS NOT NEW.ny THEN lower(hex(randomblob(16))) ELSE scope_id END,
    region_name=CASE WHEN nx IS NOT NEW.nx OR ny IS NOT NEW.ny OR latitude IS NOT NEW.latitude OR longitude IS NOT NEW.longitude THEN NULL ELSE region_name END,
    nx=NEW.nx, ny=NEW.ny, latitude=NEW.latitude, longitude=NEW.longitude
  WHERE installation_id=NEW.installation_id AND region_key='GPS';
  DELETE FROM notification_region_state WHERE installation_id=NEW.installation_id
    AND scope_id NOT IN (SELECT scope_id FROM notification_regions WHERE installation_id=NEW.installation_id);
  DELETE FROM notification_region_warning_state WHERE installation_id=NEW.installation_id
    AND scope_id NOT IN (SELECT scope_id FROM notification_regions WHERE installation_id=NEW.installation_id);
END;
CREATE TRIGGER notification_regions_delete AFTER DELETE ON installations BEGIN
  DELETE FROM notification_region_preferences WHERE installation_id=OLD.installation_id;
END;

CREATE TRIGGER notification_regions_gps_insert AFTER INSERT ON installations WHEN NEW.location_mode='GPS'
BEGIN
  UPDATE notification_regions SET nx=NEW.nx,ny=NEW.ny,latitude=NEW.latitude,longitude=NEW.longitude
    WHERE installation_id=NEW.installation_id AND region_key='GPS';
END;

CREATE TRIGGER notification_regions_legacy_insert AFTER INSERT ON installations
BEGIN
  UPDATE notification_regions SET nx=NEW.nx,ny=NEW.ny
    WHERE installation_id=NEW.installation_id AND region_key='LEGACY' AND nx IS NULL;
END;

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

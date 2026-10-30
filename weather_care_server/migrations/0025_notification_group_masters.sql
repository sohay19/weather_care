-- 구버전의 정기 알림 선택을 두 그룹의 기본값으로 보존한다.
ALTER TABLE notification_settings ADD COLUMN carry_notification_enabled INTEGER CHECK (carry_notification_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN today_notification_enabled INTEGER CHECK (today_notification_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN weather_notification_enabled INTEGER CHECK (weather_notification_enabled IN (0, 1));

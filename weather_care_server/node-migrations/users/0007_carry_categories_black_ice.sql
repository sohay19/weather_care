-- 새 준비물 항목과 블랙아이스 선택은 구 앱의 기존 설정을 fallback으로 보존한다.
ALTER TABLE notification_settings ADD COLUMN snow_preparation_enabled INTEGER CHECK (snow_preparation_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN uv_preparation_enabled INTEGER CHECK (uv_preparation_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN pollen_enabled INTEGER CHECK (pollen_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN black_ice_enabled INTEGER CHECK (black_ice_enabled IN (0, 1));

-- 특보 상태의 실제 구역을 기록하여 위치 이동 후 다른 구역의 해제를 보내지 않는다.
ALTER TABLE installation_warning_state ADD COLUMN region_id TEXT;
ALTER TABLE notification_region_warning_state ADD COLUMN region_id TEXT;

-- 구버전의 기본 lightning_enabled=1을 새 기능 지원으로 간주하지 않는다.
-- 낙뢰 설정 필드를 실제로 저장한 앱만 전용 알림을 받을 수 있다.
ALTER TABLE notification_settings ADD COLUMN lightning_supported INTEGER NOT NULL DEFAULT 0;

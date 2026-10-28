ALTER TABLE notification_settings ADD COLUMN commute_to_work_start TEXT NOT NULL DEFAULT '07:00';
ALTER TABLE notification_settings ADD COLUMN commute_to_work_end TEXT NOT NULL DEFAULT '10:00';
ALTER TABLE notification_settings ADD COLUMN commute_from_work_start TEXT NOT NULL DEFAULT '17:00';
ALTER TABLE notification_settings ADD COLUMN commute_from_work_end TEXT NOT NULL DEFAULT '20:00';

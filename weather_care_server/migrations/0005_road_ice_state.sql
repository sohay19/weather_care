ALTER TABLE installations
  ADD COLUMN road_ice_level INTEGER NOT NULL DEFAULT 0;
ALTER TABLE installations ADD COLUMN road_ice_link_id TEXT;
ALTER TABLE installations ADD COLUMN road_ice_observed_at TEXT;

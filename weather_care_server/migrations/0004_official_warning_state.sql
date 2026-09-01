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

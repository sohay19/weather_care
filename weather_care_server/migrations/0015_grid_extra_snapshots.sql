CREATE TABLE IF NOT EXISTS grid_extra_snapshots (
  source TEXT NOT NULL,
  target_id TEXT NOT NULL,
  slot TEXT NOT NULL,
  payload TEXT NOT NULL,
  collected_at TEXT NOT NULL,
  PRIMARY KEY (source, target_id, slot)
);

CREATE INDEX IF NOT EXISTS idx_grid_extra_snapshots_source_time
  ON grid_extra_snapshots (source, slot DESC);

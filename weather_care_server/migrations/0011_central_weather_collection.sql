CREATE TABLE IF NOT EXISTS api_usage_daily (
  usage_date TEXT NOT NULL,
  provider TEXT NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  response_bytes INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (usage_date, provider)
);

CREATE INDEX IF NOT EXISTS idx_installations_weather_target
  ON installations (nx, ny, latitude, longitude);

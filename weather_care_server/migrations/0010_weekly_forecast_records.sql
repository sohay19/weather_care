CREATE TABLE IF NOT EXISTS weekly_forecast_records (
  region_id TEXT NOT NULL,
  forecast_date TEXT NOT NULL,
  forecast_payload TEXT NOT NULL,
  source TEXT NOT NULL,
  issued_at TEXT,
  recorded_at TEXT NOT NULL,
  PRIMARY KEY (region_id, forecast_date)
);

CREATE INDEX IF NOT EXISTS weekly_forecast_records_date_idx
  ON weekly_forecast_records(forecast_date);

-- Node 분리 DB 최초 스키마. 기존 통합 DB는 node:db:split으로 전환한다.

CREATE TABLE IF NOT EXISTS weather_cache (
  cache_key TEXT PRIMARY KEY,
  region_id TEXT NOT NULL,
  nx INTEGER NOT NULL,
  ny INTEGER NOT NULL,
  cache_type TEXT NOT NULL,
  payload TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'AVAILABLE',
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_weather_snapshots (
  region_id TEXT NOT NULL,
  observation_date TEXT NOT NULL,
  temperature REAL,
  apparent_temperature REAL,
  pm10 INTEGER,
  pm25 INTEGER,
  summary TEXT,
  PRIMARY KEY (region_id, observation_date)
);

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

CREATE TABLE IF NOT EXISTS api_usage_daily (
  usage_date TEXT NOT NULL,
  provider TEXT NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  response_bytes INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (usage_date, provider)
);

-- 전국 원본은 격자별로 복제하지 않고 회차당 한 번 저장한다.
CREATE TABLE grid_observation_snapshots (
  observed_at TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE nationwide_forecast_fields (
  issue_time TEXT NOT NULL,
  valid_time TEXT NOT NULL,
  variable TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (issue_time, valid_time, variable)
);
CREATE INDEX nationwide_forecast_valid_time ON nationwide_forecast_fields(valid_time, issue_time);

-- 국가데이터처 SGIS 원본 경계. 완성한 데이터셋만 단일 트랜잭션으로 교체한다.
CREATE TABLE IF NOT EXISTS administrative_boundary_dataset (
  singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
  version TEXT NOT NULL,
  manifest TEXT NOT NULL,
  imported_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS administrative_boundary_features (
  sgis_code TEXT PRIMARY KEY,
  source_name TEXT NOT NULL,
  kma_code TEXT,
  precision TEXT NOT NULL CHECK(precision IN ('DONG','PARENT','UNMAPPED')),
  min_lon REAL NOT NULL, min_lat REAL NOT NULL,
  max_lon REAL NOT NULL, max_lat REAL NOT NULL,
  geometry TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS administrative_boundary_bbox
  ON administrative_boundary_features(min_lon,max_lon,min_lat,max_lat);
CREATE TABLE IF NOT EXISTS administrative_boundary_grid_regions (
  nx INTEGER NOT NULL, ny INTEGER NOT NULL, kma_code TEXT NOT NULL,
  PRIMARY KEY(nx,ny)
);

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

CREATE TABLE lightning_collection_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  attempted_at TEXT NOT NULL,
  window_end TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('AVAILABLE', 'FAILED'))
);

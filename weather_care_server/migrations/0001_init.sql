CREATE TABLE IF NOT EXISTS installations (
  installation_id TEXT PRIMARY KEY,
  fcm_token TEXT,
  nx INTEGER NOT NULL,
  ny INTEGER NOT NULL,
  region_topic TEXT NOT NULL,
  location_mode TEXT NOT NULL,
  platform TEXT,
  app_version TEXT,
  timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS active_regions (
  region_id TEXT PRIMARY KEY,
  topic TEXT NOT NULL,
  nx INTEGER NOT NULL,
  ny INTEGER NOT NULL,
  subscriber_count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS notification_settings (
  installation_id TEXT PRIMARY KEY,
  notification_enabled INTEGER NOT NULL DEFAULT 1,
  notification_time TEXT NOT NULL DEFAULT '07:00',
  umbrella_enabled INTEGER NOT NULL DEFAULT 1,
  parasol_enabled INTEGER NOT NULL DEFAULT 1,
  heavy_snow_enabled INTEGER NOT NULL DEFAULT 1,
  outerwear_enabled INTEGER NOT NULL DEFAULT 1,
  mask_enabled INTEGER NOT NULL DEFAULT 1,
  water_enabled INTEGER NOT NULL DEFAULT 1,
  sunscreen_enabled INTEGER NOT NULL DEFAULT 1,
  daily_weather_enabled INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

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

CREATE TABLE IF NOT EXISTS notification_history (
  installation_id TEXT NOT NULL,
  target_date TEXT NOT NULL,
  notification_key TEXT NOT NULL,
  sent_at TEXT NOT NULL,
  payload_hash TEXT,
  PRIMARY KEY (installation_id, target_date, notification_key)
);


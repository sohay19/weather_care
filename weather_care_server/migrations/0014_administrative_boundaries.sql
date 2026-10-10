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

-- 전국 원본은 격자별로 복제하지 않고 회차당 한 번 저장한다.
CREATE TABLE grid_observation_snapshots (
  observed_at TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

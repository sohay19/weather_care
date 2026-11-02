CREATE TABLE wear_links (
  id TEXT PRIMARY KEY,
  reader_hash TEXT NOT NULL UNIQUE,
  writer_hash TEXT UNIQUE,
  code_hash TEXT NOT NULL UNIQUE,
  code_expires_at INTEGER NOT NULL,
  payload TEXT,
  published_at INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX idx_wear_links_updated ON wear_links(updated_at);

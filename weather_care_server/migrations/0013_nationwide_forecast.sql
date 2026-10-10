CREATE TABLE nationwide_forecast_fields (
  issue_time TEXT NOT NULL,
  valid_time TEXT NOT NULL,
  variable TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (issue_time, valid_time, variable)
);
CREATE INDEX nationwide_forecast_valid_time ON nationwide_forecast_fields(valid_time, issue_time);

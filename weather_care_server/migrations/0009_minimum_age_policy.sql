-- Existing registrations are deliberately left unconfirmed. They cannot receive
-- notifications until a current app session passes the local 14+ gate and
-- registers again with the current policy assertion.
ALTER TABLE installations ADD COLUMN minimum_age_confirmed_at TEXT;
ALTER TABLE installations ADD COLUMN age_policy_version INTEGER NOT NULL DEFAULT 0;

CREATE INDEX installations_minimum_age_policy
  ON installations(age_policy_version, minimum_age_confirmed_at);

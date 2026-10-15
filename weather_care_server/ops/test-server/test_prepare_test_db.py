import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from prepare_test_db import EXTRA_TABLE, TEST_ONLY_TABLES, prepare
from sync_cache import CHANGING_TABLES, STATIC_TABLES


class PrepareTestDbTest(unittest.TestCase):
    def test_clones_weather_and_preserves_only_test_user_data(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            live_path, test_path, output_path = (
                root / "live.sqlite", root / "test.sqlite", root / "output.sqlite"
            )
            for path, label in ((live_path, "live"), (test_path, "test")):
                with closing(sqlite3.connect(path)) as db, db:
                    for table in TEST_ONLY_TABLES:
                        db.execute(f'CREATE TABLE "{table}" (value TEXT)')
                        db.execute(f'INSERT INTO "{table}" VALUES (?)', (label,))
                    db.execute("CREATE TABLE api_usage_daily (usage_date TEXT, provider TEXT, "
                               "request_count INTEGER, response_bytes INTEGER, updated_at TEXT, "
                               "PRIMARY KEY(usage_date, provider))")
                    db.execute("INSERT INTO api_usage_daily VALUES ('2026-10-15', 'SOURCE', 1, 10, ?)",
                               (label,))
                    if label == "test":
                        db.execute("INSERT INTO api_usage_daily VALUES "
                                   "('2026-10-15', 'TEST', 2, 20, 'test')")
                    db.execute(f'CREATE TABLE "{EXTRA_TABLE}" (value TEXT)')
                    db.execute(f'INSERT INTO "{EXTRA_TABLE}" VALUES (?)', (label,))
                    for table in STATIC_TABLES:
                        db.execute(f'CREATE TABLE "{table}" (value TEXT)')
                        db.execute(f'INSERT INTO "{table}" VALUES (?)', (label,))
                    for table, stamp in CHANGING_TABLES.items():
                        db.execute(f'CREATE TABLE "{table}" (value TEXT, "{stamp}" TEXT)')
                        db.execute(
                            f'INSERT INTO "{table}" VALUES (?, ?)',
                            (label, "2026-10-15T00:00:00.000Z"),
                        )
                    db.execute("CREATE TRIGGER activity_cleanup AFTER DELETE ON "
                               "installation_activity BEGIN DELETE FROM installations; END")

            copied = prepare(live_path, test_path, output_path)
            with closing(sqlite3.connect(output_path)) as db:
                self.assertEqual(copied["installations"], 1)
                self.assertEqual(db.execute("SELECT value FROM installations").fetchone()[0], "test")
                self.assertEqual(db.execute("SELECT request_count FROM api_usage_daily "
                                            "WHERE provider='SOURCE'").fetchone()[0], 1)
                self.assertEqual(db.execute("SELECT request_count FROM api_usage_daily "
                                            "WHERE provider='TEST'").fetchone()[0], 2)
                self.assertEqual(db.execute(f"SELECT value FROM {EXTRA_TABLE}").fetchone()[0], "test")
                self.assertEqual(db.execute("SELECT value FROM weather_cache").fetchone()[0], "live")
                self.assertIsNotNone(db.execute("SELECT 1 FROM sqlite_master WHERE "
                                                "type='trigger' AND name='activity_cleanup'").fetchone())
                self.assertEqual(
                    db.execute("SELECT last_stamp FROM test_cache_sync_state "
                               "WHERE table_name='weather_cache'").fetchone()[0],
                    "2026-10-15T00:00:00.000Z",
                )


if __name__ == "__main__":
    unittest.main()

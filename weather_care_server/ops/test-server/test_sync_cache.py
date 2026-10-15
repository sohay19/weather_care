import json
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from sync_cache import archive_air_quality


class AirHistorySyncTest(unittest.TestCase):
    def test_archives_new_observations_once_without_extra_requests(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.sqlite"
            target = Path(directory) / "target.sqlite"
            with closing(sqlite3.connect(source)) as db, db:
                db.execute("CREATE TABLE weather_cache (cache_key TEXT, payload TEXT, updated_at TEXT)")
                db.execute("INSERT INTO weather_cache VALUES (?, ?, ?)", (
                    "COLLECTED_NATIONWIDE_AIR",
                    json.dumps({"observations": [{"stationName": "구로구", "observedAt": "2026-10-14T15:00:00Z", "pm25": 12}]}),
                    "2026-10-15T00:10:00Z",
                ))
            with closing(sqlite3.connect(target)) as db, db:
                db.execute("CREATE TABLE weather_cache (cache_key TEXT PRIMARY KEY, region_id TEXT, nx INTEGER, "
                           "ny INTEGER, cache_type TEXT, payload TEXT, status TEXT, updated_at TEXT)")
                db.execute("CREATE TABLE test_cache_sync_state (table_name TEXT PRIMARY KEY, last_stamp TEXT)")
                db.execute("ATTACH DATABASE ? AS source", (str(source),))
                self.assertEqual(archive_air_quality(db), 1)
                self.assertEqual(archive_air_quality(db), 0)
                row = db.execute("SELECT payload FROM weather_cache WHERE cache_key=?",
                                 ("AIR_HISTORY_2026-10-15_전국",)).fetchone()
                self.assertEqual(json.loads(row[0])[0]["pm25"], 12)
                db.commit()
                db.execute("DETACH DATABASE source")


if __name__ == "__main__":
    unittest.main()

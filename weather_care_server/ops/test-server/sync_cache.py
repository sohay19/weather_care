#!/usr/bin/env python3
"""Copy public weather caches from the live SQLite DB into the test DB."""

import json
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


STATIC_TABLES = (
    "administrative_boundary_dataset",
    "administrative_boundary_features",
    "administrative_boundary_grid_regions",
)
CHANGING_TABLES = {
    "grid_observation_snapshots": "updated_at",
    "nationwide_forecast_fields": "updated_at",
    "weather_cache": "updated_at",
    "weekly_forecast_records": "recorded_at",
}


def columns(db: sqlite3.Connection, schema: str, table: str) -> list[str]:
    return [row[1] for row in db.execute(f"PRAGMA {schema}.table_info({table})")]


def copy_table(db: sqlite3.Connection, table: str, since: str | None) -> int:
    source_columns = columns(db, "source", table)
    target_columns = columns(db, "main", table)
    if not source_columns or source_columns != target_columns:
        raise RuntimeError(f"CACHE_SCHEMA_MISMATCH:{table}")
    names = ", ".join(f'"{name}"' for name in source_columns)
    stamp = CHANGING_TABLES.get(table)
    condition = f' WHERE "{stamp}" >= ?' if stamp and since else ""
    params = (since,) if condition else ()
    cursor = db.execute(
        f'INSERT OR REPLACE INTO main."{table}" ({names}) '
        f'SELECT {names} FROM source."{table}"{condition}',
        params,
    )
    return cursor.rowcount


def archive_air_quality(db: sqlite3.Connection) -> int:
    source = db.execute(
        "SELECT payload, updated_at FROM source.weather_cache "
        "WHERE cache_key='COLLECTED_NATIONWIDE_AIR'"
    ).fetchone()
    if not source:
        return 0
    payload, stamp = source
    previous = db.execute(
        "SELECT last_stamp FROM test_cache_sync_state WHERE table_name='air_history'"
    ).fetchone()
    if previous and previous[0] == stamp:
        return 0
    observations = json.loads(payload).get("observations", [])
    grouped = {}
    korea = timezone(timedelta(hours=9))
    for item in observations:
        if not item.get("stationName") or not item.get("observedAt"):
            continue
        try:
            date = datetime.fromisoformat(item["observedAt"].replace("Z", "+00:00"))
            date = date.astimezone(korea).date().isoformat()
        except ValueError:
            continue
        grouped.setdefault(date, []).append(item)
    for date, items in grouped.items():
        key = f"AIR_HISTORY_{date}_전국"
        old = db.execute("SELECT payload FROM weather_cache WHERE cache_key=?", (key,)).fetchone()
        records = {
            (item["stationName"], item["observedAt"]): item
            for item in json.loads(old[0]) if item.get("stationName") and item.get("observedAt")
        } if old else {}
        records.update({(item["stationName"], item["observedAt"]): item for item in items})
        db.execute(
            "INSERT INTO weather_cache "
            "(cache_key, region_id, nx, ny, cache_type, payload, status, updated_at) "
            "VALUES (?, ?, 0, 0, 'AIR_HISTORY', ?, 'AVAILABLE', ?) "
            "ON CONFLICT(cache_key) DO UPDATE SET payload=excluded.payload, updated_at=excluded.updated_at",
            (key, key, json.dumps(list(records.values()), ensure_ascii=False),
             datetime.now(timezone.utc).isoformat(timespec="milliseconds")),
        )
    db.execute(
        "INSERT INTO test_cache_sync_state VALUES ('air_history', ?) "
        "ON CONFLICT(table_name) DO UPDATE SET last_stamp=excluded.last_stamp",
        (stamp,),
    )
    return len(observations)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: sync_cache.py LIVE_DB TEST_DB")
    source_path, target_path = (Path(value).resolve() for value in sys.argv[1:])
    if source_path == target_path or not source_path.is_file() or not target_path.is_file():
        raise RuntimeError("CACHE_DATABASE_PATH_INVALID")

    with sqlite3.connect(target_path, timeout=30) as db:
        db.execute("PRAGMA busy_timeout=30000")
        db.execute("ATTACH DATABASE ? AS source", (source_path.as_uri() + "?mode=ro",))
        db.execute(
            "CREATE TABLE IF NOT EXISTS test_cache_sync_state "
            "(table_name TEXT PRIMARY KEY, last_stamp TEXT)"
        )
        copied = {}
        with db:
            for table in STATIC_TABLES:
                if db.execute(
                    "SELECT 1 FROM test_cache_sync_state WHERE table_name = ?", (table,)
                ).fetchone():
                    continue
                copied[table] = copy_table(db, table, None)
                db.execute(
                    "INSERT INTO test_cache_sync_state VALUES (?, '')", (table,)
                )
            for table, stamp in CHANGING_TABLES.items():
                row = db.execute(
                    "SELECT last_stamp FROM test_cache_sync_state WHERE table_name = ?",
                    (table,),
                ).fetchone()
                last_stamp = row[0] if row else None
                copied[table] = copy_table(db, table, last_stamp)
                maximum = db.execute(
                    f'SELECT MAX("{stamp}") FROM source."{table}"'
                ).fetchone()[0]
                db.execute(
                    "INSERT INTO test_cache_sync_state VALUES (?, ?) "
                    "ON CONFLICT(table_name) DO UPDATE SET last_stamp=excluded.last_stamp",
                    (table, maximum or last_stamp or ""),
                )
            copied["air_history"] = archive_air_quality(db)
            cutoff = (datetime.now(timezone(timedelta(hours=9))).date() - timedelta(days=8)).isoformat()
            for cache_type, prefix in (
                ("AIR_HISTORY", "AIR_HISTORY_"),
                ("OBSERVED_DAILY_HUMIDITY", "OBSERVED_DAILY_HUMIDITY_"),
            ):
                db.execute(
                    "DELETE FROM weather_cache WHERE cache_type=? AND cache_key < ?",
                    (cache_type, prefix + cutoff + "_"),
                )
        print(copied)


if __name__ == "__main__":
    main()

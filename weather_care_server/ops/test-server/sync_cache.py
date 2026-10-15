#!/usr/bin/env python3
"""Copy public weather caches from the live SQLite DB into the test DB."""

import sqlite3
import sys
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
        print(copied)


if __name__ == "__main__":
    main()

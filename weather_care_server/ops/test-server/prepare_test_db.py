#!/usr/bin/env python3
"""Clone the live weather database while retaining only test user data."""

import sqlite3
import sys
from contextlib import closing
from pathlib import Path

from sync_cache import CHANGING_TABLES, STATIC_TABLES


TEST_ONLY_TABLES = (
    "active_regions",
    "installation_activity",
    "installation_credentials",
    "installation_ownership_challenges",
    "installation_warning_state",
    "installations",
    "legacy_installation_ownership",
    "notification_history",
    "notification_settings",
)
EXTRA_TABLE = "grid_extra_snapshots"


def table_exists(db: sqlite3.Connection, schema: str, table: str) -> bool:
    return db.execute(
        f"SELECT 1 FROM {schema}.sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone() is not None


def columns(db: sqlite3.Connection, schema: str, table: str) -> list[str]:
    return [row[1] for row in db.execute(f'PRAGMA {schema}.table_info("{table}")')]


def copy_test_table(db: sqlite3.Connection, table: str) -> int:
    if not table_exists(db, "test", table):
        raise RuntimeError(f"TEST_TABLE_MISSING:{table}")
    if not table_exists(db, "main", table):
        schema = db.execute(
            "SELECT sql FROM test.sqlite_master WHERE type='table' AND name=?",
            (table,),
        ).fetchone()[0]
        db.execute(schema)
    names = columns(db, "main", table)
    if names != columns(db, "test", table):
        raise RuntimeError(f"TEST_SCHEMA_MISMATCH:{table}")
    fields = ", ".join(f'"{name}"' for name in names)
    db.execute(f'DELETE FROM main."{table}"')
    return db.execute(
        f'INSERT INTO main."{table}" ({fields}) '
        f'SELECT {fields} FROM test."{table}"'
    ).rowcount


def prepare(live_path: Path, test_path: Path, output_path: Path) -> dict[str, int]:
    paths = [path.resolve() for path in (live_path, test_path, output_path)]
    if len(set(paths)) != 3 or not all(path.is_file() for path in paths[:2]) or paths[2].exists():
        raise RuntimeError("TEST_DATABASE_PATH_INVALID")

    with closing(sqlite3.connect(paths[0].as_uri() + "?mode=ro", uri=True)) as live:
        with closing(sqlite3.connect(paths[2])) as output:
            live.backup(output, pages=1000, sleep=0.05)

    copied: dict[str, int] = {}
    with closing(sqlite3.connect(paths[2], uri=True)) as db:
        db.execute("PRAGMA foreign_keys=OFF")
        db.execute("ATTACH DATABASE ? AS test", (paths[1].as_uri() + "?mode=ro",))
        with db:
            for table in TEST_ONLY_TABLES:
                copied[table] = copy_test_table(db, table)
            copied[EXTRA_TABLE] = copy_test_table(db, EXTRA_TABLE)
            if columns(db, "main", "api_usage_daily") != columns(db, "test", "api_usage_daily"):
                raise RuntimeError("TEST_SCHEMA_MISMATCH:api_usage_daily")
            for row in db.execute(
                "SELECT usage_date, provider, request_count, response_bytes, updated_at "
                "FROM test.api_usage_daily"
            ):
                db.execute(
                    "INSERT INTO main.api_usage_daily VALUES (?, ?, ?, ?, ?) "
                    "ON CONFLICT(usage_date, provider) DO UPDATE SET "
                    "request_count=MAX(request_count, excluded.request_count), "
                    "response_bytes=MAX(response_bytes, excluded.response_bytes), "
                    "updated_at=MAX(updated_at, excluded.updated_at)",
                    row,
                )
            db.execute(
                "CREATE TABLE IF NOT EXISTS test_cache_sync_state "
                "(table_name TEXT PRIMARY KEY, last_stamp TEXT)"
            )
            db.execute("DELETE FROM test_cache_sync_state")
            for table in STATIC_TABLES:
                db.execute(
                    "INSERT INTO test_cache_sync_state VALUES (?, '')", (table,)
                )
            for table, stamp in CHANGING_TABLES.items():
                maximum = db.execute(
                    f'SELECT MAX("{stamp}") FROM main."{table}"'
                ).fetchone()[0]
                db.execute(
                    "INSERT INTO test_cache_sync_state VALUES (?, ?)",
                    (table, maximum or ""),
                )
        if db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
            raise RuntimeError("TEST_DATABASE_QUICK_CHECK_FAILED")
        db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        db.execute("PRAGMA journal_mode=DELETE")
    return copied


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: prepare_test_db.py LIVE_DB TEST_DB OUTPUT_DB")
    print(prepare(*(Path(value) for value in sys.argv[1:])))

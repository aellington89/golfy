from __future__ import annotations

import sqlite3
from pathlib import Path


SCHEMA = """
CREATE TABLE IF NOT EXISTS courses (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS rounds (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    date         TEXT    NOT NULL,            -- ISO date YYYY-MM-DD
    course_id    INTEGER NOT NULL REFERENCES courses(id) ON DELETE RESTRICT,
    round_number INTEGER NOT NULL DEFAULT 1,  -- 1, 2, ... for multiple rounds same day/course
    notes        TEXT,
    UNIQUE(date, course_id, round_number)
);

CREATE TABLE IF NOT EXISTS hole_results (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id         INTEGER NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    hole_number      INTEGER NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
    par              INTEGER NOT NULL CHECK (par BETWEEN 3 AND 5),
    score            INTEGER NOT NULL CHECK (score >= 1),
    fairway_hit      TEXT    CHECK (fairway_hit IN ('yes', 'no', 'na')),  -- na on par 3
    gir              INTEGER CHECK (gir IN (0, 1)),
    putts            INTEGER CHECK (putts >= 0),
    up_down_attempt  INTEGER CHECK (up_down_attempt IN (0, 1)),
    up_down_success  INTEGER CHECK (up_down_success IN (0, 1)),  -- null when no attempt
    penalty_stroke   INTEGER CHECK (penalty_stroke IN (0, 1)),
    notes            TEXT,
    UNIQUE(round_id, hole_number)
);

CREATE INDEX IF NOT EXISTS idx_rounds_date      ON rounds(date);
CREATE INDEX IF NOT EXISTS idx_rounds_course    ON rounds(course_id);
CREATE INDEX IF NOT EXISTS idx_holes_round      ON hole_results(round_id);
"""


def default_db_path() -> Path:
    """Per-user data location: ~/.golfy/golfy.db.

    Lives under the user home (not %LOCALAPPDATA% or Documents) to avoid both
    Microsoft Store Python's AppData sandbox redirect and OneDrive sync, either
    of which can hide or corrupt the SQLite file.
    """
    return Path.home() / ".golfy" / "golfy.db"


def connect(db_path: Path | None = None) -> sqlite3.Connection:
    path = db_path or default_db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(SCHEMA)
    return conn

from __future__ import annotations

import sqlite3

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QLabel,
    QMainWindow,
    QStatusBar,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from . import __version__


class PlaceholderTab(QWidget):
    def __init__(self, title: str, blurb: str) -> None:
        super().__init__()
        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        heading = QLabel(title)
        heading.setStyleSheet("font-size: 20px; font-weight: 600;")
        heading.setAlignment(Qt.AlignmentFlag.AlignCenter)

        body = QLabel(blurb)
        body.setStyleSheet("color: #666;")
        body.setAlignment(Qt.AlignmentFlag.AlignCenter)
        body.setWordWrap(True)

        layout.addWidget(heading)
        layout.addWidget(body)


class MainWindow(QMainWindow):
    def __init__(self, db: sqlite3.Connection) -> None:
        super().__init__()
        self.db = db

        self.setWindowTitle(f"Golfy — Video Game Golf Stats v{__version__}")
        self.resize(1100, 720)

        tabs = QTabWidget()
        tabs.addTab(
            PlaceholderTab("Rounds", "List of rounds will appear here."),
            "Rounds",
        )
        tabs.addTab(
            PlaceholderTab("Hole Entry", "Per-hole data entry form will live here."),
            "Hole Entry",
        )
        tabs.addTab(
            PlaceholderTab("Dashboard", "Lifetime + by-course stats will live here."),
            "Dashboard",
        )
        self.setCentralWidget(tabs)

        bar = QStatusBar()
        course_count, round_count, hole_count = self._counts()
        bar.showMessage(
            f"DB ready · {course_count} courses · {round_count} rounds · {hole_count} holes"
        )
        self.setStatusBar(bar)

    def _counts(self) -> tuple[int, int, int]:
        cur = self.db.cursor()
        c = cur.execute("SELECT COUNT(*) FROM courses").fetchone()[0]
        r = cur.execute("SELECT COUNT(*) FROM rounds").fetchone()[0]
        h = cur.execute("SELECT COUNT(*) FROM hole_results").fetchone()[0]
        return c, r, h

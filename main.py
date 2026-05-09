from __future__ import annotations

import sys

from PySide6.QtWidgets import QApplication

from golfy.db import connect
from golfy.main_window import MainWindow


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("Golfy")
    app.setOrganizationName("Golfy")

    db = connect()
    window = MainWindow(db)
    window.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())

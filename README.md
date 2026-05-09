# Golfy

Desktop app for tracking video game golf stats. PySide6 + SQLite.

## Setup

```powershell
.\dev.cmd
pip install -r requirements.txt
```

`dev.cmd` creates the venv if missing and opens a PowerShell session with it
active. It uses `activate.bat` under the hood, so it works without changing
PowerShell's ExecutionPolicy.

## Run

From a `dev.cmd` shell:

```powershell
python main.py
```

Or, without activation:

```powershell
.\.venv\Scripts\python.exe main.py
```

The SQLite database lives at `%USERPROFILE%\.golfy\golfy.db`.

## Data model

- `courses` — name
- `rounds` — date, course, round number, notes (one row per round)
- `hole_results` — par, score, fairway hit, GIR, putts, up/down, penalty per hole (18 rows per round)

Round and lifetime stats are derived from `hole_results`.

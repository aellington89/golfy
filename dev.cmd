@echo off
REM Drop into a PowerShell session with the venv active.
REM Uses activate.bat so it works regardless of PowerShell ExecutionPolicy.

if not exist "%~dp0.venv\Scripts\activate.bat" (
    echo No .venv found. Creating one...
    python -m venv "%~dp0.venv"
    if errorlevel 1 exit /b 1
)

call "%~dp0.venv\Scripts\activate.bat"
echo Virtual environment active. Type 'exit' to leave.
powershell -NoExit -NoLogo

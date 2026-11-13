@echo off
cd /d "%~dp0"
set "traffic_python=python"
if exist ".venv\Scripts\python.exe" set "traffic_python=%~dp0.venv\Scripts\python.exe"
if not exist ".venv\Scripts\python.exe" if exist "..\.venv\Scripts\python.exe" set "traffic_python=%~dp0..\.venv\Scripts\python.exe"
"%traffic_python%" Python\app.py run
pause

@echo off
cd /d "%~dp0"
python Python\app.py devices
python Python\app.py check --cable 0 --device 1
pause

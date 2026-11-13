@echo off
cd /d "%~dp0"
python -m unittest discover -s sim -p "test_*.py" -v
pause

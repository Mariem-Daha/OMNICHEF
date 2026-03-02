@echo off
cd /d "d:\New folder\cuisinee\cuisinee\backend"
call venv\Scripts\activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

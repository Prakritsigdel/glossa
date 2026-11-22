@echo off
echo Starting Glossa FastAPI Backend...
cd backend
if not exist ".venv" (
    echo Creating virtual environment...
    py -m venv .venv
    call .venv\Scripts\activate.bat
    pip install -r requirements.txt
) else (
    call .venv\Scripts\activate.bat
)
echo Running database seeding...
python seed.py
echo Forwarding ADB port for connected Android devices...
adb reverse tcp:8000 tcp:8000 2>nul
echo Starting Uvicorn API server on http://0.0.0.0:8000 ...
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

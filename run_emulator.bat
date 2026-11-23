@echo off
echo ============================================================
echo  Glossa Android Emulator Launcher
echo ============================================================
echo.
echo Starting Docker backend (if not already running)...
cd /d "%~dp0"
docker compose up -d 2>nul
echo Waiting for backend to be ready...
timeout /t 5 /nobreak >nul
echo.
echo Launching Glossa on Android emulator...
echo Backend URL: http://10.0.2.2:8000 (emulator host loopback)
echo.
flutter run -d emulator --dart-define=API_BASE_URL=http://10.0.2.2:8000

@echo off
echo ============================================================
echo  Glossa Android Device Launcher
echo ============================================================
echo.
echo Starting Docker backend (if not already running)...
cd /d "%~dp0"
docker compose up -d 2>nul
echo Waiting for backend to be ready...
timeout /t 5 /nobreak >nul
echo.
echo Setting up ADB reverse port forwarding for port 8000...
echo This lets the physical device reach the host's port 8000 via 127.0.0.1.
adb reverse tcp:8000 tcp:8000 2>nul
if %errorlevel% neq 0 (
    echo WARNING: adb reverse failed. Make sure:
    echo   - An Android device is connected via USB with USB debugging enabled
    echo   - adb is in your PATH (Android SDK platform-tools)
    echo.
    echo Alternatively, launch with your LAN IP:
    echo   flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000
    echo.
)
echo.
echo Launching Glossa on connected Android device...
echo Backend URL: http://127.0.0.1:8000 (via adb reverse)
echo.
flutter run -d R5CY21AYF2H --dart-define=API_BASE_URL=http://127.0.0.1:8000

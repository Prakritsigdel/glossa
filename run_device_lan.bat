@echo off
echo ============================================================
echo  Glossa Android Device Launcher (LAN IP mode)
echo ============================================================
echo.
echo This mode connects directly via your LAN IP (no adb reverse needed).
echo.
echo Starting Docker backend (if not already running)...
cd /d "%~dp0"
docker compose up -d 2>nul
echo Waiting for backend to be ready...
timeout /t 5 /nobreak >nul
echo.
echo Detecting your LAN IP...
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4 Address"') do (
    set LAN_IP=%%a
)
set LAN_IP=%LAN_IP: =%
echo.
echo Your LAN IP: %LAN_IP%
echo.
echo IMPORTANT: Make sure your phone is on the same Wi-Fi network.
echo If Windows Firewall blocks the connection, run:
echo   netsh advfirewall firewall add rule name="Glossa Backend" dir=in action=allow protocol=TCP localport=8000
echo.
echo Launching Glossa with backend at http://%LAN_IP%:8000
flutter run -d R5CY21AYF2H --dart-define=API_BASE_URL=http://%LAN_IP%:8000

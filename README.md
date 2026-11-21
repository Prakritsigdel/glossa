# Glossa

Glossa is a Flutter heritage-language learning app backed by a FastAPI API and PostgreSQL database. The backend validates accounts, lesson answers, and lesson completion rewards.

## Requirements

- Flutter SDK for the platform you want to run
- Docker Engine and the Docker Compose plugin
- Git

## Get started

Clone the repository and enter the project directory:

```sh
git clone <repository-url>
cd glossa
```

Start the API and database from the project root:

```sh
docker compose up --build
```

Leave this terminal running. On first startup, Compose builds the API image, waits for PostgreSQL, applies database migrations, inserts the starter lesson content, and starts the API. The database is stored in a Docker volume named `glossa_pgdata` and remains available after containers stop.

In a second terminal, install Flutter packages and run the app:

```sh
flutter pub get
flutter run
```

The API endpoints are available at `http://localhost:8000`; interactive API documentation is at `http://localhost:8000/docs`. Check that the API is ready at `http://localhost:8000/health`, which should return `{"status":"ok"}`.

To stop the backend, press **Ctrl+C** in the Compose terminal. To start it again without rebuilding, use `docker compose up`.

## Choose the API address

The app's default API address depends on the Flutter target:

| Flutter target | Default API address |
| --- | --- |
| Linux, macOS, or Windows desktop | `http://127.0.0.1:8000` |
| Android emulator | `http://10.0.2.2:8000` |

For a physical phone, the phone and development computer must be on the same local network. Find the computer's local IP address (on Linux, run `hostname -I`), then launch Flutter with that address:

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
```

Replace `192.168.1.23` with the computer's actual Wi-Fi IP. Verify connectivity by opening `http://192.168.1.23:8000/health` in the phone's browser. If it cannot connect, check that the phone and computer share a network and that the computer's firewall allows incoming connections on port `8000`.

When launching from an IDE, pass the same value as a Dart define in the Flutter run configuration:

```text
API_BASE_URL=http://192.168.1.23:8000
```

For a deployed backend, set `API_BASE_URL` to its reachable API origin. Production deployments should use HTTPS.

## Lesson content and database

Starter lessons and exercises are defined in `backend/seed.py`. Each lesson and exercise has a stable ID; exercise options and matching pairs are stored as JSON. The seed script inserts records that are missing, but it does not overwrite existing records with the same ID. To update existing lesson content in a fresh or existing database, update the seed behavior/data as needed; to change table structure, create a database migration under `backend/migrations/versions/`.

You can inspect or edit the running PostgreSQL database with a GUI such as DBeaver or pgAdmin:

- Host: `localhost`
- Port: `5432`
- Database: `glossa`
- Username: `glossa`
- Password: `glossa`

The local credentials are for development only. Add a lesson before its exercises because each exercise references a lesson ID. If editing content through a database GUI, also update `backend/seed.py` so the change can be recreated from the repository.

To open the database in the terminal instead, run this from the project root:

```sh
docker compose exec db psql -U glossa -d glossa
```

Inside `psql`, `\dt` lists tables and `\q` exits.

## Accounts and data

Accounts use an email address and a password of at least eight characters. Access tokens are stored with the platform secure-storage plugin. The Family leaderboard currently includes all users because the app does not yet have family or group membership.

To remove the local database and all its saved account/progress data, run:

```sh
docker compose down -v
```

This permanently deletes the local PostgreSQL volume. Do not use this command if you need to keep the data.

---

## Windows 11 Development Setup

This section covers everything needed to develop and run Glossa on Windows 11 with a USB-connected Android phone.

### Prerequisites overview

| Tool | Required | Notes |
|---|---|---|
| Docker Desktop | Yes | Provides Docker Engine + Compose |
| WSL 2 | Yes | Docker Desktop installs and uses it |
| Flutter SDK | Yes | 3.x, stable channel |
| Android SDK + Platform-Tools | Yes | Bundled with Android Studio |
| ADB | Yes | Included in Platform-Tools |
| Git | Yes | |
| Java / JDK 17 | Yes | For Android builds |

### 1. Install Docker Desktop

Download Docker Desktop from <https://www.docker.com/products/docker-desktop/> and run the installer. It installs the Docker Engine, Docker Compose plugin, and the WSL 2 backend automatically.

After installation, launch **Docker Desktop** from the Start menu and wait until the status bar shows the engine is running. Verify in a terminal:

```powershell
docker --version
docker compose version
docker info
```

> Docker Desktop installs its CLI to `%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin`. If `docker` is not found after installation, open a **new** terminal window (the installer updates `PATH` for new sessions only).

#### BuildKit and DNS on first run

On first launch, Docker Desktop's BuildKit worker inside WSL 2 may fail to resolve `production.cloudfront.docker.com`. The included launch script works around this by pre-pulling base images through the Windows network stack before invoking `docker buildx build`.

If you see DNS errors during a manual `docker compose up --build`, run:

```powershell
docker pull python:3.12-slim
docker pull postgres:16-alpine
docker compose up --build -d
```

The Docker daemon is also configured with explicit DNS servers (`8.8.8.8`, `1.1.1.1`) via `%APPDATA%\Docker\daemon.json`.

### 2. WSL 2 requirements

Docker Desktop requires WSL 2. Run the following to verify:

```powershell
wsl --status
wsl --list --verbose
```

You should see a `docker-desktop` distribution with version 2. If WSL 2 is not installed, follow the Microsoft guide at <https://learn.microsoft.com/en-us/windows/wsl/install>.

Virtualization must be enabled in BIOS/UEFI. Check with:

```powershell
(Get-WmiObject Win32_ComputerSystem).HypervisorPresent
```

### 3. Flutter setup

Install Flutter following <https://docs.flutter.dev/get-started/install/windows>. The SDK should be placed somewhere without spaces in the path, e.g. `C:\Users\<you>\develop\flutter`.

Add `flutter\bin` to your user `PATH` environment variable. Verify:

```powershell
flutter --version
flutter doctor -v
```

Accept any Android SDK licenses that `flutter doctor` reports:

```powershell
flutter doctor --android-licenses
```

### 4. Android SDK and ADB

Android SDK Platform-Tools (which includes `adb`) are installed with Android Studio. Add the Platform-Tools directory to `PATH`:

```
C:\Users\<you>\AppData\Local\Android\Sdk\platform-tools
```

Verify:

```powershell
adb version
```

### 5. USB debugging on the Samsung Galaxy S25 Ultra

1. On the phone, go to **Settings → About phone → Software information** and tap **Build number** seven times to enable Developer Options.
2. Go to **Settings → Developer Options** and enable **USB debugging**.
3. Connect the phone via USB. When prompted on the phone screen, tap **Allow** to authorize the computer.
4. Confirm the connection:

```powershell
adb devices
```

Expected output includes `R5CY21AYF2H  device` (or your device serial).

### 6. One-command startup

After Docker Desktop is running and the phone is connected, start the entire stack with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_glossa.ps1
```

Or, if you have already set execution policy to allow local scripts:

```powershell
.\scripts\start_glossa.ps1
```

The script:

1. Finds Docker Desktop and adds it to `PATH` if needed.
2. Starts Docker Desktop automatically if the Engine is not running.
3. Pre-pulls base images to avoid BuildKit DNS issues.
4. Builds the API image with `docker buildx build`.
5. Starts both containers with `docker compose up`.
6. Waits up to 60 seconds for `http://localhost:8000/health` to return `{"status":"ok"}`.
7. Detects the connected Android device.
8. Configures ADB reverse port forwarding (`tcp:8000 → tcp:8000`) so the phone's `localhost:8000` reaches the API on your laptop.
9. Runs `flutter pub get` if packages need updating.
10. Launches the Flutter app on the phone with `API_BASE_URL=http://127.0.0.1:8000`.

Available parameters:

```powershell
.\scripts\start_glossa.ps1 -SkipFlutter          # backend only
.\scripts\start_glossa.ps1 -Device R5CY21AYF2H   # explicit device serial
.\scripts\start_glossa.ps1 -WifiIp 192.168.0.14  # use Wi-Fi instead of ADB reverse
```

### 7. ADB reverse port forwarding (USB development)

ADB reverse makes the phone's `localhost:8000` point to your laptop's port `8000`. This avoids Wi-Fi IP configuration and firewall rules.

```powershell
adb reverse tcp:8000 tcp:8000
adb reverse --list   # confirm
```

ADB reverse is session-scoped. It is re-established each time you run `start_glossa.ps1`. If you reconnect the USB cable mid-session, run the two commands above again.

Verify from the phone:

```powershell
adb shell "curl -s http://127.0.0.1:8000/health"
# expected: {"status":"ok"}
```

### 8. Wi-Fi networking fallback

If ADB reverse is unavailable (wireless debugging, incompatible Android version), use the laptop's Wi-Fi IP instead.

Find the IP:

```powershell
ipconfig
# or
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -eq "Wi-Fi" }
```

Launch with the detected IP:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.0.14:8000
```

Verify the phone can reach the API by opening `http://192.168.0.14:8000/health` in the phone's browser.

If the phone cannot connect, Windows Defender Firewall may be blocking port 8000. Create a targeted inbound rule (private networks only):

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "Glossa Dev API" -Direction Inbound `
  -Action Allow -Protocol TCP -LocalPort 8000 `
  -Profile Private -Description "Allow Glossa Flutter app on LAN"
```

### 9. API health check

```powershell
Invoke-RestMethod http://localhost:8000/health
# expected: status: ok

# Or in a browser:
# http://localhost:8000/health
# http://localhost:8000/docs   ← interactive Swagger UI
```

### 10. Database access

Inspect the running database:

```powershell
docker compose exec db psql -U glossa -d glossa
```

Inside psql:
- `\dt` — list tables
- `SELECT id, title FROM lessons;` — verify seed data
- `\q` — exit

Or connect with DBeaver / pgAdmin using host `localhost`, port `5432`, database `glossa`, username `glossa`, password `glossa`.

### 11. Diagnostics

Run the full environment check at any time:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_glossa.ps1
```

This prints `PASS`, `FAIL`, or `WARN` for every component and suggests fixes for each failure.

### 12. Backend lifecycle

| Goal | Command |
|---|---|
| Start (first time, builds image) | `docker compose up --build -d` |
| Start (after image exists) | `docker compose up -d` |
| Stop (preserves database) | `docker compose down` |
| View logs | `docker compose logs -f` |
| **Delete database** (irreversible) | `docker compose down -v` |
| Rebuild image only | `docker buildx build --builder desktop-linux --load -t glossa_app-api ./backend` |

> **Never** run `docker compose down -v` during normal development. It deletes the `glossa_pgdata` volume and all user accounts, progress, and lesson attempts permanently.

### 13. Troubleshooting

**Docker not found in a new terminal**
The installer updates PATH for new sessions. Close and reopen the terminal, or run:
```powershell
$env:PATH += ";$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin"
```

**`docker compose up --build` fails with DNS error (production.cloudfront.docker.com)**
Pre-pull the base images manually, then retry:
```powershell
docker pull python:3.12-slim
docker pull postgres:16-alpine
docker compose up -d
```

**API container exits immediately**
Check logs:
```powershell
docker logs glossa_app-api-1
```
Common causes: PostgreSQL not yet healthy (wait and retry), missing migration, Python dependency error.

**Phone not detected by ADB**
- Check USB cable (use the cable that came with the phone).
- Check USB mode: pull down the notification shade and set USB mode to **File Transfer (MTP)** or **Charging** — not "No data transfer".
- Revoke and re-grant USB debugging authorization: Developer Options → Revoke USB debugging authorizations, then reconnect.
- Reinstall ADB drivers via Device Manager or Samsung USB Driver.

**ADB reverse fails**
The phone must be authorized and in `device` state (not `unauthorized`). Check with `adb devices`. If the phone shows `unauthorized`, unplug and replug the USB cable and accept the prompt on the phone.

**Flutter build fails: license not accepted**
```powershell
flutter doctor --android-licenses
```
Type `y` to accept each license.

**`flutter pub get` reports incompatible constraints**
The `pubspec.yaml` pins versions. Run `flutter pub outdated` to review; upgrade only when you are ready to test.

<#
.SYNOPSIS
  One-command launcher for the Glossa development stack.

.DESCRIPTION
  Adds Docker Desktop to PATH if needed, starts the backend via Docker Compose
  (pre-pulling base images to work around the BuildKit DNS issue on first run),
  waits for the health endpoint, sets up ADB reverse for connected Android
  devices, and launches the Flutter app.

.PARAMETER SkipFlutter
  Start only the backend; do not run flutter.

.PARAMETER Device
  ADB device serial to target. Defaults to the first connected device.

.PARAMETER WifiIp
  Use a Wi-Fi IP instead of ADB reverse (for wireless debugging).

.EXAMPLE
  .\scripts\start_glossa.ps1
  .\scripts\start_glossa.ps1 -SkipFlutter
  .\scripts\start_glossa.ps1 -Device R5CY21AYF2H
  .\scripts\start_glossa.ps1 -WifiIp 192.168.0.14
#>
[CmdletBinding()]
param(
    [switch]$SkipFlutter,
    [string]$Device,
    [string]$WifiIp
)

$ErrorActionPreference = 'Continue'
$ProjectRoot = Split-Path -Parent $PSScriptRoot

function Write-Step { param([string]$msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. Locate Docker Desktop and add its bin to PATH if missing
# ---------------------------------------------------------------------------
Write-Step "Checking Docker"

function Find-DockerBin {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin",
        "$env:ProgramFiles\Docker\Docker\resources\bin",
        "$env:LOCALAPPDATA\Docker\resources\bin"
    )
    foreach ($c in $candidates) {
        if (Test-Path "$c\docker.exe") { return $c }
    }
    return $null
}

$dockerBin = Find-DockerBin
if ($dockerBin -and ($env:PATH -notlike "*$dockerBin*")) {
    $env:PATH += ";$dockerBin"
    Write-Ok "Docker Desktop bin added to PATH for this session: $dockerBin"
}

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Fail "Docker not found. Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
    exit 1
}
Write-Ok "Docker found: $(docker --version 2>&1)"

# ---------------------------------------------------------------------------
# 2. Verify Docker Engine is running; offer to start Docker Desktop
# ---------------------------------------------------------------------------
Write-Step "Verifying Docker Engine"

$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Docker Engine is not running — attempting to start Docker Desktop..."
    $ddExe = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
    if (Test-Path $ddExe) {
        Start-Process $ddExe
        Write-Host "  Waiting up to 90 seconds for Docker Engine..."
        $ready = $false
        for ($i = 1; $i -le 18; $i++) {
            Start-Sleep -Seconds 5
            $dockerInfo = docker info 2>&1
            if ($LASTEXITCODE -eq 0) { $ready = $true; break }
            Write-Host "  [$($i*5)s] still waiting..."
        }
        if (-not $ready) {
            Write-Fail "Docker Engine did not start within 90 seconds."
            Write-Host "  Open Docker Desktop manually, wait for 'Engine running', then re-run this script."
            exit 1
        }
    } else {
        Write-Fail "Docker Desktop not found at $ddExe"
        Write-Host "  Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
        exit 1
    }
}
Write-Ok "Docker Engine is running"

# ---------------------------------------------------------------------------
# 3. Check Flutter
# ---------------------------------------------------------------------------
Write-Step "Checking Flutter"

# Add Flutter to PATH if missing (search common install locations)
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $flutterCandidates = @(
        "$env:USERPROFILE\develop\flutter\bin",
        "$env:USERPROFILE\flutter\bin",
        "C:\flutter\bin",
        "C:\src\flutter\bin",
        "$env:LOCALAPPDATA\flutter\bin"
    )
    foreach ($c in $flutterCandidates) {
        if (Test-Path "$c\flutter.bat") {
            $env:PATH += ";$c"
            Write-Ok "Flutter added to PATH for this session: $c"
            break
        }
    }
}

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Fail "Flutter not found in PATH."
    Write-Host "  Add your Flutter SDK bin directory to PATH, e.g.:"
    Write-Host "  `$env:PATH += ';C:\Users\<you>\develop\flutter\bin'"
    exit 1
}
$flutterVer = (flutter --version --no-pub 2>&1 | Select-Object -First 1) -replace 'Flutter (\S+).*','$1'
Write-Ok "Flutter $flutterVer"

# ---------------------------------------------------------------------------
# 4. Build & start backend
# ---------------------------------------------------------------------------
Write-Step "Building and starting backend (Docker Compose)"

Push-Location $ProjectRoot

# Pre-pull base images to avoid the BuildKit CloudFront DNS failure on first run.
# Regular 'docker pull' resolves through the Windows network stack (which works),
# whereas BuildKit resolves through the WSL2 network (which may fail on first boot).
$baseImages = @("python:3.12-slim", "postgres:16-alpine")
foreach ($img in $baseImages) {
    $exists = docker image inspect $img 2>&1 | Select-String '"Id"'
    if (-not $exists) {
        Write-Host "  Pre-pulling $img ..."
        docker pull $img 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Could not pull $img — build may fail if network is unavailable."
        } else {
            Write-Ok "Pulled $img"
        }
    } else {
        Write-Ok "$img already cached"
    }
}

# Build the API image using the desktop-linux builder (uses locally cached layers)
Write-Host "  Building API image..."
$buildOutput = docker buildx build --builder desktop-linux --load --progress=plain -t glossa_app-api ./backend 2>&1
$buildLines  = $buildOutput | Where-Object { $_ -match 'ERROR|error' }
if ($LASTEXITCODE -ne 0 -or ($buildLines | Select-String -Pattern 'ERROR' -Quiet)) {
    Write-Fail "API image build failed."
    $buildOutput | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    Pop-Location
    exit 1
}
Write-Ok "API image built"

# Start services (--no-build because we just built the image above)
docker compose up --no-build -d 2>&1 | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -ne 0) {
    Write-Fail "docker compose up failed"
    Pop-Location
    exit 1
}
Pop-Location
Write-Ok "Docker Compose services started"

# ---------------------------------------------------------------------------
# 5. Wait for API health
# ---------------------------------------------------------------------------
Write-Step "Waiting for API health endpoint (up to 60 s)"

$healthy = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 2 -ErrorAction Stop
        if ($resp.status -eq "ok") { $healthy = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
    if ($i % 5 -eq 0) { Write-Host "  [${i}s] still waiting..." }
}

if ($healthy) {
    Write-Ok "API is healthy  http://localhost:8000"
    Write-Ok "API docs        http://localhost:8000/docs"
} else {
    Write-Fail "API did not become healthy within 60 seconds."
    Write-Host ""
    Write-Host "  Inspect logs with:"
    Write-Host "    docker logs glossa_app-api-1"
    Push-Location $ProjectRoot
    docker compose logs api --tail=30 2>&1 | ForEach-Object { Write-Host "  $_" }
    Pop-Location
    exit 1
}

# ---------------------------------------------------------------------------
# 6. Verify PostgreSQL
# ---------------------------------------------------------------------------
Write-Step "Verifying PostgreSQL"

$env:PATH += ";$dockerBin"
$pgReady = docker exec glossa_app-db-1 pg_isready -U glossa -d glossa 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Ok "PostgreSQL healthy"
} else {
    Write-Warn "pg_isready check failed: $pgReady"
}

# ---------------------------------------------------------------------------
# 7. ADB device setup
# ---------------------------------------------------------------------------
Write-Step "Configuring Android device"

$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adbCmd) {
    Write-Warn "ADB not found in PATH — skipping device setup"
    $apiBaseUrl = "http://127.0.0.1:8000"
} else {
    # Discover device serial
    if (-not $Device) {
        $deviceLines = @(adb devices 2>$null | Where-Object { $_ -match "`t" -and $_ -match 'device$' -and $_ -notmatch 'unauthorized|offline' })
        if ($deviceLines.Count -gt 0) {
            $Device = ($deviceLines[0] -split "`t")[0].Trim()
        }
    }

    if ($Device) {
        $model = (adb -s $Device shell getprop ro.product.model 2>$null).Trim()
        Write-Ok "Device: $Device ($model)"

        if ($WifiIp) {
            Write-Host "  Using Wi-Fi IP: $WifiIp"
            $apiBaseUrl = "http://${WifiIp}:8000"
        } else {
            # ADB reverse: phone's localhost:8000 → host's localhost:8000
            adb -s $Device reverse tcp:8000 tcp:8000 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "ADB reverse tcp:8000 → tcp:8000 configured"
                # Quick connectivity smoke-test from device
                $smoke = adb -s $Device shell "curl -s -m 5 http://127.0.0.1:8000/health" 2>$null
                if ($smoke -match '"ok"') {
                    Write-Ok "Phone can reach API (smoke test passed)"
                } else {
                    Write-Warn "Smoke test inconclusive (curl may be absent on device) — ADB reverse is set"
                }
                $apiBaseUrl = "http://127.0.0.1:8000"
            } else {
                Write-Warn "adb reverse failed — falling back to Wi-Fi"
                # Detect actual Wi-Fi adapter IP
                $wifiIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.InterfaceAlias -notmatch 'Loopback|Docker|WSL|vEthernet|Bluetooth|Hyper-V' -and
                        $_.IPAddress -notmatch '^(169|172\.(1[6-9]|2\d|3[01]))'
                    } |
                    Sort-Object -Property PrefixLength -Descending |
                    Select-Object -First 1
                ).IPAddress
                if ($wifiIp) {
                    $apiBaseUrl = "http://${wifiIp}:8000"
                    Write-Warn "Using Wi-Fi IP $wifiIp — ensure phone and laptop share the same network"
                } else {
                    $apiBaseUrl = "http://127.0.0.1:8000"
                    Write-Warn "Could not determine Wi-Fi IP — using 127.0.0.1 (may not reach device over Wi-Fi)"
                }
            }
        }
    } else {
        Write-Warn "No Android device connected — USB debugging or authorization may be needed"
        $apiBaseUrl = "http://127.0.0.1:8000"
    }
}

Write-Host ""
Write-Host "  API_BASE_URL = $apiBaseUrl"

# ---------------------------------------------------------------------------
# 8. Flutter
# ---------------------------------------------------------------------------
if (-not $SkipFlutter) {
    Write-Step "Launching Flutter app"

    Push-Location $ProjectRoot

    # pub get only when pubspec.lock is out of date
    $pubOutdated = $false
    if (-not (Test-Path ".dart_tool\package_config.json")) { $pubOutdated = $true }
    if ($pubOutdated) {
        Write-Host "  Running flutter pub get..."
        flutter pub get 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warn "flutter pub get had warnings" }
    } else {
        Write-Ok "Flutter packages up to date"
    }

    $runArgs = @("run", "--dart-define=API_BASE_URL=$apiBaseUrl")
    if ($Device) { $runArgs += @("-d", $Device) }

    Write-Host ""
    Write-Host "  Running: flutter $($runArgs -join ' ')"
    Write-Host "  (press q to quit the Flutter app)"
    Write-Host ""
    flutter @runArgs

    Pop-Location
} else {
    Write-Step "Backend ready — Flutter skipped"
    Write-Host ""
    Write-Host "  API        http://localhost:8000"
    Write-Host "  Docs       http://localhost:8000/docs"
    Write-Host "  Device     $Device"
    Write-Host ""
    Write-Host "  To launch Flutter manually:"
    Write-Host "    flutter run -d $Device --dart-define=API_BASE_URL=$apiBaseUrl"
}

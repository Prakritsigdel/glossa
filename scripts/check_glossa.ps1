<#
.SYNOPSIS
  Diagnostics script for the Glossa development environment.

.DESCRIPTION
  Checks all required tools, services, and configuration, reporting
  PASS / FAIL / WARN for each item. Runs quickly without building or
  downloading anything.

.EXAMPLE
  .\scripts\check_glossa.ps1
#>

$ErrorActionPreference = 'Continue'
$ProjectRoot = Split-Path -Parent $PSScriptRoot

$pass = 0; $fail = 0; $warn = 0

function Test-Check {
    param([string]$Name, [scriptblock]$Test, [switch]$Optional, [string]$Fix)
    Write-Host -NoNewline "  $($Name.PadRight(42))"
    try {
        $result = & $Test
        if ($result) {
            Write-Host "PASS  $result" -ForegroundColor Green
            $script:pass++
        } elseif ($Optional) {
            Write-Host "WARN  not found (optional)" -ForegroundColor Yellow
            if ($Fix) { Write-Host "        → $Fix" -ForegroundColor DarkGray }
            $script:warn++
        } else {
            Write-Host "FAIL" -ForegroundColor Red
            if ($Fix) { Write-Host "        → $Fix" -ForegroundColor DarkGray }
            $script:fail++
        }
    } catch {
        $msg = $_.Exception.Message -replace "`n",' '
        if ($Optional) {
            Write-Host "WARN  $msg" -ForegroundColor Yellow
            $script:warn++
        } else {
            Write-Host "FAIL  $msg" -ForegroundColor Red
            if ($Fix) { Write-Host "        → $Fix" -ForegroundColor DarkGray }
            $script:fail++
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Glossa Development Environment Check  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Add Docker Desktop bin to PATH if needed (silent — same logic as start script)
# ---------------------------------------------------------------------------
$ddBinCandidates = @(
    "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin",
    "$env:ProgramFiles\Docker\Docker\resources\bin"
)
foreach ($c in $ddBinCandidates) {
    if ((Test-Path "$c\docker.exe") -and ($env:PATH -notlike "*$c*")) {
        $env:PATH += ";$c"; break
    }
}

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
            $env:PATH += ";$c"; break
        }
    }
}

# ---------------------------------------------------------------------------
Write-Host "[Tools]" -ForegroundColor White
# ---------------------------------------------------------------------------

Test-Check "Git" {
    $v = git --version 2>$null
    if ($LASTEXITCODE -eq 0) { $v.Trim() } else { $null }
} -Fix "Install Git from https://git-scm.com"

Test-Check "Flutter" {
    $lines = flutter --version 2>&1
    $first = $lines | Select-Object -First 1
    if ($first -match 'Flutter\s+(\S+)') { "Flutter $($Matches[1])" } else { $null }
} -Fix "Add Flutter SDK bin to PATH, e.g. C:\Users\<you>\develop\flutter\bin"

Test-Check "Dart (bundled with Flutter)" {
    $v = dart --version 2>&1
    if ($v -match 'Dart SDK version: (\S+)') { $Matches[1] } else { $null }
}

Test-Check "ADB" {
    $v = adb version 2>$null | Select-Object -First 1
    if ($v) { $v.Trim() } else { $null }
} -Fix "Install Android SDK Platform-Tools or add its path to PATH"

Test-Check "Docker CLI" {
    $v = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) { $v.Trim() } else { $null }
} -Fix "Install Docker Desktop from https://www.docker.com/products/docker-desktop/"

Test-Check "Docker Compose plugin" {
    $v = docker compose version 2>$null
    if ($LASTEXITCODE -eq 0) { $v.Trim() } else { $null }
} -Fix "Upgrade Docker Desktop — Compose is bundled since v3.x"

Test-Check "Java / JDK" {
    $v = java -version 2>&1 | Select-Object -First 1
    $vs = "$v".Trim()
    if ($vs -match 'version') { $vs } else { $null }
} -Optional

Test-Check "Python (py launcher)" {
    $v = py --version 2>$null
    if ($LASTEXITCODE -eq 0) { $v.Trim() } else { $null }
} -Optional

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[Project Files]" -ForegroundColor White
# ---------------------------------------------------------------------------

Test-Check "pubspec.yaml" {
    if (Test-Path "$ProjectRoot\pubspec.yaml") { "found" } else { $null }
}

Test-Check "docker-compose.yml" {
    if (Test-Path "$ProjectRoot\docker-compose.yml") { "found" } else { $null }
}

Test-Check "backend/Dockerfile" {
    if (Test-Path "$ProjectRoot\backend\Dockerfile") { "found" } else { $null }
}

Test-Check "backend/.env" {
    if (Test-Path "$ProjectRoot\backend\.env") { "found" } else { $null }
} -Fix "Copy backend\.env.example to backend\.env and fill in values"

Test-Check "backend/seed.py" {
    if (Test-Path "$ProjectRoot\backend\seed.py") { "found" } else { $null }
}

Test-Check "AndroidManifest INTERNET permission" {
    $mf = Get-Content "$ProjectRoot\android\app\src\main\AndroidManifest.xml" -Raw 2>$null
    if ($mf -match 'android\.permission\.INTERNET') { "present" } else { $null }
}

Test-Check "AndroidManifest usesCleartextTraffic" {
    $mf = Get-Content "$ProjectRoot\android\app\src\main\AndroidManifest.xml" -Raw 2>$null
    if ($mf -match 'usesCleartextTraffic\s*=\s*"true"') { "enabled (dev only)" } else { $null }
} -Optional

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[Docker Engine & Containers]" -ForegroundColor White
# ---------------------------------------------------------------------------

Test-Check "Docker Engine running" {
    $info = docker info 2>$null
    if ($LASTEXITCODE -eq 0) { "running" } else { $null }
} -Fix "Open Docker Desktop and wait until the icon shows 'Engine running'"

Test-Check "glossa_app-db-1 (PostgreSQL)" {
    $st = docker inspect --format "{{.State.Status}}" glossa_app-db-1 2>$null
    if ($st -eq "running") { "running" } else { $st }
} -Fix "Run: docker compose up -d  (from the project root)"

Test-Check "glossa_app-api-1 (FastAPI)" {
    $st = docker inspect --format "{{.State.Status}}" glossa_app-api-1 2>$null
    if ($st -eq "running") { "running" } else { $st }
} -Fix "Run: docker compose up -d  (from the project root)"

Test-Check "PostgreSQL pg_isready" {
    $r = docker exec glossa_app-db-1 pg_isready -U glossa -d glossa 2>$null
    if ($LASTEXITCODE -eq 0) { "healthy" } else { $null }
} -Fix "Check db container logs: docker logs glossa_app-db-1"

Test-Check "DB tables exist" {
    $tbls = docker exec glossa_app-db-1 psql -U glossa -d glossa -Atc "\dt" 2>$null
    $count = ($tbls -split "`n" | Where-Object { $_ -match '\S' }).Count
    if ($count -ge 4) { "$count tables" } else { $null }
} -Fix "Migrations may not have run. Check: docker logs glossa_app-api-1"

Test-Check "Lessons seeded (≥7)" {
    $cnt = docker exec glossa_app-db-1 psql -U glossa -d glossa -Atc "SELECT COUNT(*) FROM lessons;" 2>$null
    $n = [int]($cnt.Trim())
    if ($n -ge 7) { "$n lessons" } else { $null }
} -Fix "Seed did not run or failed. Check: docker logs glossa_app-api-1"

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[API Health]" -ForegroundColor White
# ---------------------------------------------------------------------------

Test-Check "API /health endpoint" {
    $resp = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 5 -ErrorAction Stop
    if ($resp.status -eq "ok") { "ok" } else { $null }
} -Fix "Backend not running. Run: .\scripts\start_glossa.ps1 -SkipFlutter"

Test-Check "Port 8000 listening" {
    $conn = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
    if ($conn) { "PID $($conn[0].OwningProcess)" } else { $null }
} -Fix "Start the backend: docker compose up -d"

Test-Check "API docs reachable (/docs)" {
    $r = Invoke-WebRequest -Uri "http://localhost:8000/docs" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($r.StatusCode -eq 200) { "200 OK" } else { $null }
} -Optional

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[Android Device]" -ForegroundColor White
# ---------------------------------------------------------------------------

$connectedDevice = $null

Test-Check "ADB device connected" {
    $raw = adb devices 2>$null
    $lines = @($raw | Where-Object { $_ -match "`t" -and $_ -match 'device$' -and $_ -notmatch 'unauthorized|offline' })
    if ($lines.Count -gt 0) {
        $serial = ($lines[0] -split "`t")[0].Trim()
        $script:connectedDevice = $serial
        $modelRaw = adb -s "$serial" shell getprop ro.product.model 2>$null
        $model = "$modelRaw".Trim()
        "$serial ($model)"
    } else { $null }
} -Fix "Enable USB debugging on the phone (Settings → Developer Options → USB Debugging) and accept the authorization prompt"

Test-Check "Flutter sees the device" {
    # Use adb to infer flutter device availability rather than waiting 20s for flutter devices
    $adbLines = @(adb devices 2>$null | Where-Object { $_ -match "`t" -and $_ -match 'device$' })
    if ($adbLines.Count -gt 0) {
        $serial = ($adbLines[0] -split "`t")[0].Trim()
        $model  = "$( adb -s "$serial" shell getprop ro.product.model 2>$null )".Trim()
        "android device $serial ($model) — run 'flutter devices' to confirm"
    } else { $null }
} -Fix "Run: flutter doctor -v  to diagnose"

Test-Check "ADB reverse tcp:8000 set" {
    $rl = adb reverse --list 2>$null
    if ($rl -match 'tcp:8000') { "configured" } else { $null }
} -Fix "Run: adb reverse tcp:8000 tcp:8000"

Test-Check "Phone can reach API (curl smoke test)" {
    $serial = $script:connectedDevice
    if ($serial -and $serial.Length -gt 2) {
        $r = adb -s "$serial" shell "curl -s -m 5 http://127.0.0.1:8000/health" 2>$null
        $rs = "$r".Trim()
        if ($rs -match '"ok"') { "reachable via ADB reverse" } else { $null }
    } else { $null }
} -Fix "Ensure ADB reverse is set and the backend is running"

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[Network]" -ForegroundColor White
# ---------------------------------------------------------------------------

Test-Check "Wi-Fi IP detected" {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -notmatch 'Loopback|Docker|WSL|vEthernet|Bluetooth|Hyper-V' -and
            $_.IPAddress -notmatch '^(169|172\.(1[6-9]|2\d|3[01]))'
        } |
        Sort-Object PrefixLength -Descending |
        Select-Object -First 1
    ).IPAddress
    if ($ip) { $ip } else { $null }
} -Optional -Fix "Connect to a Wi-Fi network for LAN-based device testing"

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[Flutter Packages]" -ForegroundColor White
# ---------------------------------------------------------------------------

Test-Check "package_config.json present (pub get ran)" {
    if (Test-Path "$ProjectRoot\.dart_tool\package_config.json") { "present" } else { $null }
} -Fix "Run: flutter pub get"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host -NoNewline "  Results: "
Write-Host -NoNewline "$pass PASS" -ForegroundColor Green
Write-Host -NoNewline "  /  "
Write-Host -NoNewline "$warn WARN" -ForegroundColor Yellow
Write-Host -NoNewline "  /  "
Write-Host           "$fail FAIL" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($fail -gt 0) {
    Write-Host "Fix the FAIL items above, then run this script again." -ForegroundColor Red
    Write-Host "Quick start command:  .\scripts\start_glossa.ps1" -ForegroundColor Yellow
    exit 1
} elseif ($warn -gt 0) {
    Write-Host "All required checks passed. Resolve WARNs for full functionality." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "All checks passed. Run the app with:" -ForegroundColor Green
    Write-Host "  .\scripts\start_glossa.ps1" -ForegroundColor Cyan
    exit 0
}

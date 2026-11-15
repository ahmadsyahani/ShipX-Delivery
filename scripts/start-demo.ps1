$ErrorActionPreference = 'Stop'
$demoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$demoMutexHasher = [Security.Cryptography.SHA256]::Create()
try {
    $demoMutexName = [BitConverter]::ToString($demoMutexHasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($demoRoot.ToLowerInvariant()))).Replace('-', '')
} finally {
    $demoMutexHasher.Dispose()
}
$demoMutex = [Threading.Mutex]::new($false, 'Local\ShipXDemo-' + $demoMutexName)
$demoLocked = $false
try {
    try {
        $demoLocked = $demoMutex.WaitOne(30000)
    } catch [Threading.AbandonedMutexException] {
        $demoLocked = $true
    }
    if (!$demoLocked) { throw 'Persiapan demo lain masih berjalan. Tunggu lalu jalankan lagi.' }
    $demoBackend = Join-Path $demoRoot 'backend'
    $demoPhp = (Get-Command php -ErrorAction Stop).Source
    $demoArtisan = Join-Path $demoBackend 'artisan'
    $demoRouter = Join-Path $demoBackend 'vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php'
    $demoLog = Join-Path $demoBackend 'storage/logs'

    if (!(Test-Path (Join-Path $demoBackend 'public/build/manifest.json'))) {
        throw 'Aset web belum tersedia. Jalankan npm run build dari folder backend.'
    }
    $demoCheckOutput = & $demoPhp (Join-Path $PSScriptRoot 'check-demo.php')
    if ($LASTEXITCODE -ne 0) { throw 'Pemeriksaan database/depot belum lolos.' }
    $demoCheck = $demoCheckOutput | ConvertFrom-Json
    if ($demoCheck.routing_url.TrimEnd('/') -ne 'http://127.0.0.1:8002') {
        throw 'Launcher demo lokal memerlukan konfigurasi routing http://127.0.0.1:8002.'
    }
    & (Join-Path $PSScriptRoot 'routing-demo/start.ps1')
    $demoRoad = Invoke-RestMethod 'http://127.0.0.1:8002/health' -TimeoutSec 5
    $demoLatitudeDelta = $demoCheck.depot.service_radius_m / 111320
    $demoLongitudeDelta = $demoLatitudeDelta / [Math]::Max(0.01, [Math]::Cos($demoCheck.depot.latitude * [Math]::PI / 180))
    if ($demoCheck.depot.latitude - $demoLatitudeDelta -lt $demoRoad.bbox[0] -or
        $demoCheck.depot.longitude - $demoLongitudeDelta -lt $demoRoad.bbox[1] -or
        $demoCheck.depot.latitude + $demoLatitudeDelta -gt $demoRoad.bbox[2] -or
        $demoCheck.depot.longitude + $demoLongitudeDelta -gt $demoRoad.bbox[3]) {
        throw 'Perluas peta melalui python scripts/routing-demo/prepare.py --depot, lalu jalankan launcher lagi.'
    }

    $demoListener = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($demoListener) {
        $demoHealth = Invoke-RestMethod 'http://127.0.0.1:8000/api/v1/health' -TimeoutSec 5
        if ($demoHealth.data.service -ne 'shipx-api' -or $demoHealth.data.status -ne 'ok') {
            throw 'Port 8000 digunakan layanan lain.'
        }
        if ($demoListener.LocalAddress -ne '0.0.0.0') {
            $demoExisting = Get-CimInstance Win32_Process -Filter "ProcessId = $($demoListener.OwningProcess)"
            if (!$demoExisting.CommandLine.Contains($demoBackend) -or $demoExisting.Name -ne 'php.exe') {
                throw 'Server port 8000 hanya menerima localhost. Jalankan server ShipX dengan --host=0.0.0.0.'
            }
            # Follow only the server's own ancestor chain to stop its artisan supervisor.
            $demoAncestor = $demoExisting
            for ($demoDepth = 0; $demoDepth -lt 4; $demoDepth++) {
                $demoAncestor = Get-CimInstance Win32_Process -Filter "ProcessId = $($demoAncestor.ParentProcessId)"
                if (!$demoAncestor) { break }
                if ($demoAncestor.Name -eq 'php.exe' -and $demoAncestor.CommandLine -match 'artisan"?\s+serve') {
                    Stop-Process -Id $demoAncestor.ProcessId
                    break
                }
            }
            if (Get-Process -Id $demoExisting.ProcessId -ErrorAction SilentlyContinue) {
                Stop-Process -Id $demoExisting.ProcessId
            }
            Wait-Process -Id $demoExisting.ProcessId -Timeout 5 -ErrorAction SilentlyContinue
            $demoListener = $null
        }
    }
    if (!$demoListener) {
        # Laravel's own development router serves the same public entry point as artisan serve.
        Start-Process -FilePath $demoPhp -ArgumentList @('-S', '0.0.0.0:8000', ('"' + $demoRouter + '"')) `
            -WorkingDirectory (Join-Path $demoBackend 'public') -WindowStyle Hidden `
            -RedirectStandardOutput (Join-Path $demoLog 'demo-api.log') `
            -RedirectStandardError (Join-Path $demoLog 'demo-api-error.log') | Out-Null
    }
    $demoReady = $false
    for ($demoAttempt = 0; $demoAttempt -lt 20; $demoAttempt++) {
        try {
            $demoHealth = Invoke-RestMethod 'http://127.0.0.1:8000/api/v1/health' -TimeoutSec 2
            if ($demoHealth.data.service -eq 'shipx-api' -and $demoHealth.data.status -eq 'ok') {
                $demoReady = $true
                break
            }
        } catch { }
        Start-Sleep -Milliseconds 250
    }
    if (!$demoReady) { throw 'Laravel belum siap. Periksa backend/storage/logs/demo-api-error.log.' }
    $demoScheduler = Get-CimInstance Win32_Process -Filter "Name = 'php.exe'" | Where-Object {
        $_.CommandLine.Contains($demoArtisan) -and $_.CommandLine -match 'schedule:work'
    }
    if (!$demoScheduler) {
        Start-Process -FilePath $demoPhp -ArgumentList @(('"' + $demoArtisan + '"'), 'schedule:work') `
            -WorkingDirectory $demoBackend -WindowStyle Hidden `
            -RedirectStandardOutput (Join-Path $demoLog 'demo-scheduler.log') `
            -RedirectStandardError (Join-Path $demoLog 'demo-scheduler-error.log') | Out-Null
    }
    Write-Output 'MySQL, routing dan Laravel siap. Scheduler aktif.'
    Write-Output 'Web admin http://127.0.0.1:8000/admin'
    $demoAddresses = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address }
    foreach ($demoAddress in $demoAddresses.IPv4Address.IPAddress) {
        Write-Output "API Wi-Fi http://${demoAddress}:8000/api/v1"
    }
    Write-Output 'HP harus menggunakan Wi-Fi yang sama. API APK perlu sesuai alamat laptop.'
} finally {
    if ($demoLocked) { $demoMutex.ReleaseMutex() }
    $demoMutex.Dispose()
}

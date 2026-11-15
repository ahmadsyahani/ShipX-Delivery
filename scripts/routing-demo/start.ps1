$ErrorActionPreference = 'Stop'
$routingWorkspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$routingWork = Join-Path $routingWorkspace 'backend/work/routing-demo'
$routingPython = Join-Path $routingWork 'python/python.exe'
$routingScript = Join-Path $PSScriptRoot 'server.py'
$routingGraph = $routingWork
$routingActive = Join-Path $routingWork 'active.json'
if (Test-Path -LiteralPath $routingActive) {
    $routingDirectory = (Get-Content -LiteralPath $routingActive -Raw | ConvertFrom-Json).directory
    $routingGraph = [IO.Path]::GetFullPath((Join-Path $routingWork $routingDirectory))
    if ($routingGraph -ne $routingWork -and !$routingGraph.StartsWith($routingWork + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Routing graph must stay inside the demo workspace.'
    }
}
if (!(Test-Path (Join-Path $routingGraph 'ready.json'))) {
    throw 'Run python scripts/routing-demo/prepare.py first.'
}
$routingRoadHash = (Get-FileHash -LiteralPath (Join-Path $routingGraph 'roads.osm.pbf') -Algorithm SHA256).Hash.ToLowerInvariant()
$routingServerHash = (Get-FileHash -LiteralPath $routingScript -Algorithm SHA256).Hash.ToLowerInvariant()
$routingHasher = [Security.Cryptography.SHA256]::Create()
try {
    $routingDataset = [BitConverter]::ToString($routingHasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($routingRoadHash + $routingServerHash))).Replace('-', '').ToLowerInvariant()
} finally {
    $routingHasher.Dispose()
}
$routingPortUsed = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() |
    Where-Object Port -eq 8002
if ($routingPortUsed) {
    $routingHealth = Invoke-RestMethod 'http://127.0.0.1:8002/health' -TimeoutSec 2
    if ($routingHealth.provider -eq 'valhalla-local' -and $routingHealth.dataset_id -eq $routingDataset) {
        Write-Output 'ShipX routing demo is already running.'
        return
    }
    $routingOwner = Get-NetTCPConnection -LocalPort 8002 -State Listen | Select-Object -First 1 -ExpandProperty OwningProcess
    $routingExisting = Get-CimInstance Win32_Process -Filter "ProcessId = $routingOwner"
    if ($routingHealth.provider -ne 'valhalla-local' -or $routingExisting.ExecutablePath -ne $routingPython -or !$routingExisting.CommandLine.Contains($routingScript)) {
        throw 'Port 8002 is already used by another service.'
    }
    Stop-Process -Id $routingOwner
    Wait-Process -Id $routingOwner -Timeout 5 -ErrorAction SilentlyContinue
}
$routingProcess = Start-Process -FilePath $routingPython -ArgumentList @('"' + $routingScript + '"') -WindowStyle Hidden -PassThru `
    -WorkingDirectory $routingWorkspace -RedirectStandardOutput (Join-Path $routingWork 'server.log') `
    -RedirectStandardError (Join-Path $routingWork 'server-error.log')
for ($routingAttempt = 0; $routingAttempt -lt 10; $routingAttempt++) {
    if ($routingProcess.HasExited) { throw 'Routing server stopped. Check backend/work/routing-demo/server-error.log.' }
    try {
        $routingHealth = Invoke-RestMethod 'http://127.0.0.1:8002/health' -TimeoutSec 2
        if ($routingHealth.provider -eq 'valhalla-local' -and $routingHealth.dataset_id -eq $routingDataset) {
            Write-Output 'ShipX routing demo is running on 127.0.0.1:8002.'
            return
        }
    } catch { }
    Start-Sleep -Milliseconds 250
}
throw 'Routing server did not become ready. Check backend/work/routing-demo/server-error.log.'

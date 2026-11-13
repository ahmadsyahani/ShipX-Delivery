$ErrorActionPreference = 'Stop'
$routingWorkspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$routingWork = Join-Path $routingWorkspace 'backend/work/routing-demo'
$routingPython = Join-Path $routingWork 'python/python.exe'
if (!(Test-Path (Join-Path $routingWork 'ready.json'))) {
    throw 'Run python scripts/routing-demo/prepare.py first.'
}
$routingPortUsed = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() |
    Where-Object Port -eq 8002
if ($routingPortUsed) {
    $routingHealth = Invoke-RestMethod 'http://127.0.0.1:8002/health' -TimeoutSec 2
    if ($routingHealth.provider -eq 'valhalla-local') {
        Write-Output 'ShipX routing demo is already running.'
        return
    }
    throw 'Port 8002 is already used by another service.'
}
$routingScript = Join-Path $PSScriptRoot 'server.py'
$routingProcess = Start-Process -FilePath $routingPython -ArgumentList @('"' + $routingScript + '"') -WindowStyle Hidden -PassThru `
    -WorkingDirectory $routingWorkspace -RedirectStandardOutput (Join-Path $routingWork 'server.log') `
    -RedirectStandardError (Join-Path $routingWork 'server-error.log')
for ($routingAttempt = 0; $routingAttempt -lt 10; $routingAttempt++) {
    if ($routingProcess.HasExited) { throw 'Routing server stopped. Check backend/work/routing-demo/server-error.log.' }
    try {
        $routingHealth = Invoke-RestMethod 'http://127.0.0.1:8002/health' -TimeoutSec 2
        if ($routingHealth.provider -eq 'valhalla-local') {
            Write-Output 'ShipX routing demo is running on 127.0.0.1:8002.'
            return
        }
    } catch { }
    Start-Sleep -Milliseconds 250
}
throw 'Routing server did not become ready. Check backend/work/routing-demo/server-error.log.'

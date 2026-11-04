$ErrorActionPreference = 'Stop'
$mobileRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\mobile'))
Push-Location $mobileRoot
try {
    if (-not (Test-Path -LiteralPath 'android')) {
        flutter create --platforms=android --org com.example --project-name shipx --no-pub .
        if ($LASTEXITCODE -ne 0) { throw 'flutter create gagal. Periksa izin SDK Flutter.' }
    }
    $mainManifest = Join-Path $mobileRoot 'android\app\src\main\AndroidManifest.xml'
    [xml]$main = Get-Content -LiteralPath $mainManifest -Raw
    $androidNs = 'http://schemas.android.com/apk/res/android'
    $hasInternet = $main.SelectNodes('/manifest/uses-permission') | Where-Object { $_.GetAttribute('name', $androidNs) -eq 'android.permission.INTERNET' }
    if (-not $hasInternet) {
        $permission = $main.CreateElement('uses-permission')
        $permission.SetAttribute('name', $androidNs, 'android.permission.INTERNET')
        [void]$main.manifest.AppendChild($permission)
        $main.Save($mainManifest)
    }
    $debugManifest = Join-Path $mobileRoot 'android\app\src\debug\AndroidManifest.xml'
    [xml]$debug = Get-Content -LiteralPath $debugManifest -Raw
    if (-not $debug.SelectSingleNode('/manifest/application')) {
        [void]$debug.manifest.AppendChild($debug.CreateElement('application'))
    }
    $debug.SelectSingleNode('/manifest/application').SetAttribute('usesCleartextTraffic', $androidNs, 'true')
    $debug.Save($debugManifest)
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get gagal.' }
    Write-Host 'Scaffolding Android siap. Lanjutkan flutter analyze dan flutter run.'
} finally {
    Pop-Location
}

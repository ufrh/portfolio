$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$run = Join-Path $root '.run'
$pidFile = Join-Path $run 'rojo.pid'
$watchFile = Join-Path $run 'watcher.pid'
foreach ($entry in @(@($pidFile,'rojo'), @($watchFile,'powershell'))) {
    $path = $entry[0]
    if (-not (Test-Path $path)) { continue }
    $idValue = 0
    [void][int]::TryParse((Get-Content $path -Raw).Trim(), [ref]$idValue)
    if ($idValue -gt 0) {
        $process = Get-Process -Id $idValue -ErrorAction SilentlyContinue
        if ($process -and $process.ProcessName -match ('^' + $entry[1])) {
            Stop-Process -Id $idValue -Force -ErrorAction SilentlyContinue
            Write-Host "[PORTFOLIO] Stopped $($entry[1]) PID $idValue"
        }
    }
    Remove-Item $path -Force -ErrorAction SilentlyContinue
}

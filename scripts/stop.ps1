$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pidPath = Join-Path $root '.run/rojo.pid'

if (-not (Test-Path $pidPath)) {
    Write-Host 'No tracked Rojo process to stop.'
    return
}
$processId = [int](Get-Content $pidPath -Raw).Trim()
$running = Get-Process -Id $processId -ErrorAction SilentlyContinue
if ($running -and $running.ProcessName -match '^rojo') {
    Stop-Process -Id $processId -Force
    Write-Host "Stopped Rojo (PID $processId)."
} else {
    Write-Host 'Tracked Rojo process was already stopped or PID was reused.'
}
Remove-Item $pidPath -Force

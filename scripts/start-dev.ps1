param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('outfit','inventory','backrooms')]
    [string]$Place
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) { throw 'Rojo not found on PATH. Install Rojo 7.x (or use Aftman).' }
& (Join-Path $PSScriptRoot 'stop-all.ps1')
$run = Join-Path $root '.run'
New-Item -ItemType Directory -Force -Path $run | Out-Null
$manifest = Join-Path $root "$Place.project.json"
$rojo = (Get-Command rojo).Source
$p = Start-Process -FilePath $rojo -ArgumentList @('serve', ('"' + $manifest + '"'), '--port', '34876') -WorkingDirectory $root -RedirectStandardOutput (Join-Path $run 'rojo.log') -RedirectStandardError (Join-Path $run 'rojo.err.log') -PassThru
Set-Content (Join-Path $run 'rojo.pid') $p.Id
Write-Host "[PORTFOLIO] Serving $Place on localhost:34876 (PID $($p.Id))" -ForegroundColor Green
Write-Host '[PORTFOLIO] Open the corresponding Roblox Studio place before connecting Rojo.'
if (-not (Test-Path (Join-Path $root '.git'))) {
    Write-Host '[PORTFOLIO] ZIP extraction: no .git found. Git watcher disabled. Clone the repo for live Git sync.' -ForegroundColor Yellow
}

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('outfit-studio', 'inventory-equipment', 'backrooms-generator')]
    [string]$Place
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$project = Join-Path $root "places/$Place/default.project.json"
if (-not (Test-Path $project)) { throw "Missing Rojo project: $project" }
if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) { throw 'Rojo is not on PATH. Install Rojo or run aftman install.' }

& (Join-Path $PSScriptRoot 'stop.ps1')

$runDir = Join-Path $root '.run'
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$logPath = Join-Path $runDir 'rojo.log'
$errPath = Join-Path $runDir 'rojo.err.log'
$process = Start-Process -FilePath (Get-Command rojo).Source -ArgumentList @('serve', $project, '--port', '34872') -PassThru -WorkingDirectory $root -RedirectStandardOutput $logPath -RedirectStandardError $errPath
Set-Content -Path (Join-Path $runDir 'rojo.pid') -Value $process.Id
Write-Host "Started Rojo for $Place (PID $($process.Id)) at localhost:34872."
Write-Host "Open the matching Roblox Studio place and connect the Rojo plugin."

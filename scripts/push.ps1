param([Parameter(Mandatory=$true)][string]$Message)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Test-Path '.git')) { throw 'This folder is not a Git clone. Clone https://github.com/ufrh/portfolio.git to push.' }
$branch = (& git branch --show-current).Trim()
if ($branch -ne 'main') { throw "Expected branch main; found '$branch'." }
& git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
& git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host '[PORTFOLIO] No changes to push.'; exit 0 }
if ($LASTEXITCODE -ne 1) { throw 'git diff failed' }
& git commit -m $Message
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
& git push origin main
if ($LASTEXITCODE -ne 0) { throw 'git push failed' }
Write-Host '[PORTFOLIO] Pushed to origin/main.' -ForegroundColor Green

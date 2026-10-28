param(
    [Parameter(Mandatory = $true)]
    [string]$Message
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host 'No changes to commit.'; return }
if ($LASTEXITCODE -ne 1) { throw 'git diff failed' }

git commit -m $Message
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
git push
if ($LASTEXITCODE -ne 0) { throw 'git push failed' }

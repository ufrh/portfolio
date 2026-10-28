param([int]$IntervalSeconds = 3)
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Test-Path '.git') -or -not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '[PORTFOLIO] Git watcher unavailable (use a git clone for live updates).' -ForegroundColor Yellow
    exit 0
}
$run = Join-Path $root '.run'
New-Item -ItemType Directory -Force -Path $run | Out-Null
Set-Content (Join-Path $run 'watcher.pid') $PID
Write-Host '[PORTFOLIO] Watching origin/main; only pulls when local tree is clean.' -ForegroundColor Cyan
try {
    while ($true) {
        try {
            $branch = (& git branch --show-current).Trim()
            $dirty = @(& git status --porcelain)
            if ($branch -eq 'main' -and $dirty.Count -eq 0) {
                & git fetch --quiet origin main 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $ahead = [int]((& git rev-list 'origin/main..HEAD' --count).Trim())
                    $behind = [int]((& git rev-list 'HEAD..origin/main' --count).Trim())
                    if ($ahead -eq 0 -and $behind -gt 0) {
                        & git pull --ff-only origin main
                        if ($LASTEXITCODE -eq 0) { Write-Host "[PORTFOLIO] Pulled $behind new commit(s)." -ForegroundColor Green }
                    }
                }
            }
        } catch { Write-Host "[PORTFOLIO] Watcher warning: $($_.Exception.Message)" -ForegroundColor Yellow }
        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    Remove-Item (Join-Path $run 'watcher.pid') -Force -ErrorAction SilentlyContinue
}

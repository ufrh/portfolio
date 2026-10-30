@echo off
setlocal
cd /d "%~dp0"
if not exist ".run" mkdir ".run"
where rojo >nul 2>nul
if errorlevel 1 (
    echo Rojo is unavailable. Run: rokit install
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root=(Get-Location).Path; $pidFile=Join-Path $root '.run\rojo.pid'; if(Test-Path $pidFile){$old=[int](Get-Content $pidFile -Raw); if(Get-Process -Id $old -ErrorAction SilentlyContinue){Write-Host 'Rojo already started; use STOP.bat first.'; exit 1}}; $exe=(Get-Command rojo).Source; $p=Start-Process -FilePath $exe -ArgumentList @('serve','outfit.project.json','--port','34876') -WorkingDirectory $root -RedirectStandardOutput (Join-Path $root '.run\rojo.log') -RedirectStandardError (Join-Path $root '.run\rojo.err.log') -PassThru; Set-Content $pidFile $p.Id; Start-Sleep -Milliseconds 700; if($p.HasExited){Get-Content (Join-Path $root '.run\rojo.err.log'); Remove-Item $pidFile -Force; exit 1}; Write-Host ('Outfit Studio Rojo running on localhost:34876 (PID ' + $p.Id + ')')"
if errorlevel 1 pause

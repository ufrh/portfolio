@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$pidFile=Join-Path (Get-Location).Path '.run\rojo.pid'; if(!(Test-Path $pidFile)){Write-Host 'No tracked Rojo process.'; exit}; $idValue=0; if([int]::TryParse((Get-Content $pidFile -Raw).Trim(),[ref]$idValue)){ $p=Get-Process -Id $idValue -ErrorAction SilentlyContinue; if($p -and $p.ProcessName -match '^rojo'){Stop-Process -Id $idValue -Force; Write-Host 'Stopped Outfit Studio Rojo.'} }; Remove-Item $pidFile -Force -ErrorAction SilentlyContinue"

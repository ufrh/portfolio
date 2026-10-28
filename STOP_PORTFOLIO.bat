@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\stop-all.ps1"
if errorlevel 1 pause

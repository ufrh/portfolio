@echo off
setlocal
cd /d "%~dp0"
title PORTFOLIO - Development
set "PLACE=%~1"
if "%PLACE%"=="" (
    echo Select Roblox showcase place:
    echo   1. Outfit Studio
    echo   2. Inventory and Equipment
    echo   3. Backrooms Generator
    set /p PLACE=Choice [1-3]:
)
if /i "%PLACE%"=="1" set "PLACE=outfit"
if /i "%PLACE%"=="2" set "PLACE=inventory"
if /i "%PLACE%"=="3" set "PLACE=backrooms"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\start-dev.ps1" -Place "%PLACE%"
if errorlevel 1 (
    echo [PORTFOLIO] Startup failed.
    pause
    exit /b 1
)
echo.
echo [PORTFOLIO] Rojo running. Ctrl+C stops this Git watcher only.
echo [PORTFOLIO] Use STOP_PORTFOLIO.bat to stop Rojo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\live-sync.ps1"
pause

@echo off
setlocal
cd /d "%~dp0"
set /p "MSG=Commit message: "
if "%MSG%"=="" set "MSG=Update portfolio"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\push.ps1" -Message "%MSG%"
pause

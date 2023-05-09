@echo off
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
PowerShell -NoProfile -ExecutionPolicy Bypass -file ".\maintenance_script.ps1"
pause

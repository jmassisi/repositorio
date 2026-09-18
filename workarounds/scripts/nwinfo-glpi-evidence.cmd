@echo off
net session >nul 2>&1
if errorlevel 1 (
    powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"C:\repositorio\workarounds\scripts\nwinfo-glpi-evidence.ps1\"' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\workarounds\scripts\nwinfo-glpi-evidence.ps1"
@echo off
:: Lanzador de Reset-AnyDesk.ps1
:: Eleva privilegios y bypasea ExecutionPolicy sin cambiarla globalmente

net session >nul 2>&1
if errorlevel 1 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reset-AnyDesk.ps1"
pause

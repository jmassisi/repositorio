@echo off
:: Lanzador de actualizar-default.ps1
:: Eleva privilegios y bypasea ExecutionPolicy sin cambiarla globalmente

net session >nul 2>&1
if errorlevel 1 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0actualizar-default.ps1"
pause

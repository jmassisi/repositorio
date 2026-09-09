@echo off
:: Lanzador de instalar-aplicaciones.ps1
:: Eleva privilegios y bypasea ExecutionPolicy sin cambiarla globalmente
:: Usa Windows PowerShell (5.1) integrado (decision 2026-09-09: no migrar a pwsh)

net session >nul 2>&1
if errorlevel 1 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar-aplicaciones.ps1"
pause
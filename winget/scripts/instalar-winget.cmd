@echo off
:: Lanzador de instalar-winget.ps1
:: Eleva privilegios y bypasea ExecutionPolicy sin cambiarla globalmente
:: Usa PowerShell 7 (pwsh) en lugar de Windows PowerShell 5.1

net session >nul 2>&1
if errorlevel 1 (
    echo Solicitando permisos de administrador...
    pwsh -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar-winget.ps1"
pause
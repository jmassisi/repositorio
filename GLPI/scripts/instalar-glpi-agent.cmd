@echo off
:: Lanzador de instalar-glpi-agent.ps1
:: Eleva privilegios y bypasea ExecutionPolicy sin cambiarla globalmente

net session >nul 2>&1
if errorlevel 1 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

start powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar-glpi-agent.ps1"
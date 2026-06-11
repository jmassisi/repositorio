@echo off
:: Lanzador de Instalar-Office.ps1
:: Abre una sola ventana de PowerShell elevada

powershell -NoProfile -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -Command Set-Location \"%~dp0\"; & \"%~dp0Instalar-Office.ps1\"' -Verb RunAs"

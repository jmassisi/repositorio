@echo off
:: ============================================================
::  Instalacion silenciosa - GLPI Agent
::  Servidor: https://soporte.igeek.ar
::  TAG: Staging (pendiente de clasificacion en GLPI)
::
::  El instalador se descarga automaticamente desde GitHub.
::
::  Requisitos:
::    - Ejecutar como Administrador
::    - Acceso a internet (github.com)
:: ============================================================
::  Version: 1.2  (2026-04-27)
::
::  TODO: Reemplazar version fija por consulta dinamica a la API de
::        GitHub Releases, validando compatibilidad con la version
::        del servidor GLPI antes de descargar.
::        Ref: https://github.com/glpi-project/glpi-agent/releases

set "GLPI_AGENT_VERSION=1.17"
set "MSI_NAME=GLPI-Agent-%GLPI_AGENT_VERSION%-x64.msi"
set "DOWNLOAD_URL=https://github.com/glpi-project/glpi-agent/releases/download/%GLPI_AGENT_VERSION%/%MSI_NAME%"
set "MSI_FILE=%TEMP%\%MSI_NAME%"

:: Verificar privilegios de administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Este script requiere privilegios de administrador.
    echo Clic derecho sobre el archivo ^> Ejecutar como administrador
    pause
    exit /b 1
)

echo Descargando %MSI_NAME% desde GitHub...
curl -L --fail --silent --show-error --ssl-no-revoke "%DOWNLOAD_URL%" -o "%MSI_FILE%"
if %errorlevel% neq 0 (
    echo [ERROR] No se pudo descargar el instalador.
    echo URL: %DOWNLOAD_URL%
    echo Verifique su conexion a internet o descargue manualmente desde:
    echo https://github.com/glpi-project/glpi-agent/releases
    pause
    exit /b 1
)

echo Instalando %MSI_NAME%...
echo.

msiexec /i "%MSI_FILE%" /quiet /norestart ^
    SERVER="https://soporte.igeek.ar" ^
    RUNNOW=1 ^
    EXECMODE=1 ^
    ADD_FIREWALL_EXCEPTION=1 ^
    AGENTMONITOR=1 ^
    TAG="Staging"

set INSTALL_CODE=%errorlevel%
del /f /q "%MSI_FILE%" >nul 2>&1

if %INSTALL_CODE% equ 0 (
    echo [OK] Instalacion completada correctamente.
    echo El agente reportara al servidor en los proximos minutos.
    echo Entidad asignada: Staging (pendiente de clasificacion)
) else (
    echo [ERROR] La instalacion fallo con codigo: %INSTALL_CODE%
    echo Revise el log en: C:\Windows\Temp\glpi-agent-install.log
)

echo.
pause

# fix-alias-winget.ps1
# WORKAROUND: repara el comando winget cuando el alias de WindowsApps esta roto.
# NO toca el sistema: crea un shim (winget.cmd) en %USERPROFILE%\bin y agrega
# esa carpeta al PATH de usuario. No requiere admin.
# Requiere: PowerShell 7 (pwsh).
# Reversible: ver winget/docs/winget-alias-workaround.md (seccion "Deshacer").

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }

Write-Step "Diagnostico previo"
$pkg = Get-AppxPackage Microsoft.DesktopAppInstaller | Select-Object -First 1
if (-not $pkg -or -not $pkg.InstallLocation) {
    Write-Host "[-] El paquete Microsoft.DesktopAppInstaller no esta instalado (o no se puede leer)." -ForegroundColor Red
    Write-Host "    Este workaround no aplica. Instalalo desde la Microsoft Store." -ForegroundColor Yellow
    exit 1
}
$wingetExe = Join-Path $pkg.InstallLocation 'winget.exe'
if (-not (Test-Path $wingetExe)) {
    Write-Host "[-] No se encontro winget.exe en: $wingetExe" -ForegroundColor Red
    exit 1
}
Write-Host "[+] Motor winget encontrado: $wingetExe" -ForegroundColor Green

Write-Step "Creando shim winget.cmd en %USERPROFILE%\bin"
$bin = Join-Path $env:USERPROFILE 'bin'
New-Item -ItemType Directory -Force -Path $bin | Out-Null
$shim = @'
@echo off
setlocal
for /f "usebackq delims=" %%i in (`pwsh -NoProfile -Command "(Get-AppxPackage Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue).InstallLocation"`) do set "WINGET_DIR=%%i"
if not defined WINGET_DIR exit /b 1
"%WINGET_DIR%\winget.exe" %*
'@
$shimPath = Join-Path $bin 'winget.cmd'
Set-Content -Path $shimPath -Value $shim -Encoding ASCII
Write-Host "[+] Shim creado: $shimPath" -ForegroundColor Green

Write-Step "Agregando $bin al PATH de usuario"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($null -eq $userPath) { $userPath = '' }
if ($userPath -notlike "*$bin*") {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $bin), 'User')
    Write-Host "[+] PATH de usuario actualizado." -ForegroundColor Green
} else {
    Write-Host "[=] $bin ya estaba en el PATH de usuario. Nada que hacer." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Workaround aplicado. IMPORTANTE: abri una terminal NUEVA y verificá:" -ForegroundColor White
Write-Host "    winget --version" -ForegroundColor Green
Write-Host "    where.exe winget" -ForegroundColor Green
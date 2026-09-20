# menu: keyboard-leds-install (Instalar Keyboard LEDs)
# keyboard-leds-install.ps1
# Instala Keyboard LEDs 2.7.1.59 (KARPOLAN) desde el distribuidor local del repo:
#     workarounds/bin/keyboard-leds-2.7.1.59.exe   (instalador NSIS original)
# La URL oficial (keyboard-leds.com) esta muerta (404); el binario viaja en el repo
# para no depender de mirrors. Ver workarounds/docs/workarounds.md.
# Requiere: Administrador (el menu elevado via menu.cmd).
# Idempotente: detecta instalacion previa y pide confirmacion antes de re-instalar.

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$root    = Split-Path $PSScriptRoot -Parent
$logDir  = Join-Path $root 'logs'
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logFile = Join-Path $logDir "keyboard-leds-install_$ts.log"
if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    Add-Content -Path $logFile -Value "[$ts][$level] $msg" -Encoding UTF8
    if ($level -eq 'ERROR') { Write-Host "[-] $msg" -ForegroundColor Red }
}

$installer = Join-Path $root 'bin\keyboard-leds-2.7.1.59.exe'

function Find-InstalledExe {
    $dirs = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Keyboard LEDs'),
        (Join-Path ${env:ProgramFiles} 'Keyboard LEDs'),
        (Join-Path ${env:ProgramFiles(x86)} 'Keyboard-Leds'),
        (Join-Path ${env:ProgramFiles} 'Keyboard-Leds')
    )
    foreach ($d in $dirs | Select-Object -Unique) {
        if (Test-Path $d) {
            $exe = Get-ChildItem -Path $d -Filter '*.exe' -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^Keyboard' } | Select-Object -First 1
            if ($exe) { return $exe.FullName }
        }
    }
    $null
}

function Find-UninstallEntry {
    $keys = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    foreach ($k in $keys) {
        foreach ($item in (Get-Item $k -ErrorAction SilentlyContinue)) {
            $entry = $item.GetValue('DisplayName')
            $loc    = $item.GetValue('InstallLocation')
            if ($entry -and $entry -match 'Keyboard Leds|Keyboard LEDs') {
                return @{ Name = $entry; Uninstall = $item.PSPath; Location = $loc }
            }
        }
    }
    $null
}

Write-Host "================================================"
Write-Host " KEYBOARD LEDS 2.7.1.59  (KARPOLAN)"
Write-Host " Host   : $env:COMPUTERNAME"
Write-Host "================================================"
Write-Log "Inicio"
Write-Log "Host: $env:COMPUTERNAME | Usuario: $env:USERDOMAIN\$env:USERNAME"

# --- 1. Verificar que existe el instalador local ---
if (-not (Test-Path $installer)) {
    Write-Log "Instalador no encontrado en $installer" 'ERROR'
    Write-Host "[-] No se encontro el instalador en el repo: $installer" -ForegroundColor Red
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}
Write-Host "`n[+] Instalador local: $installer" -ForegroundColor Green
Write-Log "Instalador presente: $installer"

# --- 2. Idempotencia: detectar instalacion previa ---
$exe   = Find-InstalledExe
$entry = Find-UninstallEntry
if ($exe -or $entry) {
    Write-Host "`n[=] Keyboard LEDs ya esta instalado:" -ForegroundColor Yellow
    if ($exe)   { Write-Host "    Exe    : $exe" -ForegroundColor Yellow }
    if ($entry) { Write-Host "    Uninst : $($entry.Uninstall)" -ForegroundColor Yellow }
    $re = Read-Host '    Re-instalar de todos modos? (S/N)'
    if ($re -notmatch '^[sS]') {
        Write-Log "Ya instalado, sin cambios."
        Read-Host "`nPresiona Enter para cerrar"
        exit 0
    }
    Write-Log "Ya instalado, re-instalacion confirmada por el operador."
}

# --- 3. Proceso en ejecucion ---
$proc = Get-Process -Name 'KeyboardLeds' -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "`n[=] Keyboard LEDs esta en ejecucion; se cerrara antes de instalar." -ForegroundColor Yellow
    $proc | Stop-Process -Force
    Write-Log "Proceso KeyboardLeds detenido."
}

# --- 4. Instalar silenciosamente (NSIS /S) ---
Write-Host "`n==> Instalando silenciosamente (NSIS /S)..." -ForegroundColor Cyan
Write-Log "Invocando: $installer /S"
try {
    $p = Start-Process -FilePath $installer -ArgumentList '/S' -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        Write-Log "Instalador termino con exit code $($p.ExitCode)" 'ERROR'
        Write-Host "`n[-] El instalador termino con codigo $($p.ExitCode)." -ForegroundColor Red
    } else {
        Write-Host "   [i] Instalador finalizado (exit 0)." -ForegroundColor Gray
        Write-Log "Instalador finalizado con exit 0."
    }
} catch {
    Write-Log "Error al ejecutar el instalador: $($_.Exception.Message)" 'ERROR'
    Write-Host "`n[-] Error al ejecutar el instalador: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

# --- 5. Verificar resultado final visible ---
Write-Host "`n==> Verificando instalacion" -ForegroundColor Cyan
$exeNuevo = Find-InstalledExe
if ($exeNuevo) {
    Write-Host "   [+] Keyboard LEDs instalado en: $exeNuevo" -ForegroundColor Green
    Write-Log "Verificado: $exeNuevo"
} else {
    Write-Host "   [?] No se confirmo el exe por defecto. Revisa tambien:" -ForegroundColor Yellow
    Write-Host "       Panel de control -> Programas (Keyboard LEDs)" -ForegroundColor Gray
    Write-Log "Verificacion por exe: no encontrado (puede instalarse en otra ruta)"
}

Write-Host "`n================================================"
Write-Host "   Resumen:"
Write-Host "   Instalador : $installer"
Write-Host "   SHA-256    : 4b2e12eea8116f0670919dc0b782019776dbec09614e821132636679421c50f5"
Write-Host "   Log        : $logFile"
Write-Host "================================================"
Write-Log "Fin."
Write-Host ""
Read-Host "Presiona Enter para cerrar"
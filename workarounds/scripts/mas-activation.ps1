# menu: mas-activation (Activador MAS)
# mas-activation.ps1
# Ejecuta el activador MAS (Microsoft Activation Scripts) de MassGrave:
#     irm https://get.activated.win | iex
# Repo: https://github.com/massgravel/Microsoft-Activation-Scripts
# Web : https://massgrave.dev
# Descarga y ejecuta el script remoto (terceros) en memoria; no deja archivos locales.
# Requiere: Administrador (el menu se lanza elevado via menu.cmd) y conexion a internet.
# Idempotente: verifica el estado de activacion previo y, si ya esta activado,
# avisa y pide confirmacion antes de correr igual.

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$root    = Split-Path $PSScriptRoot -Parent
$logDir  = Join-Path $root 'logs'
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logFile = Join-Path $logDir "mas-activation_$ts.log"
if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    Add-Content -Path $logFile -Value "[$ts][$level] $msg" -Encoding UTF8
    if ($level -eq 'ERROR') { Write-Host "[-] $msg" -ForegroundColor Red }
}

function Show-ActivationState {
    $prod = Get-CimInstance -ClassName SoftwareLicensingProduct |
        Where-Object { $_.Name -like 'Windows*' -and $_.PartialProductKey }
    if (-not $prod) {
        Write-Host "   [-] No se encontro producto Windows con clave (licencia no activable por esta via?)" -ForegroundColor Yellow
        return
    }
    foreach ($p in $prod) {
        $estado = switch ($p.LicenseStatus) {
            1 { 'ACTIVADO' }
            0 { 'sin licencia' }
            2 { 'gracia OOB' }
            3 { 'gracia OOT' }
            4 { 'gracia no genuina' }
            6 { 'gracia extendida' }
            default { "estado $($p.LicenseStatus)" }
        }
        if ($p.LicenseStatus -eq 1) {
            Write-Host "   [+] $($p.Name) -> $estado" -ForegroundColor Green
        } else {
            Write-Host "   [=] $($p.Name) -> $estado" -ForegroundColor Yellow
        }
    }
}

Write-Host "================================================"
Write-Host " MAS - ACTIVADOR WINDOWS  (get.activated.win)"
Write-Host " Host   : $env:COMPUTERNAME"
Write-Host "================================================"
Write-Log "Inicio"
Write-Log "Host: $env:COMPUTERNAME | Usuario: $env:USERDOMAIN\$env:USERNAME"

# --- 1. Idempotencia: verificar activacion previa ---
Write-Host "`n==> Estado de activacion actual" -ForegroundColor Cyan
$prod = Get-CimInstance -ClassName SoftwareLicensingProduct |
    Where-Object { $_.Name -like 'Windows*' -and $_.PartialProductKey }
Show-ActivationState

$yaActivado = $prod | Where-Object { $_.LicenseStatus -eq 1 } | Select-Object -First 1
if ($yaActivado) {
    Write-Host "`n   [=] Windows ya parece activado." -ForegroundColor Yellow
    $re = Read-Host '   Correr MAS de todos modos? (S/N)'
    if ($re -notmatch '^[sS]') {
        Write-Log "Ya activado, sin cambios."
        Read-Host "`nPresiona Enter para cerrar"
        exit 0
    }
    Write-Log "Ya activado, re-ejecucion confirmada por el operador."
}

# --- 2. Confirmacion antes de descargar codigo de terceros ---
Write-Host "`n==> Descargar y ejecutar get.activated.win (script de terceros: MAS, MassGrave)" -ForegroundColor Cyan
Write-Host "   Se abrira el menu interactivo de MAS (HWID / Ohook / KMS38 / Online KMS)." -ForegroundColor Gray
$ok = Read-Host '   Ejecutar ahora? (S/N)'
if ($ok -notmatch '^[sS]') {
    Write-Log "Cancelado por el operador."
    Read-Host "`nPresiona Enter para cerrar"
    exit 0
}

# --- 3. Ejecutar el oneliner ---
Write-Host "`n==> Ejecutando: irm https://get.activated.win | iex" -ForegroundColor Cyan
Write-Log "Ejecutando oneliner MAS"
$ea = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $script = irm https://get.activated.win
    if ($null -eq $script -or [string]::IsNullOrEmpty($script)) {
        Write-Log "No se obtuvo contenido de get.activated.win" 'ERROR'
        Write-Host "   [-] No se pudo descargar el script (revisa conexion)." -ForegroundColor Red
    } else {
        iex $script
        Write-Log "Oneliner MAS finalizado (retorno normal)"
    }
} catch {
    Write-Log "Error durante MAS: $($_.Exception.Message)" 'ERROR'
    Write-Host "`n   [-] Error durante la ejecucion de MAS." -ForegroundColor Red
} finally {
    $ErrorActionPreference = $ea
}

# --- 4. Resultado final visible ---
Write-Host "`n==> Resultado: re-verificando activacion" -ForegroundColor Cyan
Show-ActivationState

Write-Host "`n   Verificacion adicional (opcional):" -ForegroundColor Gray
Write-Host "       slmgr /xpr"
Write-Host "       slmgr /dli"

Write-Host "`n================================================"
Write-Host "   Resumen:"
Write-Host "   Script      : MAS (get.activated.win)"
Write-Host "   Repo        : https://github.com/massgravel/Microsoft-Activation-Scripts"
Write-Host "   Web         : https://massgrave.dev"
Write-Host "   Log         : $logFile"
Write-Host "================================================"
Write-Log "Fin."
Write-Host ""
Read-Host "Presiona Enter para cerrar"
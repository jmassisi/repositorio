# actualizar-default.ps1
# Ejecuta defprof sobre el usuario molde elegido
# Requiere: defprof.exe en C:\IT\  |  Ejecutar como Administrador
# Log en: C:\repositorio\logs\defprof\

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logDir  = 'C:\repositorio\logs\defprof'
$logFile = "$logDir\defprof_$ts.log"
$defprof = 'C:\IT\defprof.exe'

if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    $line = "[$ts][$level] $msg"
    Write-Host "   $msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

# ── Header ───────────────────────────────────────────────────
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8
Add-Content -Path $logFile -Value " actualizar-default  |  $ts"                      -Encoding UTF8
Add-Content -Path $logFile -Value " Host   : $env:COMPUTERNAME"                      -Encoding UTF8
Add-Content -Path $logFile -Value " Usuario: $env:USERDOMAIN\$env:USERNAME"          -Encoding UTF8
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8

# ── Verificar defprof ────────────────────────────────────────
if (-not (Test-Path $defprof)) {
    Write-Log "No se encontro defprof.exe en $defprof" 'ERROR'
    Write-Host "`n   Descargarlo de https://www.forensit.com/downloads.html y copiarlo a C:\IT\"
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

# ── Listar usuarios disponibles ──────────────────────────────
$excluir  = @('Administrator', 'DefaultAccount', 'Guest', 'WDAGUtilityAccount')
$usuarios = Get-LocalUser | Where-Object { $excluir -notcontains $_.Name -and $_.Name -ne $env:USERNAME }

Write-Host ""
Write-Host "Cuenta activa (no disponible como molde): $env:USERNAME"
Write-Host ""
Write-Host "Usuarios disponibles como molde:"
$usuarios | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host ""

$molde = Read-Host "Nombre del usuario molde (debe tener sesion cerrada)"

if (-not $molde) {
    Write-Log "No se ingreso ningun usuario." 'ERROR'
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

Write-Log "Usuario molde seleccionado: $molde"

# ── Ejecutar defprof ─────────────────────────────────────────
Write-Host ""
Write-Host "Ejecutando defprof sobre '$molde'..."
Write-Host ""

try {
    $output = & $defprof $molde /q 2>&1
    $output | ForEach-Object { Write-Log $_ }

    Write-Log "defprof completado para: $molde"
    Write-Host ""
    Write-Host "   Listo. Los nuevos usuarios seran clones de '$molde'."
} catch {
    Write-Log "Error al ejecutar defprof: $_" 'ERROR'
}

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
Write-Host ""
Write-Host "Log guardado en:"
Write-Host "   $logFile"
Write-Host ""
Read-Host "Presiona Enter para cerrar"

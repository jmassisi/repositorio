# defprof.ps1
# Ejecuta defprof sobre el usuario molde elegido
# Usa defprof.exe desde C:\repositorio\defprof\bin\ con verificacion de integralidad
# Requiere: ejecutar como Administrador | Log en: C:\repositorio\logs\defprof\

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logDir  = 'C:\repositorio\logs\defprof'
$logFile = "$logDir\defprof_$ts.log"
$defprof = 'C:\repositorio\defprof\bin\defprof.exe'

$DEFPROF_EXE_HASH  = '1a0574aeca4b95c3aa54813182ca41254f15f32fddfe0406756759bca0fc5949'

if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    $line = "[$ts][$level] $msg"
    Write-Host "   $msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

# ── Header ───────────────────────────────────────────────────
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8
Add-Content -Path $logFile -Value " defprof  |  $ts"                      -Encoding UTF8
Add-Content -Path $logFile -Value " Host   : $env:COMPUTERNAME"                      -Encoding UTF8
Add-Content -Path $logFile -Value " Usuario: $env:USERDOMAIN\$env:USERNAME"          -Encoding UTF8
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8

# ── Verificacion de integridad de defprof.exe ────────────────
function Test-DefProfIntegrity {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return $false }

    $hashOk = $false
    try {
        $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
        $hashOk = ($actual -eq $DEFPROF_EXE_HASH)
        if ($hashOk) {
            Write-Log "Hash SHA-256 OK: $actual"
        } else {
            Write-Log "Hash SHA-256 no coincide. Actual: $actual" 'WARN'
        }
    } catch {
        Write-Log "No se pudo calcular el hash: $_" 'WARN'
    }

    $sigOk = $false
    try {
        $sig = Get-AuthenticodeSignature -FilePath $Path
        $sigOk = ($sig.Status -eq 'Valid') -and ($sig.SignerCertificate.Subject -match 'ForensiT Limited')
        if ($sigOk) {
            Write-Log "Firma Authenticode OK: $($sig.SignerCertificate.Subject)"
        } else {
            Write-Log "Firma Authenticode invalida: $($sig.Status)" 'WARN'
        }
    } catch {
        Write-Log "No se pudo verificar la firma: $_" 'WARN'
    }

    return ($hashOk -and $sigOk)
}

# ── Verificacion de defprof ───────────────────────────────────
function Ensure-DefProf {

    if (-not (Test-Path $defprof)) {
        Write-Log "Busqueda de ${defprof}: no existe." 'ERROR'
        Write-Host "`n   [-] No se encontro defprof.exe en el repositorio (${defprof})." -ForegroundColor Red
        Write-Host "   [!] Actualiza el repositorio desde el menu ([A]) y relanza el script." -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }

    if (-not (Test-DefProfIntegrity $defprof)) {
        Write-Log "defprof.exe del repositorio no supero la verificacion de integridad." 'ERROR'
        Write-Host "`n   [-] El defprof.exe del repositorio no supero la verificacion (hash/firma)." -ForegroundColor Red
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }

    Write-Log "defprof.exe verificado. Ejecutando desde el repositorio."
}

Ensure-DefProf

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

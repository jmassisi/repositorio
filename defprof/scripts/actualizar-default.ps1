# actualizar-default.ps1
# Ejecuta defprof sobre el usuario molde elegido
# Descarga y verifica defprof.exe automaticamente si falta o no es confiable
# Requiere: ejecutar como Administrador | Log en: C:\repositorio\logs\defprof\

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logDir  = 'C:\repositorio\logs\defprof'
$logFile = "$logDir\defprof_$ts.log"
$defprof = 'C:\IT\defprof.exe'

$DEFPROF_URL       = 'https://www.forensit.com/Downloads/DefProf.msi'
$DEFPROF_EXE_HASH  = '1a0574aeca4b95c3aa54813182ca41254f15f32fddfe0406756759bca0fc5949'
$TMP_DIR           = "$env:TEMP\defprof_setup"

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

# ── Descarga y preparacion de defprof ─────────────────────────
function Ensure-DefProf {

    if (Test-Path $defprof) {
        if (Test-DefProfIntegrity $defprof) {
            Write-Log "defprof.exe presente y verificado."
            return
        }
        Write-Log "defprof.exe existente no supero la verificacion. Se reinstalara." 'WARN'
    }

    Write-Host ""
    Write-Log "Descargando DefProf desde ForensiT..."
    Write-Host "   Descarga: $DEFPROF_URL" -ForegroundColor Yellow

    $msiPath = "$TMP_DIR\DefProf.msi"
    if (Test-Path $TMP_DIR) { Remove-Item $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item $TMP_DIR -ItemType Directory -Force | Out-Null

    try {
        & curl.exe -L -o $msiPath $DEFPROF_URL
        if ($LASTEXITCODE -ne 0) { throw "curl.exe devolvio codigo $LASTEXITCODE" }
        $msiSize = (Get-Item $msiPath).Length
        if ($msiSize -lt 200KB) {
            throw "Archivo descargado demasiado pequeno ($([Math]::Round($msiSize/1KB)) KB)"
        }
        Write-Log "MSI descargado OK ($([Math]::Round($msiSize/1KB)) KB)"
    } catch {
        Write-Log "Error descargando DefProf: $_" 'ERROR'
        Write-Host "`n   [-] No se pudo descargar DefProf automaticamente." -ForegroundColor Red
        Write-Host "   [!] Descargalo manualmente de https://www.forensit.com/downloads.html" -ForegroundColor Yellow
        Write-Host "   [!] y copia defprof.exe a C:\IT\, luego relanza el script." -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }

    Write-Host ""
    Write-Log "Extrayendo DefProf.exe del MSI..."
    $extractDir = "$TMP_DIR\extracted"
    New-Item $extractDir -ItemType Directory -Force | Out-Null

    try {
        $proc = Start-Process -FilePath 'msiexec.exe' `
                              -ArgumentList "/a `"$msiPath`" /qn TARGETDIR=`"$extractDir`"" `
                              -Wait -PassThru -NoNewWindow
        Write-Log "msiexec exit code: $($proc.ExitCode)"
    } catch {
        Write-Log "Error extrayendo el MSI: $_" 'ERROR'
        Remove-Item $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "`n   [-] No se pudo extraer DefProf del MSI." -ForegroundColor Red
        Write-Host "   [!] Descarga manual: https://www.forensit.com/downloads.html" -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }

    $extracted = Get-ChildItem -Path $extractDir -Filter 'DefProf.exe' -Recurse -ErrorAction SilentlyContinue |
                 Select-Object -First 1

    if (-not $extracted) {
        Write-Log "DefProf.exe no encontrado despues de extraer." 'ERROR'
        Remove-Item $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "`n   [-] No se pudo extraer DefProf.exe del MSI." -ForegroundColor Red
        Write-Host "   [!] Descarga manual: https://www.forensit.com/downloads.html" -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }

    if (-not (Test-Path 'C:\IT')) { New-Item 'C:\IT' -ItemType Directory -Force | Out-Null }
    Copy-Item $extracted.FullName $defprof -Force
    Write-Log "defprof.exe instalado en $defprof"

    # ── Verificacion final ──
    if (Test-DefProfIntegrity $defprof) {
        Write-Log "defprof.exe descargado y verificado correctamente."
    } else {
        Write-Log "defprof.exe descargado no supero la verificacion de integridad." 'ERROR'
        Write-Host "`n   [!] El archivo descargado no supero la verificacion (hash/firma)." -ForegroundColor Yellow
        Write-Host "       Continuar implica ejecutar un archivo no verificado." -ForegroundColor White
        $op = Read-Host "       Continuar de todos modos? (S/N)"
        if ($op -notmatch '^(S|s|Si|si)$') {
            Remove-Item $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Operacion cancelada por verificacion fallida." 'WARN'
            Read-Host "`nPresiona Enter para cerrar"
            exit 1
        }
        Write-Log "El usuario decidio continuar con defprof.exe no verificado." 'WARN'
    }

    Remove-Item $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Archivos temporales eliminados."
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

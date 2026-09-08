# fix-winx.ps1
# Repara el menu Win + X (falla post-defprof): copia los accesos directos ocultos
# (Group1/2/3) de un usuario con Win+X funcional hacia la plantilla Default y al
# usuario actual, normaliza atributos y reinicia el explorador.
# Requiere: ejecutar como Administrador | Log en: C:\repositorio\logs\defprof\

#Requires -RunAsAdministrator

param([string]$SourceUser = "")

$ErrorActionPreference = 'Stop'

$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logDir  = 'C:\repositorio\logs\defprof'
$logFile = "$logDir\fix-winx_$ts.log"
$bkpRoot = "$logDir\winx_bkp_$ts"

$defaultWinX = 'C:\Users\Default\AppData\Local\Microsoft\Windows\WinX'

if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    $line = "[$ts][$level] $msg"
    Write-Host "   $msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

# ── Header ───────────────────────────────────────────────────
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8
Add-Content -Path $logFile -Value " fix-winx  |  $ts"                                 -Encoding UTF8
Add-Content -Path $logFile -Value " Host   : $env:COMPUTERNAME"                       -Encoding UTF8
Add-Content -Path $logFile -Value " Usuario: $env:USERDOMAIN\$env:USERNAME"           -Encoding UTF8
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8

# ── Seleccionar usuario con Win+X funcional ───────────────────
$excluir  = @('Administrator', 'DefaultAccount', 'Guest', 'WDAGUtilityAccount')
$usuarios = Get-LocalUser | Where-Object { $excluir -notcontains $_.Name }

if ($SourceUser) {
    if (-not ($usuarios.Name -contains $SourceUser)) {
        Write-Log "El usuario '$SourceUser' no existe o no es local." 'ERROR'
        Write-Host "`n   [-] El usuario '$SourceUser' no existe o no es local." -ForegroundColor Red
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }
    $origen = $SourceUser
    Write-Log "Usuario origen definido por parametro: $origen"
} else {
    Write-Host ""
    Write-Host "Cuenta activa: $env:USERNAME"
    Write-Host ""
    Write-Host "Usuarios locales:"
    $i = 1
    $usuarios | ForEach-Object { Write-Host "  [$i] $($_.Name)"; $i++ }
    Write-Host ""
    $opcion = Read-Host "Usuario con Win+X funcional (origen)"
    $n = 0
    if (-not [int]::TryParse($opcion, [ref]$n)) {
        Write-Log "No se ingreso un numero valido: '$opcion'." 'ERROR'
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }
    if ($n -lt 1 -or $n -gt $usuarios.Count) {
        Write-Log "Numero fuera de rango: $n" 'ERROR'
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }
    $origen = $usuarios[$n - 1].Name
}

$srcWinX = "C:\Users\$origen\AppData\Local\Microsoft\Windows\WinX"
$curWinX = "$env:LOCALAPPDATA\Microsoft\Windows\WinX"

if (-not (Test-Path $srcWinX)) {
    Write-Log "No existe la carpeta WinX en el origen: $srcWinX" 'ERROR'
    Write-Host "`n   [-] El usuario '$origen' no tiene la carpeta WinX esperada." -ForegroundColor Red
    Write-Host "   [$srcWinX]" -ForegroundColor Yellow
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

Write-Log "Origen seleccionado: $origen"

# ── Backup del estado actual ─────────────────────────────────
function Backup-WinX {
    param([string]$path, [string]$tag)
    if (-not (Test-Path $path)) { return }
    $dest = "$bkpRoot\$tag"
    New-Item $dest -ItemType Directory -Force | Out-Null
    xcopy $path $dest /E /I /Y /H /Q | Out-Null
    if ($LASTEXITCODE -gt 1) {
        Write-Log "No se pudo respaldar $path (xcopy exit=$LASTEXITCODE)" 'WARN'
    } else {
        Write-Log "Backup del WinX actual: $dest"
    }
}

# ── Copiar y normalizar ──────────────────────────────────────
function Copy-WinX {
    param([string]$source, [string]$dest, [string]$label)
    Write-Host ""
    Write-Log "Copiando accesos directos hacia $label..."
    xcopy $source $dest /E /I /Y /H /Q | Out-Null
    if ($LASTEXITCODE -gt 1) {
        Write-Log "ERROR al copiar hacia $label (xcopy exit=$LASTEXITCODE)" 'ERROR'
        return $false
    }
    Write-Log "Accesos directos copiados a $label"
    attrib -r -s -h "$dest\*" /s /d | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Permisos y atributos normalizados en $label"
    } else {
        Write-Log "attrib devolvio exit=$LASTEXITCODE en $label" 'WARN'
    }
    return $true
}

Backup-WinX $defaultWinX 'Default'
if ($origen -ne $env:USERNAME) { Backup-WinX $curWinX $env:USERNAME }

$huboError = $false
if (-not (Copy-WinX $srcWinX $defaultWinX 'la plantilla Default')) { $huboError = $true }
if ($origen -ne $env:USERNAME) {
    if (-not (Copy-WinX $srcWinX $curWinX "el usuario actual ($env:USERNAME)")) { $huboError = $true }
}

# ── Reiniciar el explorador ──────────────────────────────────
Write-Host ""
Write-Log "Reiniciando el Explorador de Windows..."
taskkill /f /im explorer.exe | Out-Null
Start-Sleep -Seconds 1
Start-Process explorer.exe
Write-Log "Explorador reiniciado."

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8

if ($huboError) {
    Write-Host "`n   [x] Proceso completado con errores. Revisar el log." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n   [+] Proceso completado con exito." -ForegroundColor Green
Write-Host ""
Write-Host "Log guardado en:"
Write-Host "   $logFile"
Write-Host ""
Read-Host "Presiona Enter para cerrar"
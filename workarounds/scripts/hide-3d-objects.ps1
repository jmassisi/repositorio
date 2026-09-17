# menu: hide-3d-objects (Windows 10 only)
# hide-3d-objects.ps1
# WORKAROUND (Windows 10 / perfiles en ingles): oculta la biblioteca
# "3D Objects" de "Este equipo" y elimina la carpeta fisica vacia de cada perfil.
# 1) Borra la key CLSID {0DB7E03F-FC29-4DC6-9020-FF41B59E513A} del namespace
#    (HKLM + WOW6432Node), equivalente al Hide_3D_Objects.reg original.
# 2) Borra "%USERPROFILE%\3D Objects" solo si la carpeta esta VACIA.
# Si alguna carpeta "3D Objects" tiene contenido -> ABORTA todo (ni hide ni
# borrado) y lista que encontro, para no perder datos del usuario.
# SOLO Windows 10: en Windows 11 el icono ya no existe (build < 22000 exigida).
# Requiere: Administrador. Reversible: importando el .reg generado en logs/.

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$root    = Split-Path $PSScriptRoot -Parent
$logDir  = Join-Path $root 'logs'
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logFile = Join-Path $logDir "hide-3d-objects_$ts.log"
if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    Add-Content -Path $logFile -Value "[$ts][$level] $msg" -Encoding UTF8
    if ($level -eq 'ERROR') { Write-Host "[-] $msg" -ForegroundColor Red }
}

Write-Host "================================================"
Write-Host " HIDE 3D OBJECTS  (SOLO Windows 10)"
Write-Host " Host   : $env:COMPUTERNAME"
Write-Host "================================================"
Write-Log "Inicio"
Write-Log "Host: $env:COMPUTERNAME | Usuario: $env:USERDOMAIN\$env:USERNAME"

# --- 1. Verificar Windows 10 (build < 22000); en 11 el icono no existe ---
$nt = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build = [int]$nt.CurrentBuildNumber
if ($nt.ProductName -notlike 'Windows 10*' -or $build -ge 22000) {
    Write-Log "OS no soportado: $($nt.ProductName) (build $build). Solo Windows 10." 'ERROR'
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}
Write-Host "   [+] Windows 10 detectado (build $build)" -ForegroundColor Green
Write-Log "OS OK: $($nt.ProductName) (build $build)"

# --- 2. Escanear perfiles: abortar si alguna carpeta tiene contenido ---
function Get-3DContent {
    param([string]$Path)
    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'desktop.ini' }
}
$excluir = @('Default', 'Default User', 'Public', 'All Users')
$perfiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin $excluir }

$carpetas = @()
foreach ($perfil in $perfiles) {
    $carpeta3d = Join-Path $perfil.FullName '3D Objects'
    if (Test-Path $carpeta3d) { $carpetas += $carpeta3d }
}
if ($carpetas.Count -eq 0) {
    Write-Host "   [=] No se encontro ninguna carpeta '3D Objects' en C:\Users" -ForegroundColor Yellow
    Write-Log "Sin carpetas '3D Objects' en C:\Users"
}

$conContenido = @($carpetas | Where-Object { @(Get-3DContent $_ | Select-Object -First 1).Count -gt 0 })
if ($conContenido.Count -gt 0) {
    Write-Host "`n   [-] Se ABORTA. Hay carpetas '3D Objects' con contenido:" -ForegroundColor Red
    foreach ($carpeta in $conContenido) {
        Write-Host "       $carpeta" -ForegroundColor Yellow
        Get-3DContent $carpeta | Select-Object -First 5 |
            ForEach-Object { Write-Host "           - $($_.Name)" -ForegroundColor DarkGray }
        if (@(Get-3DContent $carpeta).Count -gt 5) {
            Write-Host "           - ... (y mas archivos)" -ForegroundColor DarkGray
        }
    }
    Write-Host "   [...] No se oculta el icono ni se borra ninguna carpeta." -ForegroundColor Red
    Write-Log "ABORTO por contenido en: $($conContenido -join ' | ')" 'ERROR'
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

# --- 3. Idempotencia: ya oculto y sin carpetas? ---
$keys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'
)
$keysPresentes = @($keys | Where-Object { Test-Path $_ })

if ($keysPresentes.Count -eq 0 -and $carpetas.Count -eq 0) {
    Write-Host "`n   [=] Ya esta aplicado: sin keys y sin carpetas '3D Objects'." -ForegroundColor Yellow
    $re = Read-Host '   Re-hacer? (S/N)'
    if ($re -notmatch '^[sS]') {
        Write-Log "Ya aplicado, sin cambios."
        Read-Host "`nPresiona Enter para cerrar"
        exit 0
    }
    Write-Log "Re-hacer confirmado por el operador."
}

# --- 4. Ocultar del Explorador: borrar keys del namespace (HKLM + WOW6432Node) ---
Write-Host "`n   ==> Ocultando '3D Objects' de 'Este equipo' (registro)" -ForegroundColor Cyan
$okKeys = 0
foreach ($k in $keys) {
    if (Test-Path $k) {
        Remove-Item -Path $k -Recurse -Force
        Write-Host "   [+] Key eliminada: $k" -ForegroundColor Green
        Write-Log "Key eliminada: $k"
        $okKeys++
    } else {
        Write-Host "   [=] Key ausente: $k" -ForegroundColor Yellow
    }
}

# --- 5. Borrar carpetas vacias de cada perfil ---
Write-Host "`n   ==> Eliminando carpetas vacias '3D Objects' por perfil" -ForegroundColor Cyan
foreach ($carpeta in $carpetas) {
    Remove-Item -Path $carpeta -Recurse -Force
    Write-Host "   [+] Carpeta eliminada: $carpeta" -ForegroundColor Green
    Write-Log "Carpeta eliminada: $carpeta"
}

# --- 6. Dejar .reg de restauracion (rollback) ---
$restore = Join-Path $logDir "hide-3d-objects-restore_$ts.reg"
$contenido = @(
    'Windows Registry Editor Version 5.00',
    '',
    "[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}]",
    "[HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}]"
)
Set-Content -Path $restore -Value $contenido -Encoding Unicode
Write-Host "`n   [+] Rollback (.reg) en: $restore" -ForegroundColor Green
Write-Log "Restore .reg generado: $restore"

# --- 7. Resultado final ---
Write-Host "`n================================================"
Write-Host "   Resumen:"
Write-Host "   Keys eliminadas           : $okKeys / $($keys.Count)"
Write-Host "   Carpetas eliminadas       : $($carpetas.Count)"
$carpetas | ForEach-Object { Write-Host "       - $_" -ForegroundColor Green }
Write-Host "   Log                      : $logFile"
Write-Host "================================================"
Write-Log "Fin OK. Keys: $okKeys | Carpetas: $($carpetas.Count)"
Write-Host ""
Write-Host "   Nota: el icono desaparece al refrescar/reabrir el Explorador." -ForegroundColor DarkGray
Write-Host "   Si persiste, reinicia Explorer o cierra sesion." -ForegroundColor DarkGray
Write-Host ""
Read-Host "Presiona Enter para cerrar"
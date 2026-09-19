# menu: copy-path-file-context-menu-w10 (Windows 10 only)
# copy-path-file-context-menu-w10.ps1
# WORKAROUND (Windows 10): agrega "Copiar ruta del archivo" al menu contextual
# de archivos y carpetas (Explorador), via la key
# HKCR\AllFilesystemObjects\shell\windows.copyaspath (equal al
# copy_path_file_context_menu_W10.reg original). Util para PCs donde no se
# usa Shift+Click para copiar la ruta completa.
# SOLO Windows 10: en Windows 11 "Copiar como ruta" ya esta integrado en el
# menu contextual (build < 22000 exigida).
# Requiere: Administrador. Reversible: importando el .reg de undo en logs/.
# Idempotente: si la key ya existe avisa y ofrece re-aplicar de todos modos.

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$root    = Split-Path $PSScriptRoot -Parent
$logDir  = Join-Path $root 'logs'
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logFile = Join-Path $logDir "copy-path-file-context-menu-w10_$ts.log"
if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    Add-Content -Path $logFile -Value "[$ts][$level] $msg" -Encoding UTF8
    if ($level -eq 'ERROR') { Write-Host "[-] $msg" -ForegroundColor Red }
}

Write-Host "================================================"
Write-Host " COPY PATH FILE CONTEXT MENU  (SOLO Windows 10)"
Write-Host " Host   : $env:COMPUTERNAME"
Write-Host "================================================"
Write-Log "Inicio"
Write-Log "Host: $env:COMPUTERNAME | Usuario: $env:USERDOMAIN\$env:USERNAME"

# --- 1. Verificar Windows 10 (build < 22000); en 11 ya existe integrado ---
$nt = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build = [int]$nt.CurrentBuildNumber
if ($nt.ProductName -notlike 'Windows 10*' -or $build -ge 22000) {
    Write-Log "OS no soportado: $($nt.ProductName) (build $build). Solo Windows 10." 'ERROR'
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}
Write-Host "   [+] Windows 10 detectado (build $build)" -ForegroundColor Green
Write-Log "OS OK: $($nt.ProductName) (build $build)"

# --- 2. Definir la key y los valores a escribir ---
$namespace = 'Registry::HKEY_CLASSES_ROOT\AllFilesystemObjects\shell\windows.copyaspath'
$valores = @(
    @{ N = '';                                V = 'Copiar ruta del archivo'; T = 'String' },
    @{ N = 'InvokeCommandOnSelection';        V = 1;                          T = 'DWord' },
    @{ N = 'VerbHandler';                     V = '{f3d06e7c-1e45-4a26-847e-f9fcdee59be0}'; T = 'String' },
    @{ N = 'Icon';                            V = 'C:\Windows\System32\shell32.dll,134'; T = 'String' }
)

# --- 3. Idempotencia: ya aplicado? ---
if (Test-Path $namespace) {
    Write-Host "`n   [=] Ya esta aplicado: la entrada 'Copiar ruta del archivo' existe en el menu contextual." -ForegroundColor Yellow
    $re = Read-Host '   Re-aplicar de todos modos? (S/N)'
    if ($re -notmatch '^[sS]') {
        Write-Log "Ya aplicado, sin cambios."
        Read-Host "`nPresiona Enter para cerrar"
        exit 0
    }
    Write-Log "Re-aplicar confirmado por el operador."
}

# --- 4. Crear la key y escribir los valores ---
Write-Host "`n   ==> Agregando 'Copiar ruta del archivo' al menu contextual" -ForegroundColor Cyan
New-Item -Path $namespace -Force | Out-Null
foreach ($v in $valores) {
    if ($v.N -eq '') {
        Set-Item -Path $namespace -Value $v.V -Force
    } else {
        New-ItemProperty -Path $namespace -Name $v.N -Value $v.V -PropertyType $v.T -Force | Out-Null
    }
    Write-Host "   [+] $($v.N) = $($v.V)" -ForegroundColor Green
}
Write-Log "Key creada: $namespace con $($valores.Count) valores"

# --- 5. Verificar y dejar .reg de undo (rollback) ---
$ok = Test-Path $namespace -and (Get-Item $namespace).GetValue('') -eq 'Copiar ruta del archivo'
if (-not $ok) {
    Write-Log "Verificacion fallida: $namespace" 'ERROR'
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

$undo = Join-Path $logDir "copy-path-file-context-menu-w10-undo_$ts.reg"
$contenido = @(
    'Windows Registry Editor Version 5.00',
    '',
    '[-HKEY_CLASSES_ROOT\AllFilesystemObjects\shell\windows.copyaspath]'
)
Set-Content -Path $undo -Value $contenido -Encoding Unicode
Write-Host "`n   [+] Undo (.reg) en: $undo" -ForegroundColor Green
Write-Log "Undo .reg generado: $undo"

# --- 6. Resultado final ---
Write-Host "`n================================================"
Write-Host "   Resumen:"
Write-Host "   Entrada agregada        : Copiar ruta del archivo"
Write-Host "   Key                     : $namespace"
Write-Host "   Undo                    : $undo"
Write-Host "   Log                     : $logFile"
Write-Host "================================================"
Write-Log "Fin OK."
Write-Host ""
Write-Host "   Nota: el cambio se refleja al reabrir el menu contextual/Explorador." -ForegroundColor DarkGray
Write-Host ""
Read-Host "Presiona Enter para cerrar"
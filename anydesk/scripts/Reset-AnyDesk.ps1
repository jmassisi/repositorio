# Reset-AnyDesk.ps1 - v3
# Agnostico de idioma, path, instalado o standalone
# - Deteccion por ProductName (no por nombre del proceso)
# - Relaunch: Start-Service si instalado, Start-Process si standalone
# - Backup de .conf con timestamp (sin sobreescribir historial)
# - Log en C:\repositorio\anydesk\logs\

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# ── Timestamp unico para esta ejecucion ──────────────────────
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logDir  = "$PSScriptRoot\..\logs"
$logFile = "$logDir\reset_$ts.log"

if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    $line = "[$ts][$level] $msg"
    Write-Host "   $msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

function Write-Step($n, $total, $msg) {
    Write-Host "`n[$n/$total] $msg"
    Add-Content -Path $logFile -Value "`n--- $msg ---" -Encoding UTF8
}

$totalSteps = 4

# ── Header del log ───────────────────────────────────────────
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8
Add-Content -Path $logFile -Value " Reset-AnyDesk  |  $ts"                           -Encoding UTF8
Add-Content -Path $logFile -Value " Host   : $env:COMPUTERNAME"                      -Encoding UTF8
Add-Content -Path $logFile -Value " Usuario: $env:USERDOMAIN\$env:USERNAME"          -Encoding UTF8
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8

# ── 1. Detectar proceso ──────────────────────────────────────
Write-Step 1 $totalSteps "Buscando proceso AnyDesk..."

# Buscar por ProductName para ser agnóstico al nombre del exe
$proc = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try { $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' } catch { $false }
} | Select-Object -First 1

$exePath   = $null
$anyDeskId = $null

if ($proc) {
    try {
        $exePath = $proc.MainModule.FileName
    } catch {
        $exePath = (Get-WmiObject Win32_Process -Filter "ProcessId=$($proc.Id)").ExecutablePath
    }
    Write-Log "Proceso activo - PID: $($proc.Id) | Nombre: $($proc.Name)"
    Write-Log "Ruta exe: $exePath"

    # Leer AnyDesk ID desde system.conf ANTES de matar el proceso
    $systemConf = "$env:ProgramData\AnyDesk\system.conf"
    if (-not (Test-Path $systemConf)) {
        $systemConf = "$(Split-Path $exePath -Parent)\system.conf"
    }
    if (Test-Path $systemConf) {
        $idLine = Get-Content $systemConf -ErrorAction SilentlyContinue |
                  Where-Object { $_ -match 'ad\.anynet\.id\s*=' }
        if ($idLine) {
            $anyDeskId = ($idLine -split '=', 2)[1].Trim()
            Write-Log "AnyDesk ID (antes del reset): $anyDeskId"
        }
    }
    if (-not $anyDeskId) { Write-Log "AnyDesk ID: no encontrado en system.conf" 'WARN' }

} else {
    Write-Log "AnyDesk no estaba corriendo - buscando instalacion..."
}

# Fallback: buscar instalacion en ProgramFiles
if (-not $exePath) {
    foreach ($c in @("$env:ProgramFiles\AnyDesk\AnyDesk.exe", "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe")) {
        if (Test-Path $c) { $exePath = $c; break }
    }
}

if (-not $exePath) {
    Write-Log "No se encontro AnyDesk instalado ni corriendo." 'ERROR'
    Write-Host "`n   Coloca este script en el mismo directorio que AnyDesk.exe y volvelo a ejecutar."
    exit 1
}

$exeDir = Split-Path $exePath -Parent

# Version del exe
try {
    $ver = (Get-Item $exePath).VersionInfo.FileVersion
    Write-Log "Version: $ver"
} catch {
    Write-Log "Version: no disponible" 'WARN'
}

# Instalado vs standalone
$pfPaths     = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
$isInstalled = $pfPaths | Where-Object { $exeDir -like "$_*" }
$tipoStr     = if ($isInstalled) { 'INSTALADO' } else { 'STANDALONE' }
Write-Log "Tipo: $tipoStr"

# ── 2. Kill ──────────────────────────────────────────────────
Write-Step 2 $totalSteps "Terminando procesos AnyDesk..."

# Matar todos los procesos con ProductName AnyDesk
Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try { $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' } catch { $false }
} | ForEach-Object {
    $_ | Stop-Process -Force
    Write-Log "Terminado PID $($_.Id)"
}

# Si instalado, detener tambien el servicio
if ($isInstalled) {
    $svc = Get-Service -Name 'AnyDesk' -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') {
        Stop-Service -Name 'AnyDesk' -Force -ErrorAction SilentlyContinue
        Write-Log "Servicio AnyDesk detenido"
    }
}

$waited = 0
while (
    (Get-Process -ErrorAction SilentlyContinue | Where-Object {
        try { $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' } catch { $false }
    }) -and $waited -lt 5
) {
    Start-Sleep -Seconds 1
    $waited++
}
Write-Log "Procesos terminados (espera: ${waited}s)"

# ── 3. Reset .conf con backup timestamped ────────────────────
Write-Step 3 $totalSteps "Reseteando configuracion..."

$confDirs = @(
    "$env:ProgramData\AnyDesk",
    "$env:AppData\AnyDesk",
    "$env:LocalAppData\AnyDesk",
    $exeDir
) | Select-Object -Unique

$confFiles  = @('system.conf', 'service.conf', 'user.conf', 'ad.trace')
$resetCount = 0

foreach ($dir in $confDirs) {
    if (-not (Test-Path $dir)) { continue }
    foreach ($file in $confFiles) {
        $full = Join-Path $dir $file
        if (-not (Test-Path $full)) { continue }
        $backup = Join-Path $dir "$file.$ts.backup"
        try {
            Rename-Item $full $backup
            Write-Log "Backup: $backup"
            $resetCount++
        } catch {
            Write-Log "No se pudo resetear: $full - $_" 'ERROR'
        }
    }
}

Write-Log "$resetCount archivo(s) reseteado(s)"

# ── 4. Relaunch ──────────────────────────────────────────────
Write-Step 4 $totalSteps "Relanzando AnyDesk..."

try {
    if ($isInstalled) {
        Start-Service -Name 'AnyDesk' -ErrorAction Stop
        Write-Log "Servicio AnyDesk iniciado"
        Start-Process $exePath
        Write-Log "Relaunch OK (instalado): $exePath"
    } else {
        Start-Process $exePath
        Write-Log "Relaunch OK (standalone): $exePath"
    }
} catch {
    Write-Log "Relaunch FALLIDO: $_" 'ERROR'
}

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
Write-Host "`nListo. Log guardado en:`n   $logFile"

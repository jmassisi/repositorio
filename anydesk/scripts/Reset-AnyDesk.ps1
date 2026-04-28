# Reset-AnyDesk.ps1 - v2
# Agnostico de idioma, path, instalado o standalone
# - Backup de .conf con timestamp (sin sobreescribir historial)
# - Log persistente por ejecucion

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'

# ── Timestamp unico para esta ejecucion ──────────────────────
$ts     = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logDir = "$env:ProgramData\AnyDesk\reset-logs"
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

# ── Funcion: decodificar ROT13 ───────────────────────────────
function ConvertFrom-Rot13 ([string]$s) {
    -join ($s.ToCharArray() | ForEach-Object {
        $c = [int]$_
        if    ($c -ge 65 -and $c -le 90)  { [char](( ($c - 65 + 13) % 26 ) + 65) }
        elseif($c -ge 97 -and $c -le 122) { [char](( ($c - 97 + 13) % 26 ) + 97) }
        else  { $_ }
    })
}

# ── Funcion: buscar exe via UserAssist ───────────────────────
function Find-ExeViaUserAssist {
    Write-Log "Buscando ruta via UserAssist (ROT13)..."
    $uaRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist'
    try {
        $guids = Get-ChildItem $uaRoot -ErrorAction Stop
        foreach ($guid in $guids) {
            $countKey = Join-Path $guid.PSPath 'Count'
            if (-not (Test-Path $countKey)) { continue }
            $names = Get-Item $countKey | Select-Object -ExpandProperty Property
            foreach ($name in $names) {
                $decoded = ConvertFrom-Rot13 $name
                if ($decoded -match 'AnyDesk\.exe$') {
                    Write-Log "UserAssist hit: $decoded"
                    return $decoded
                }
            }
        }
        Write-Log "UserAssist: no se encontro AnyDesk.exe" 'WARN'
    } catch {
        Write-Log "UserAssist: error leyendo registro - $_" 'WARN'
    }
    return $null
}

# ── Funcion: buscar exe via Prefetch ─────────────────────────
function Find-ExeViaPrefetch {
    Write-Log "Buscando ruta via Prefetch..."
    $prefetchDir = "$env:SystemRoot\Prefetch"
    try {
        $pf = Get-ChildItem "$prefetchDir\ANYDESK*.pf" -ErrorAction Stop | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($pf) {
            Write-Log "Prefetch encontrado: $($pf.FullName) (ultima ejecucion: $($pf.LastWriteTime))"
            # Prefetch no contiene la ruta completa de forma facil de leer sin herramientas forenses,
            # pero confirma ejecucion. Intentar reconstruir ruta desde strings del archivo.
            $bytes  = [System.IO.File]::ReadAllBytes($pf.FullName)
            $text   = [System.Text.Encoding]::Unicode.GetString($bytes)
            $match  = [regex]::Match($text, '[A-Z]:\\[^\x00]+AnyDesk\.exe')
            if ($match.Success) {
                $path = $match.Value.Trim()
                Write-Log "Prefetch ruta extraida: $path"
                return $path
            } else {
                Write-Log "Prefetch: no se pudo extraer ruta del exe" 'WARN'
            }
        } else {
            Write-Log "Prefetch: no se encontro archivo ANYDESK*.pf" 'WARN'
        }
    } catch {
        Write-Log "Prefetch: error leyendo directorio - $_" 'WARN'
    }
    return $null
}

# ── 1. Detectar proceso ──────────────────────────────────────
Write-Step 1 $totalSteps "Buscando proceso AnyDesk..."

$proc      = Get-Process -Name AnyDesk -ErrorAction SilentlyContinue | Select-Object -First 1
$exePath   = $null
$anyDeskId = $null
$detectedVia = $null

# 1a. Proceso activo
if ($proc) {
    try {
        $exePath = (Get-Process -Id $proc.Id -FileVersionInfo -ErrorAction Stop).FileName
    } catch {
        $exePath = (Get-WmiObject Win32_Process -Filter "ProcessId=$($proc.Id)").ExecutablePath
    }
    $detectedVia = 'PROCESO'
    Write-Log "Proceso activo - PID: $($proc.Id)"
    Write-Log "Ruta exe: $exePath"
} else {
    Write-Log "AnyDesk no estaba corriendo."
}

# 1b. Instalacion en ProgramFiles
if (-not $exePath) {
    Write-Log "Buscando instalacion en ProgramFiles..."
    foreach ($c in @("$env:ProgramFiles\AnyDesk\AnyDesk.exe", "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe")) {
        if (Test-Path $c) { $exePath = $c; $detectedVia = 'PROGRAMFILES'; break }
    }
    if ($exePath) { Write-Log "Instalacion encontrada: $exePath" }
    else          { Write-Log "No encontrado en ProgramFiles." 'WARN' }
}

# 1c. UserAssist
if (-not $exePath) {
    $exePath = Find-ExeViaUserAssist
    if ($exePath) { $detectedVia = 'USERASSIST' }
}

# 1d. Prefetch
if (-not $exePath) {
    $exePath = Find-ExeViaPrefetch
    if ($exePath) { $detectedVia = 'PREFETCH' }
}

# Validar que el exe existe fisicamente
if ($exePath) {
    if (Test-Path $exePath) {
        Write-Log "Exe validado via $detectedVia : $exePath"
    } else {
        Write-Log "Ruta encontrada via $detectedVia pero el exe ya no existe: $exePath" 'ERROR'
        Write-Log "Abortando para evitar reset sin posibilidad de relaunch." 'ERROR'
        exit 1
    }
} else {
    Write-Log "No se encontro AnyDesk por ningun metodo (proceso, ProgramFiles, UserAssist, Prefetch)." 'ERROR'
    Write-Log "Coloca este script en el mismo directorio que AnyDesk.exe y volvelo a ejecutar." 'ERROR'
    exit 1
}

$exeDir = Split-Path $exePath -Parent

# Leer AnyDesk ID ANTES del kill (ahora siempre, independiente de si habia proceso)
$systemConf = "$env:ProgramData\AnyDesk\system.conf"
if (-not (Test-Path $systemConf)) { $systemConf = "$exeDir\system.conf" }
if (Test-Path $systemConf) {
    $idLine = Get-Content $systemConf -ErrorAction SilentlyContinue |
              Where-Object { $_ -match 'ad\.anynet\.id\s*=' }
    if ($idLine) {
        $anyDeskId = ($idLine -split '=', 2)[1].Trim()
        Write-Log "AnyDesk ID (antes del reset): $anyDeskId"
    } else {
        Write-Log "AnyDesk ID: no encontrado en system.conf" 'WARN'
    }
} else {
    Write-Log "AnyDesk ID: system.conf no encontrado" 'WARN'
}

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

Get-Process -Name AnyDesk -ErrorAction SilentlyContinue | ForEach-Object {
    $_ | Stop-Process -Force
    Write-Log "Terminado PID $($_.Id)"
}

$waited = 0
while ((Get-Process -Name AnyDesk -ErrorAction SilentlyContinue) -and $waited -lt 5) {
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
    Start-Process $exePath
    Write-Log "Relaunch OK: $exePath"
} catch {
    Write-Log "Relaunch FALLIDO: $_" 'ERROR'
}

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
Write-Host "`nListo. Log guardado en:`n   $logFile"

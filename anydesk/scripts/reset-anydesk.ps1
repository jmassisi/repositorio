# Reset-AnyDesk.ps1 - v4
# Agnostico de idioma, path, instalado o standalone
# - Deteccion por ProductName (proceso corriendo)
# - Fallback: UserAssist (registro) y Prefetch si no esta corriendo
# - Relaunch: Start-Service si instalado, Start-Process si standalone
# - Sin ruta: reset de configs igual + advertencia + oferta de descarga
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

# Decodifica ROT13
function ConvertFrom-Rot13 {
    param([string]$s)
    -join ($s.ToCharArray() | ForEach-Object {
        if ($_ -match '[A-Za-z]') {
            $base = if ($_ -cmatch '[A-Z]') { [int][char]'A' } else { [int][char]'a' }
            [char](($([int][char]$_) - $base + 13) % 26 + $base)
        } else { $_ }
    })
}

$totalSteps = 4

# ── Header del log ───────────────────────────────────────────
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8
Add-Content -Path $logFile -Value " Reset-AnyDesk  |  $ts"                           -Encoding UTF8
Add-Content -Path $logFile -Value " Host   : $env:COMPUTERNAME"                      -Encoding UTF8
Add-Content -Path $logFile -Value " Usuario: $env:USERDOMAIN\$env:USERNAME"          -Encoding UTF8
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8

# ── 1. Detectar proceso / ruta ───────────────────────────────
Write-Step 1 $totalSteps "Buscando AnyDesk..."

$exePath   = $null
$anyDeskId = $null

# --- 1a. Proceso corriendo (ProductName) ---
$proc = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try { $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' } catch { $false }
} | Select-Object -First 1

if ($proc) {
    try {
        $exePath = $proc.MainModule.FileName
    } catch {
        $exePath = (Get-WmiObject Win32_Process -Filter "ProcessId=$($proc.Id)").ExecutablePath
    }
    Write-Log "Proceso activo - PID: $($proc.Id) | Nombre: $($proc.Name)"
    Write-Log "Ruta exe: $exePath"
    Write-Log "Fuente deteccion: proceso corriendo"
}

# --- 1b. No esta corriendo: ProgramFiles ---
if (-not $exePath) {
    Write-Log "AnyDesk no estaba corriendo - buscando instalacion..."
    foreach ($c in @("$env:ProgramFiles\AnyDesk\AnyDesk.exe", "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe")) {
        if (Test-Path $c) { $exePath = $c; break }
    }
    if ($exePath) { Write-Log "Fuente deteccion: ProgramFiles | Ruta: $exePath" }
}

# --- 1c. UserAssist (ROT13) ---
if (-not $exePath) {
    Write-Log "Buscando en UserAssist (registro)..."
    try {
        $uaKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist'
        Get-ChildItem $uaKey -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ItemProperty "$($_.PSPath)\Count" -ErrorAction SilentlyContinue |
            Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name |
            ForEach-Object {
                if (-not $exePath) {
                    $decoded = ConvertFrom-Rot13 $_
                    if ($decoded -match '\.exe$' -and (Test-Path $decoded)) {
                        try {
                            $pn = (Get-Item $decoded -ErrorAction Stop).VersionInfo.ProductName
                            if ($pn -like '*AnyDesk*') { $exePath = $decoded }
                        } catch {}
                    }
                }
            }
        }
    } catch {
        Write-Log "Error leyendo UserAssist: $_" 'WARN'
    }
    if ($exePath) { Write-Log "Fuente deteccion: UserAssist | Ruta: $exePath" }
}

# --- 1d. Prefetch ---
if (-not $exePath) {
    Write-Log "Buscando en Prefetch..."
    try {
        $pfFiles = Get-ChildItem 'C:\Windows\Prefetch\' -Filter '*.pf' -ErrorAction SilentlyContinue
        foreach ($pf in $pfFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($pf.FullName)
            $text  = [System.Text.Encoding]::Unicode.GetString($bytes)
            $matches = [regex]::Matches($text, '[A-Z]:\\[^\x00<>|]{4,260}\.EXE')
            foreach ($m in $matches) {
                $candidate = $m.Value.Trim()
                if (Test-Path $candidate) {
                    try {
                        $pn = (Get-Item $candidate -ErrorAction Stop).VersionInfo.ProductName
                        if ($pn -like '*AnyDesk*') { $exePath = $candidate; break }
                    } catch {}
                }
            }
            if ($exePath) { break }
        }
    } catch {
        Write-Log "Error leyendo Prefetch: $_" 'WARN'
    }
    if ($exePath) { Write-Log "Fuente deteccion: Prefetch | Ruta: $exePath" }
}

# --- Leer AnyDesk ID desde system.conf ---
$confLocations = @("$env:ProgramData\AnyDesk", "$env:AppData\AnyDesk", "$env:LocalAppData\AnyDesk")
if ($exePath) { $confLocations += Split-Path $exePath -Parent }

foreach ($loc in $confLocations) {
    $sc = Join-Path $loc 'system.conf'
    if (Test-Path $sc) {
        $idLine = Get-Content $sc -ErrorAction SilentlyContinue | Where-Object { $_ -match 'ad\.anynet\.id\s*=' }
        if ($idLine) {
            $anyDeskId = ($idLine -split '=', 2)[1].Trim()
            Write-Log "AnyDesk ID (antes del reset): $anyDeskId"
            break
        }
    }
}
if (-not $anyDeskId) { Write-Log "AnyDesk ID: no encontrado en system.conf" 'WARN' }

# --- Determinar instalado vs standalone ---
$isInstalled = $false
$tipoStr     = 'DESCONOCIDO'
if ($exePath) {
    $exeDir      = Split-Path $exePath -Parent
    $pfPaths     = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    $isInstalled = [bool]($pfPaths | Where-Object { $exeDir -like "$_*" })
    $tipoStr     = if ($isInstalled) { 'INSTALADO' } else { 'STANDALONE' }
    Write-Log "Tipo: $tipoStr"

    try {
        $ver = (Get-Item $exePath).VersionInfo.FileVersion
        Write-Log "Version: $ver"
    } catch {
        Write-Log "Version: no disponible" 'WARN'
    }
} else {
    Write-Log "No se encontro el ejecutable de AnyDesk por ningun metodo." 'WARN'
}

# ── 2. Kill ──────────────────────────────────────────────────
Write-Step 2 $totalSteps "Terminando procesos AnyDesk..."

$killed = 0
Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try { $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' } catch { $false }
} | ForEach-Object {
    $_ | Stop-Process -Force
    Write-Log "Terminado PID $($_.Id)"
    $killed++
}

if ($isInstalled) {
    $svc = Get-Service -Name 'AnyDesk' -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') {
        Stop-Service -Name 'AnyDesk' -Force -ErrorAction SilentlyContinue
        Write-Log "Servicio AnyDesk detenido"
    }
}

if ($killed -eq 0) { Write-Log "No habia procesos AnyDesk corriendo" }

$waited = 0
while (
    (Get-Process -ErrorAction SilentlyContinue | Where-Object {
        try { $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' } catch { $false }
    }) -and $waited -lt 5
) {
    Start-Sleep -Seconds 1
    $waited++
}
if ($waited -gt 0) { Write-Log "Espera post-kill: ${waited}s" }

# ── 3. Reset .conf con backup timestamped ────────────────────
Write-Step 3 $totalSteps "Reseteando configuracion..."

$confDirs = @(
    "$env:ProgramData\AnyDesk",
    "$env:AppData\AnyDesk",
    "$env:LocalAppData\AnyDesk"
)
if ($exePath) { $confDirs += Split-Path $exePath -Parent }
$confDirs = $confDirs | Select-Object -Unique

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

if ($exePath) {
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
} else {
    Write-Log "Sin ruta de ejecutable: relaunch omitido" 'WARN'
    Write-Host ""
    Write-Host "   [!] AnyDesk no esta instalado y no se encontro el ejecutable."
    Write-Host "       Si tenes el archivo .exe, abri AnyDesk antes de ejecutar este script."
    Write-Host "       Para descargar AnyDesk: https://anydesk.com/es/downloads/windows"
    Write-Host ""
    Write-Log "Descarga sugerida: https://anydesk.com/es/downloads/windows" 'WARN'

    $resp = Read-Host "   Abrir pagina de descarga ahora? (S/N)"
    if ($resp -match '^[Ss]') {
        Start-Process "https://anydesk.com/es/downloads/windows"
        Write-Log "Usuario eligio abrir descarga en navegador"
    }
}

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
Write-Host "`nListo. Log guardado en:`n   $logFile"

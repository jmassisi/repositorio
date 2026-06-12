# anydesk-reset.ps1 - v5
# Agnostico de idioma, path, instalado o standalone
# - NTP al inicio para corregir hora antes de cualquier accion
# - Deteccion por ProductName (cubre exe renombrado)
# - Fallback: ProgramFiles, UserAssist (ROT13), Prefetch
# - Si no se encuentra: winget install silencioso
# - Kill por ProductName + Stop-Service si instalado
# - Reset de confs SIN tocar user.conf (preserva alias y sesiones recientes)
# - Restore de ad.roster.items del backup al nuevo user.conf post-relaunch
# - Relaunch: Start-Service si instalado, Start-Process si standalone
# - Verificacion de conectividad + polling de ID post-relaunch (30s)
# - Log en %ProgramData%\AnyDesk\reset-logs\

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'

# -- Timestamp unico para esta ejecucion ----------------------
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logDir  = "$env:ProgramData\AnyDesk\reset-logs"
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

$totalSteps = 6

# -- Header del log -------------------------------------------
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8
Add-Content -Path $logFile -Value (" anydesk-reset  |  " + $ts)                      -Encoding UTF8
Add-Content -Path $logFile -Value (" Host   : " + $env:COMPUTERNAME)                  -Encoding UTF8
Add-Content -Path $logFile -Value (" Usuario: " + $env:USERDOMAIN + "\" + $env:USERNAME) -Encoding UTF8
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8

# -- 1. Sincronizar hora del sistema --------------------------
Write-Step 1 $totalSteps "Verificando hora del sistema..."
try {
    $ntpServer = 'time.windows.com'
    $localTime = [DateTime]::UtcNow
    $ntpData   = New-Object byte[] 48
    $ntpData[0] = 0x1B
    $udpClient  = New-Object System.Net.Sockets.UdpClient
    $udpClient.Connect($ntpServer, 123)
    $udpClient.Send($ntpData, $ntpData.Length) | Out-Null
    $endpoint  = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
    $recv      = $udpClient.Receive([ref]$endpoint)
    $udpClient.Close()
    $intPart   = [BitConverter]::ToUInt32($recv[40..43][3..0], 0)
    $fracPart  = [BitConverter]::ToUInt32($recv[44..47][3..0], 0)
    $ntpEpoch  = [DateTime]::new(1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
    $ntpTime   = $ntpEpoch.AddSeconds($intPart + $fracPart / [Math]::Pow(2, 32))
    $diffSec   = [Math]::Abs(($ntpTime - $localTime).TotalSeconds)
    Write-Log ("Hora local (UTC): " + $localTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Log ("Hora NTP   (UTC): " + $ntpTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Log ("Diferencia: " + [Math]::Round($diffSec, 1) + "s")
    if ($diffSec -gt 60) {
        Write-Log "Desfase mayor a 60s - forzando sincronizacion NTP..." 'WARN'
        Start-Service w32tm -ErrorAction SilentlyContinue
        $resync = & w32tm /resync /force 2>&1
        Write-Log ("w32tm: " + $resync)
        Start-Sleep -Seconds 3
        Write-Log "Hora sincronizada."
    } else {
        Write-Log "Hora OK (desfase dentro del margen aceptable)"
    }
} catch {
    Write-Log ("No se pudo verificar hora NTP: " + $_ + " - Continuando de todas formas") 'WARN'
}

# -- Funcion: decodificar ROT13 -------------------------------
function ConvertFrom-Rot13 ([string]$s) {
    -join ($s.ToCharArray() | ForEach-Object {
        if ($_ -match '[A-Za-z]') {
            $base = if ($_ -cmatch '[A-Z]') { [int][char]'A' } else { [int][char]'a' }
            [char](([int][char]$_ - $base + 13) % 26 + $base)
        } else { $_ }
    })
}

# -- Funcion: buscar exe via UserAssist -----------------------
function Find-ExeViaUserAssist {
    Write-Log "Buscando ruta via UserAssist (ROT13)..."
    $uaRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist'
    $found  = $null
    try {
        $guids = Get-ChildItem $uaRoot -ErrorAction Stop
        foreach ($guid in $guids) {
            if ($found) { break }
            $countKey = Join-Path $guid.PSPath 'Count'
            if (-not (Test-Path $countKey)) { continue }
            $props = Get-ItemProperty $countKey -ErrorAction SilentlyContinue
            if (-not $props) { continue }
            $names = $props | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue |
                     Select-Object -ExpandProperty Name
            if (-not $names) { continue }
            foreach ($name in $names) {
                $decoded = ConvertFrom-Rot13 $name
                if ($decoded -match '\.exe$' -and $decoded -notlike '*Uninst*' -and (Test-Path $decoded)) {
                    try {
                        $pn = (Get-Item $decoded -ErrorAction Stop).VersionInfo.ProductName
                        if ($pn -like '*AnyDesk*') {
                            Write-Log ("UserAssist hit: " + $decoded)
                            $found = $decoded
                            break
                        }
                    } catch {}
                }
            }
        }
    } catch {
        Write-Log ("UserAssist: error leyendo registro - " + $_) 'WARN'
    }
    if (-not $found) { Write-Log "UserAssist: no se encontro AnyDesk.exe" 'WARN' }
    return $found
}

# -- Funcion: buscar exe via Prefetch -------------------------
function Find-ExeViaPrefetch {
    Write-Log "Buscando ruta via Prefetch..."
    try {
        $pfFiles = Get-ChildItem "$env:SystemRoot\Prefetch" -Filter '*.pf' -ErrorAction Stop |
                   Sort-Object LastWriteTime -Descending
        foreach ($pf in $pfFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($pf.FullName)
            $text  = [System.Text.Encoding]::Unicode.GetString($bytes)
            $hits  = [regex]::Matches($text, '[A-Z]:\\[^\x00<>|]{4,260}\.EXE')
            foreach ($m in $hits) {
                $candidate = $m.Value.Trim()
                if (Test-Path $candidate) {
                    if ($candidate -like '*Uninst*') { continue }
                    try {
                        $pn = (Get-Item $candidate -ErrorAction Stop).VersionInfo.ProductName
                        if ($pn -like '*AnyDesk*') {
                            Write-Log ("Prefetch hit: " + $candidate + " (pf: " + $pf.Name + ")")
                            return $candidate
                        }
                    } catch {}
                }
            }
        }
        Write-Log "Prefetch: no se encontro AnyDesk por ProductName" 'WARN'
    } catch {
        Write-Log ("Prefetch: error leyendo directorio - " + $_) 'WARN'
    }
    return $null
}

# -- 2. Detectar proceso / ruta -------------------------------
Write-Step 2 $totalSteps "Buscando AnyDesk..."

$exePath     = $null
$anyDeskId   = $null
$detectedVia = $null
$isInstalled = $false

# 2a. Proceso activo por ProductName
$proc = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' -and
        $_.MainModule.FileName -notlike '*Uninst*'
    } catch { $false }
} | Select-Object -First 1

if ($proc) {
    try {
        $exePath = $proc.MainModule.FileName
    } catch {
        $exePath = (Get-WmiObject Win32_Process -Filter "ProcessId=$($proc.Id)").ExecutablePath
    }
    $detectedVia = 'PROCESO'
    Write-Log ("Proceso activo - PID: " + $proc.Id + " | Nombre: " + $proc.Name)
    Write-Log ("Ruta exe: " + $exePath)
} else {
    Write-Log "AnyDesk no estaba corriendo."
}

# 2b. ProgramFiles y rutas de instalacion de usuario
if (-not $exePath) {
    Write-Log "Buscando instalacion en ProgramFiles..."
    $candidatePaths = @(
        "$env:ProgramFiles\AnyDesk\AnyDesk.exe",
        "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe",
        "$env:LocalAppData\Programs\AnyDesk\AnyDesk.exe",
        "$env:AppData\AnyDesk\AnyDesk.exe"
    )
    foreach ($c in $candidatePaths) {
        if (Test-Path $c) { $exePath = $c; $detectedVia = 'PROGRAMFILES'; break }
    }
    if ($exePath) { Write-Log ("Instalacion encontrada: " + $exePath) }
    else          { Write-Log "No encontrado en ProgramFiles ni rutas de usuario." 'WARN' }
}

# 2c. UserAssist
if (-not $exePath) {
    $exePath = Find-ExeViaUserAssist
    if ($exePath) { $detectedVia = 'USERASSIST' }
}

# 2d. Prefetch
if (-not $exePath) {
    $exePath = Find-ExeViaPrefetch
    if ($exePath) { $detectedVia = 'PREFETCH' }
}

# 2e. No encontrado - instalar via winget
if (-not $exePath) {
    Write-Log "AnyDesk no encontrado por ningun metodo. Intentando instalacion via winget..." 'WARN'
    try {
        $winget = Get-Command winget -ErrorAction Stop
        Write-Log "winget disponible. Instalando AnyDesk..."
        & winget install -e --id AnyDesk.AnyDesk --silent --accept-package-agreements --accept-source-agreements | Out-Null
        Write-Log "winget finalizo. Buscando exe instalado..."
        # Buscar el exe en rutas conocidas post-instalacion
        $postInstallPaths = @(
            "$env:ProgramFiles\AnyDesk\AnyDesk.exe",
            "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe",
            "$env:LocalAppData\Programs\AnyDesk\AnyDesk.exe",
            "$env:LocalAppData\Microsoft\WinGet\Packages\AnyDesk.AnyDesk\AnyDesk.exe"
        )
        foreach ($p in $postInstallPaths) {
            if (Test-Path $p) { $exePath = $p; break }
        }
        if ($exePath) {
            $detectedVia = 'WINGET'
            Write-Log ("AnyDesk instalado y encontrado: " + $exePath)
        } else {
            Write-Log "winget instalo pero no se pudo localizar el exe." 'ERROR'
        }
    } catch {
        Write-Log ("winget no disponible o fallo: " + $_) 'ERROR'
    }
}

# Validar exe fisicamente
if ($exePath) {
    $exePath = [string]$exePath
    if (Test-Path $exePath) {
        Write-Log ("Exe validado via " + $detectedVia + " : " + $exePath)
    } else {
        Write-Log ("Ruta encontrada via " + $detectedVia + " pero exe ya no existe: " + $exePath) 'ERROR'
        Write-Log "Abortando para evitar reset sin posibilidad de relaunch." 'ERROR'
        Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
        Write-Host ("`nListo. Log guardado en:`n   " + $logFile)
        exit 1
    }
} else {
    Write-Log "No se pudo encontrar ni instalar AnyDesk. Abortando." 'ERROR'
    Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
    Write-Host ("`nListo. Log guardado en:`n   " + $logFile)
    exit 1
}

$exeDir = Split-Path $exePath -Parent

# Determinar instalado vs standalone
$pfPaths     = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
$isInstalled = [bool]($pfPaths | Where-Object { $exeDir -like "$_*" })
$tipoStr     = if ($isInstalled) { 'INSTALADO' } else { 'STANDALONE' }
Write-Log ("Tipo: " + $tipoStr)

# Version
try {
    $ver = (Get-Item $exePath).VersionInfo.FileVersion
    Write-Log ("Version: " + $ver)
} catch {
    Write-Log "Version: no disponible" 'WARN'
}

# Leer AnyDesk ID ANTES del kill
$confLocations = @("$env:ProgramData\AnyDesk", "$env:AppData\AnyDesk", "$env:LocalAppData\AnyDesk", $exeDir) |
                 Select-Object -Unique
foreach ($loc in $confLocations) {
    $sc = Join-Path $loc 'system.conf'
    if (Test-Path $sc) {
        $idLine = Get-Content $sc -ErrorAction SilentlyContinue |
                  Where-Object { $_ -match 'ad\.anynet\.id\s*=' }
        if ($idLine) {
            $anyDeskId = ($idLine -split '=', 2)[1].Trim()
            Write-Log ("AnyDesk ID (antes del reset): " + $anyDeskId)
            break
        }
    }
}
if (-not $anyDeskId) { Write-Log "AnyDesk ID: no encontrado en system.conf" 'WARN' }

# -- 3. Kill --------------------------------------------------
Write-Step 3 $totalSteps "Terminando procesos AnyDesk..."

$killed = 0
Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' -and
        $_.MainModule.FileName -notlike '*Uninst*'
    } catch { $false }
} | ForEach-Object {
    $_ | Stop-Process -Force
    Write-Log ("Terminado PID " + $_.Id)
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
        try {
            $_.MainModule.FileVersionInfo.ProductName -like '*AnyDesk*' -and
            $_.MainModule.FileName -notlike '*Uninst*'
        } catch { $false }
    }) -and $waited -lt 5
) {
    Start-Sleep -Seconds 1
    $waited++
}
Write-Log ("Procesos terminados (espera: " + $waited + "s)")

# -- 4. Reset .conf con backup timestamped (SIN user.conf) ----
Write-Step 4 $totalSteps "Reseteando configuracion..."

$confDirs = @(
    "$env:ProgramData\AnyDesk",
    "$env:AppData\AnyDesk",
    "$env:LocalAppData\AnyDesk",
    $exeDir
) | Select-Object -Unique

# user.conf excluido: preserva alias y sesiones recientes
$confFiles  = @('system.conf', 'service.conf', 'ad.trace')
$resetCount = 0

foreach ($dir in $confDirs) {
    if (-not (Test-Path $dir)) { continue }
    foreach ($file in $confFiles) {
        $full   = Join-Path $dir $file
        if (-not (Test-Path $full)) { continue }
        $backup = Join-Path $dir ("$file.$ts.backup")
        try {
            Rename-Item $full $backup
            Write-Log ("Backup: " + $backup)
            $resetCount++
        } catch {
            Write-Log ("No se pudo resetear: " + $full + " - " + $_) 'ERROR'
        }
    }
}

Write-Log ($resetCount.ToString() + " archivo(s) reseteado(s)")

# -- 5. Relaunch ----------------------------------------------
Write-Step 5 $totalSteps "Relanzando AnyDesk..."

# 5a. Verificar conectividad
Write-Log "Verificando conectividad a relay.anydesk.com:443..."
try {
    $conn = Test-NetConnection -ComputerName 'relay.anydesk.com' -Port 443 -WarningAction SilentlyContinue
    if ($conn.TcpTestSucceeded) {
        Write-Log "Conectividad OK (relay.anydesk.com:443)"
    } else {
        Write-Log "Sin conectividad a relay.anydesk.com:443 - AnyDesk puede no obtener ID" 'WARN'
    }
} catch {
    Write-Log ("No se pudo verificar conectividad: " + $_) 'WARN'
}

# 5b. Relaunch
try {
    $exePathStr = [string]$exePath
    if ($isInstalled) {
        Start-Service -Name 'AnyDesk' -ErrorAction SilentlyContinue
        Write-Log "Servicio AnyDesk iniciado"
        Start-Process $exePathStr
        Write-Log ("Relaunch OK (instalado): " + $exePathStr)
    } else {
        Start-Process $exePathStr
        Write-Log ("Relaunch OK (standalone): " + $exePathStr)
    }
} catch {
    Write-Log ("Relaunch FALLIDO: " + $_) 'ERROR'
    Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
    Write-Host ("`nListo. Log guardado en:`n   " + $logFile)
    exit 1
}

# 5c. Polling de ID (30s, cada 2s)
$idTimeout  = 30
$idWaited   = 0
$idObtained = $null
$idConfPaths = @(
    "$env:ProgramData\AnyDesk\system.conf",
    ([string]$exeDir + "\system.conf")
) | Select-Object -Unique

Write-Log ("Esperando ID de AnyDesk (timeout: " + $idTimeout + "s)...")

while ($idWaited -lt $idTimeout) {
    Start-Sleep -Seconds 2
    $idWaited += 2
    foreach ($cp in $idConfPaths) {
        if (-not (Test-Path $cp)) { continue }
        $idLine = Get-Content $cp -ErrorAction SilentlyContinue |
                  Where-Object { $_ -match 'ad\.anynet\.id\s*=' }
        if ($idLine) {
            $idObtained = ($idLine -split '=', 2)[1].Trim()
            break
        }
    }
    if ($idObtained) { break }
}

if ($idObtained) {
    Write-Log ("ID obtenido: " + $idObtained + " (espera: " + $idWaited + "s)")
} else {
    Write-Log ("Sin ID tras " + $idTimeout + "s - AnyDesk arranco pero no se registro. Verificar conectividad a relay.anydesk.com:443") 'WARN'
}

# -- 6. Restaurar ad.roster.items del backup ------------------
Write-Step 6 $totalSteps "Restaurando alias y sesiones recientes..."

$rosterDir    = "$env:AppData\AnyDesk"
$userConfNew  = Join-Path $rosterDir 'user.conf'
$userConfBkp  = Join-Path $rosterDir ("user.conf.$ts.backup")

# Si no habia user.conf antes del reset (no se creo backup), no hay nada que restaurar
if (-not (Test-Path $userConfBkp)) {
    Write-Log "No habia backup de user.conf - nada que restaurar" 'WARN'
    Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
    Write-Host ("`nListo. Log guardado en:`n   " + $logFile)
    exit 0
}

# Extraer ad.roster.items del backup
$rosterLine = Get-Content $userConfBkp -ErrorAction SilentlyContinue |
              Where-Object { $_ -match '^ad\.roster\.items\s*=' }

if (-not $rosterLine) {
    Write-Log "ad.roster.items no encontrado en backup de user.conf" 'WARN'
    Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
    Write-Host ("`nListo. Log guardado en:`n   " + $logFile)
    exit 0
}

Write-Log ("ad.roster.items encontrado en backup (" + ($rosterLine.Length) + " chars)")

# Esperar a que AnyDesk genere el nuevo user.conf (timeout 30s)
$ucWaited = 0
$ucTimeout = 30
Write-Log ("Esperando nuevo user.conf (timeout: " + $ucTimeout + "s)...")

while (-not (Test-Path $userConfNew) -and $ucWaited -lt $ucTimeout) {
    Start-Sleep -Seconds 2
    $ucWaited += 2
}

if (-not (Test-Path $userConfNew)) {
    Write-Log "AnyDesk no genero un nuevo user.conf - restaurando backup completo como fallback" 'WARN'
    try {
        Copy-Item $userConfBkp $userConfNew -Force
        Write-Log "Fallback: backup completo de user.conf restaurado"
    } catch {
        Write-Log ("Fallback fallido: " + $_) 'ERROR'
    }
    Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
    Write-Host ("`nListo. Log guardado en:`n   " + $logFile)
    exit 0
}

# Merge: reemplazar o insertar ad.roster.items en el nuevo user.conf
$newContent = Get-Content $userConfNew -ErrorAction SilentlyContinue
if ($newContent -match '^ad\.roster\.items\s*=') {
    # Reemplazar linea existente
    $newContent = $newContent -replace '^ad\.roster\.items\s*=.*', $rosterLine
    Write-Log "ad.roster.items reemplazado en nuevo user.conf"
} else {
    # Insertar al final
    $newContent = $newContent + "`n" + $rosterLine
    Write-Log "ad.roster.items insertado en nuevo user.conf"
}

try {
    Set-Content $userConfNew -Value $newContent -Encoding UTF8
    Write-Log "Restauracion de alias y sesiones recientes completada."
} catch {
    Write-Log ("Error escribiendo nuevo user.conf: " + $_) 'ERROR'
}

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
Write-Host ("`nListo. Log guardado en:`n   " + $logFile)

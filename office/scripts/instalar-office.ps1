# Instalar-Office.ps1 - v1.2
# Instalacion de Microsoft 365 Apps via Office Deployment Tool (ODT)
# - Deteccion y actualizacion automatica del ODT
# - Menu de seleccion de XML dinamico (lee carpeta xml\)
# - Modos: instalar online, descargar offline, instalar offline
# - Log persistente por ejecucion en .\logs\
#
# XMLs disponibles:
#   Configuracion01.xml  ->  M365 Enterprise: Word + Excel + PowerPoint (64 bits, es-es)
#
# Requisitos:
#   - Ejecutar como Administrador
#   - Los archivos XML deben estar en .\xml\

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# ── Constantes ───────────────────────────────────────────────
$ODT_DETAILS_URL = 'https://www.microsoft.com/en-us/download/details.aspx?id=49117'
$ODT_MIN_SIZE_MB = 1
$SETUP_EXE       = '.\setup.exe'
$XML_DIR         = '.\xml'
$LOG_DIR         = '..\logs'
$ts              = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logFile         = "$LOG_DIR\install_$ts.log"

# ── Init ─────────────────────────────────────────────────────
if (-not (Test-Path $LOG_DIR)) { New-Item $LOG_DIR -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $XML_DIR)) { New-Item $XML_DIR -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    $line = "[$ts][$level] $msg"
    Write-Host "   $msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

function Write-Step([int]$n, [int]$total, [string]$msg) {
    Write-Host "`n[$n/$total] $msg" -ForegroundColor Cyan
    Add-Content -Path $logFile -Value "`n--- $msg ---" -Encoding UTF8
}

function Write-Header {
    $lines = @(
        "================================================",
        " Instalar-Office  |  $ts",
        " Host   : $env:COMPUTERNAME",
        " Usuario: $env:USERDOMAIN\$env:USERNAME",
        "================================================"
    )
    foreach ($l in $lines) {
        Write-Host $l -ForegroundColor White
        Add-Content -Path $logFile -Value $l -Encoding UTF8
    }
}

# ── Obtener ultima version ODT desde Microsoft ───────────────
function Get-LatestOdtInfo {
    try {
        $html = (Invoke-WebRequest -Uri $ODT_DETAILS_URL -UseBasicParsing -TimeoutSec 15).Content
        if ($html -match 'officedeploymenttool[_\-][\d]+[\-\.][\d]+\.exe') {
            $filename = $Matches[0]
            # Extraer build: officedeploymenttool_18227-20162.exe -> 18227.20162
            if ($filename -match '_([\d]+)[\-\.]([\d]+)\.exe') {
                $build = "$($Matches[1]).$($Matches[2])"
                return @{ Filename = $filename; Build = $build; Url = $null }
            }
        }
    } catch {
        Write-Log "No se pudo consultar version online del ODT: $_" 'WARN'
    }
    return $null
}

# Extraer build desde URL de descarga embebida en la pagina
function Get-LatestOdtUrl {
    try {
        $html = (Invoke-WebRequest -Uri $ODT_DETAILS_URL -UseBasicParsing -TimeoutSec 15).Content
        if ($html -match 'https://download\.microsoft\.com/[^"'']+officedeploymenttool[^"'']+\.exe') {
            return $Matches[0]
        }
        # Fallback: construir URL desde el nombre del archivo encontrado
        if ($html -match 'officedeploymenttool_([\d]+)-([\d]+)\.exe') {
            $fname = $Matches[0]
            # URL base conocida de Microsoft CDN
            return "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/$fname"
        }
    } catch {}
    return $null
}

# ── Gestion del ODT ──────────────────────────────────────────
function Ensure-Odt {
    Write-Step 1 5 "Verificando Office Deployment Tool..."

    # Buscar ODT existente en el directorio actual
    $existingOdt = Get-ChildItem -Filter 'officedeploymenttool*.exe' -ErrorAction SilentlyContinue |
                   Where-Object { $_.Length -gt ($ODT_MIN_SIZE_MB * 1MB) } |
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1

    # Consultar version online
    Write-Host "   Consultando version actual del ODT en Microsoft..." -ForegroundColor Yellow
    $latest = Get-LatestOdtInfo

    if ($existingOdt) {
        $localBuild = $existingOdt.VersionInfo.FileVersion
        Write-Log "ODT local encontrado: $($existingOdt.Name) | Version: $localBuild"

        if ($latest) {
            Write-Log "Version online disponible: $($latest.Build)"
            $localBuildShort = ($localBuild -split '\.', 3)[2]
        if ($localBuildShort -and $localBuildShort -eq $latest.Build) {
                Write-Log "ODT actualizado. Usando version local."
            } else {
                Write-Log "Nueva version disponible. Descargando..." 'WARN'
                Download-Odt $latest
            }
        } else {
            Write-Log "No se pudo verificar version online. Usando ODT local." 'WARN'
        }
    } else {
        Write-Log "ODT no encontrado localmente. Descargando..."
        if ($latest) {
            Download-Odt $latest
        } else {
            Write-Host ""
            Write-Host "   [-] No se pudo obtener el ODT automaticamente." -ForegroundColor Red
            Write-Host "   [!] Descarga manual: https://aka.ms/odt" -ForegroundColor Yellow
            Write-Host "   [!] Coloca el .exe en esta carpeta y relanza el script." -ForegroundColor Yellow
            Write-Host ""
            pause; exit 1
        }
    }

    # Extraer setup.exe si no existe o si descargamos uno nuevo
    if (-not (Test-Path $SETUP_EXE)) {
        Extract-Odt
    }
}

function Download-Odt($info) {
    $url = Get-LatestOdtUrl
    if (-not $url) {
        Write-Log "No se encontro URL de descarga directa." 'ERROR'
        Write-Host "   [!] Descarga manual: https://aka.ms/odt" -ForegroundColor Yellow
        pause; exit 1
    }

    $destFile = ".\$($info.Filename)"
    Write-Host "   Descargando: $($info.Filename)" -ForegroundColor Yellow
    Write-Log "Descargando ODT desde: $url"

    try {
        Invoke-WebRequest -Uri $url -OutFile $destFile -UseBasicParsing -TimeoutSec 120
        $downloaded = Get-Item $destFile
        if ($downloaded.Length -lt ($ODT_MIN_SIZE_MB * 1MB)) {
            throw "Archivo descargado invalido ($(($downloaded.Length / 1KB).ToString('N0')) KB)"
        }
        Write-Log "Descarga OK: $($info.Filename) ($([Math]::Round($downloaded.Length/1MB,2)) MB)"
        # Eliminar setup.exe anterior para forzar extraccion del nuevo
        if (Test-Path $SETUP_EXE) { Remove-Item $SETUP_EXE -Force }
    } catch {
        Write-Log "Error descargando ODT: $_" 'ERROR'
        if (Test-Path $destFile) { Remove-Item $destFile -Force }
        Write-Host "   [!] Descarga manual: https://aka.ms/odt" -ForegroundColor Yellow
        pause; exit 1
    }

    Extract-Odt
}

function Extract-Odt {
    $odtExe = Get-ChildItem -Filter 'officedeploymenttool*.exe' -ErrorAction SilentlyContinue |
              Where-Object { $_.Length -gt ($ODT_MIN_SIZE_MB * 1MB) } |
              Sort-Object LastWriteTime -Descending |
              Select-Object -First 1

    if (-not $odtExe) {
        Write-Log "No se encontro ningun ODT para extraer." 'ERROR'
        pause; exit 1
    }

    Write-Host "   Extrayendo setup.exe..." -ForegroundColor Yellow
    Write-Log "Extrayendo: $($odtExe.Name)"
    $fullPath = Resolve-Path $odtExe.FullName
    Start-Process -FilePath $fullPath -ArgumentList '/extract:.', '/quiet' -Wait

    if (-not (Test-Path $SETUP_EXE)) {
        Write-Log "Extraccion fallida. setup.exe no encontrado." 'ERROR'
        Write-Host "   [-] La extraccion fallo. El archivo puede estar bloqueado por el sistema." -ForegroundColor Red
        Write-Host "   [!] Intenta desbloquear el .exe: clic derecho > Propiedades > Desbloquear" -ForegroundColor Yellow
        pause; exit 1
    }

    $setupVer = (Get-Item $SETUP_EXE).VersionInfo.FileVersion
    Write-Log "setup.exe extraido correctamente | Version: $setupVer"

    # Eliminar XMLs de muestra extraidos por el ODT
    Get-ChildItem -Filter 'configuration*.xml' -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Log "XML de muestra eliminado: $($_.Name)"
    }
}

# ── Deteccion y desinstalacion de Office ─────────────────────
function Detect-Office {
    Write-Step 2 5 "Detectando instalacion de Office..."

    $officeKey = @(
        'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration'
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($officeKey) {
        $props     = Get-ItemProperty $officeKey -ErrorAction SilentlyContinue
        $version   = $props.VersionToReport
        $channel   = $props.CDNBaseUrl -replace '^.*/', ''
        $clientId  = $props.ProductReleaseIds

        Write-Host ""
        Write-Host "   [!] Se detecto una instalacion de Office:" -ForegroundColor Yellow
        Write-Host "       Version : $version" -ForegroundColor White
        Write-Host "       Canal   : $channel" -ForegroundColor White
        Write-Host "       Producto: $clientId" -ForegroundColor White
        Write-Host ""
        Write-Log "Office detectado: Version=$version Canal=$channel Producto=$clientId"

        Write-Host "   1) Desinstalar Office (SaRACmd) y continuar" -ForegroundColor Yellow
        Write-Host "   2) Instalar encima sin desinstalar" -ForegroundColor Yellow
        Write-Host "   3) Salir" -ForegroundColor White
        Write-Host ""

        do {
            $op = Read-Host "   Opcion"
        } while ($op -notin @('1','2','3'))

        switch ($op) {
            '1' { Uninstall-Office }
            '2' { Write-Log "Usuario eligio instalar encima sin desinstalar." }
            '3' { exit 0 }
        }
    } else {
        Write-Host ""
        Write-Host "   Sin instalacion previa de Office detectada." -ForegroundColor Green
        Write-Log "No se detecto instalacion previa de Office."
        Write-Host ""
        Read-Host "   Enter para continuar"
    }
}

function Uninstall-Office {
    $saraUrl  = 'https://aka.ms/SaRA_EnterpriseVersionFiles'
    $saraZip  = '.\SaRACmd.zip'
    $saraDir  = '.\SaRACmd'
    $saraExe  = "$saraDir\GetHelpCmd.exe"

    Write-Host ""
    Write-Host "   Descargando SaRACmd desde Microsoft..." -ForegroundColor Yellow
    Write-Log "Descargando SaRACmd desde: $saraUrl"

    try {
        Invoke-WebRequest -Uri $saraUrl -OutFile $saraZip -UseBasicParsing -TimeoutSec 120
        Write-Log "Descarga SaRACmd OK."
    } catch {
        Write-Log "Error descargando SaRACmd: $_" 'ERROR'
        Write-Host "   [-] No se pudo descargar SaRACmd. Verifica la conexion." -ForegroundColor Red
        Write-Host "   [!] Descarga manual: https://aka.ms/SaRA_EnterpriseVersionFiles" -ForegroundColor Yellow
        pause; exit 1
    }

    try {
        Expand-Archive -Path $saraZip -DestinationPath $saraDir -Force
        Write-Log "SaRACmd extraido en: $saraDir"
    } catch {
        Write-Log "Error extrayendo SaRACmd: $_" 'ERROR'
        pause; exit 1
    }

    if (-not (Test-Path $saraExe)) {
        # Buscar el exe en subcarpetas (el zip puede tener una carpeta interna)
        $saraExe = Get-ChildItem -Path $saraDir -Filter 'GetHelpCmd.exe' -Recurse -ErrorAction SilentlyContinue |
                   Select-Object -First 1 | Select-Object -ExpandProperty FullName
    }

    if (-not $saraExe) {
        Write-Log "GetHelpCmd.exe no encontrado despues de extraer." 'ERROR'
        pause; exit 1
    }

    Write-Host "   Desinstalando Office (esto puede tardar varios minutos)..." -ForegroundColor Yellow
    Write-Log "Ejecutando SaRACmd: $saraExe"

    # Cerrar procesos de Office antes de desinstalar
    $officeProcs = @('winword','excel','powerpnt','outlook','onenote','msaccess','mspub','teams','lync')
    foreach ($proc in $officeProcs) {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    }

    $result = Start-Process -FilePath $saraExe `
                            -ArgumentList '-S OfficeScrubScenario -AcceptEula' `
                            -Wait -PassThru -NoNewWindow
    $exitCode = $result.ExitCode

    Write-Log "SaRACmd exit code: $exitCode"

    if ($exitCode -eq 0) {
        Write-Host "   [+] Office desinstalado correctamente." -ForegroundColor Green
        Write-Log "Desinstalacion completada exitosamente."
    } else {
        Write-Host "   [!] SaRACmd finalizo con codigo: $exitCode" -ForegroundColor Yellow
        Write-Host "   [!] Continua con la instalacion. Verifica el log si hay problemas." -ForegroundColor Yellow
        Write-Log "SaRACmd finalizo con codigo $exitCode - puede requerir revision." 'WARN'
    }

    # Limpiar archivos temporales de SaRA
    Remove-Item $saraZip -Force -ErrorAction SilentlyContinue
    Remove-Item $saraDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Archivos temporales de SaRACmd eliminados."

    # Esperar que la desinstalacion en segundo plano finalice
    Write-Host ""
    Write-Host "   Esperando que finalice la desinstalacion en segundo plano..." -ForegroundColor Yellow
    $waited = 0
    while ($true) {
        $running = Get-Process -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match 'OfficeClickToRun|OffScrub' }
        if (-not $running) { break }
        Start-Sleep -Seconds 3
        $waited += 3
        Write-Host ("   {0}s - en proceso: {1}" -f $waited, (($running.Name | Select-Object -Unique) -join ', ')) -ForegroundColor Gray
    }

    if ($waited -gt 0) {
        Write-Host "   [+] Desinstalacion en segundo plano completada ($waited s)." -ForegroundColor Green
        Write-Log "Desinstalacion en segundo plano completada tras $waited s."
    } else {
        Write-Host "   [+] No se detectaron procesos pendientes." -ForegroundColor Green
        Write-Log "No se detectaron procesos de desinstalacion en segundo plano."
    }

    Write-Host ""
    Read-Host "   Enter para continuar con la instalacion"
}

# ── Seleccion de XML ─────────────────────────────────────────
function Select-Xml {
    Write-Step 3 5 "Seleccionando configuracion..."

    $xmlFiles = Get-ChildItem -Path $XML_DIR -Filter '*.xml' -ErrorAction SilentlyContinue |
                Sort-Object Name

    if (-not $xmlFiles) {
        Write-Log "No se encontraron archivos XML en $XML_DIR" 'ERROR'
        Write-Host "   [-] Agrega al menos un .xml en la carpeta xml\ y relanza el script." -ForegroundColor Red
        pause; exit 1
    }

    Write-Host ""
    Write-Host "   Configuraciones disponibles:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $xmlFiles.Count; $i++) {
        $xmlFile = $xmlFiles[$i]
		if ($i -gt 0) { Write-Host "" }
        Write-Host "   $($i + 1)) $($xmlFile.Name)" -ForegroundColor Yellow
        try {
            [xml]$xmlContent = Get-Content $xmlFile.FullName -Encoding UTF8
            $desc = $xmlContent.Configuration.Info.Description
            if ($desc) { Write-Host "       $desc" -ForegroundColor Gray }
        } catch {}
    }
    Write-Host ""

    do {
        $sel = Read-Host "   Selecciona una configuracion (1-$($xmlFiles.Count))"
    } while ($sel -notmatch '^\d+$' -or [int]$sel -lt 1 -or [int]$sel -gt $xmlFiles.Count)

    $chosen = $xmlFiles[[int]$sel - 1]
    Write-Log "XML seleccionado: $($chosen.Name)"
    return $chosen.FullName
}

# ── Menu de operacion ─────────────────────────────────────────
function Select-Operation([string]$xmlPath) {
    Write-Step 4 5 "Seleccionando operacion..."

    Write-Host ""
    Write-Host "   1) Instalar Office (online)" -ForegroundColor Yellow
    Write-Host "   2) Descargar archivos para instalacion offline" -ForegroundColor Yellow
    Write-Host "   3) Instalar desde archivos offline ya descargados" -ForegroundColor Yellow
    Write-Host "   4) Salir" -ForegroundColor White
    Write-Host ""

    do {
        $op = Read-Host "   Opcion"
    } while ($op -notin @('1','2','3','4'))

    Write-Log "Operacion seleccionada: $op"

    switch ($op) {
        '1' {
            Write-Step 5 5 "Instalando Office (online)..."
            Write-Log "Ejecutando: setup.exe /configure $xmlPath"
            Start-Process -FilePath (Resolve-Path $SETUP_EXE) `
                          -ArgumentList "/configure `"$xmlPath`"" `
                          -Wait -NoNewWindow
            Write-Log "Instalacion completada."
        }
        '2' {
            Write-Step 5 5 "Descargando archivos de Office para uso offline..."
            Write-Log "Ejecutando: setup.exe /download $xmlPath"
            Start-Process -FilePath (Resolve-Path $SETUP_EXE) `
                          -ArgumentList "/download `"$xmlPath`"" `
                          -Wait -NoNewWindow
            Write-Log "Descarga completada. Archivos en: .\Office\"
            Write-Host "   [+] Archivos guardados en .\Office\" -ForegroundColor Green
        }
        '3' {
            if (-not (Test-Path '.\Office')) {
                Write-Host "   [-] No se encontro la carpeta .\Office\ con archivos offline." -ForegroundColor Red
                Write-Log "Carpeta .\Office\ no encontrada para instalacion offline." 'ERROR'
                pause; exit 1
            }
            Write-Step 5 5 "Instalando Office desde archivos offline..."
            Write-Log "Ejecutando: setup.exe /configure $xmlPath (offline)"
            Start-Process -FilePath (Resolve-Path $SETUP_EXE) `
                          -ArgumentList "/configure `"$xmlPath`"" `
                          -Wait -NoNewWindow
            Write-Log "Instalacion offline completada."
        }
        '4' { exit 0 }
    }
}

# ── Main ─────────────────────────────────────────────────────
Write-Header
Ensure-Odt
Detect-Office
$xmlPath = Select-Xml
Select-Operation $xmlPath

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
Write-Host ""
Write-Host "   Listo. Log guardado en:" -ForegroundColor Green
Write-Host "   $logFile" -ForegroundColor White
Write-Host ""
Read-Host "   Enter para cerrar"
# menu: nwinfo-evidence (NWinfo legacy -> GLPI)
# nwinfo-glpi-evidence.ps1
# WORKAROUND (Windows): lee el SPD real de la RAM con NWinfo y lo usa para
# corregir el inventario de memoria que reporta el GLPI Agent (que se apoya en
# datos SMBIOS erroneos de BIOS viejas: DDR2 en vez de DDR3, etc).
#
# Como funciona:
#   1) Detecta el agente GLPI instalado y genera un INVENTARIO LOCAL con
#      `glpi-agent --local <dir>` (sin --server: NO contacta ningun servidor,
#      escribe el XML local). Ahi estan los <MEMORIES> que el agente reporta.
#   2) Descarga NWinfo v1.6.6 - pack FULL + LITE (si no esta en
#      workarounds\nwinfo\). El LITE trae el driver NwHwIo.sys, que NWinfo
#      elige automaticamente (segundo en su orden de drivers, antes que
#      PawnIO) y es quien lee el SPD por scan PCI directo en chipsets Intel
#      legacy (ICH6-10) donde PawnIO falla.
#   3) Corre `nwinfo.exe --format=json --human --spd --sys` (lectura REAL del
#      SPD por SMBus/I2C, no es lo que dice la BIOS).
#   4) Alinea slot a slot: usa los <DESIGNATION> (pkey) del inventario actual
#      del agente y para cada uno arma el <MEMORIES> corregido con los datos
#      reales del SPD (TYPE, SPEED, CAPACITY, SERIALNUMBER, MANUFACTURER).
#   5) MODO DRY-RUN (default): genera <content>.xml + reporte comparativo
#      local. NO envia nada al servidor.
#   6) El envio es un paso EXPLICITO (lanzar por separado), una de dos:
#      a) con el agente local:      glpi-agent.bat --force --additional-content=<content>.xml
#      b) con el agente instalado:  glpi-agent.bat --force --additional-content=<content>.xml
#      (En ambos casos el agente usa su config/server instalado.)
#
# Requiere: Administrador (descarga a workarounds\nwinfo\). No instala
# servicios en el sistema: el driver NwHwIo se registra y arranca a demanda
# por el propio nwinfo.exe y no queda corriendo. El dry-run deja todo en logs/.
# Reversible: nada se envia en dry-run; la correccion solo llega a GLPI si el
# operador corre el comando de envio. Si el service NwHwIo quedo registrado,
# se limpia con `sc.exe delete NwHwIo`.
#
# Uso:
#   nwinfo-glpi-evidence.ps1                    -> dry-run (idempotente)
#   nwinfo-glpi-evidence.ps1 -ForceRedownload   -> re-baja NWinfo aunque exista
#   nwinfo-glpi-evidence.ps1 -AgentDir <ruta>   -> override de la carpeta del agente
#   nwinfo-glpi-evidence.ps1 -SkipDriver        -> no baja el LITE (solo PawnIO/CPU-Z)
#   nwinfo-glpi-evidence.ps1 -Send              -> corre el envio con glpi-agent

#Requires -RunAsAdministrator
param(
    [switch]$ForceRedownload,
    [string]$AgentDir = '',
    [switch]$SkipDriver,
    [switch]$Send
)
$ErrorActionPreference = 'Stop'

$root    = Split-Path $PSScriptRoot -Parent
$logDir  = Join-Path $root 'logs'
$toolDir = Join-Path $root 'nwinfo'
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logFile = Join-Path $logDir "nwinfo-glpi-evidence_$ts.log"
if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $toolDir)) { New-Item $toolDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    Add-Content -Path $logFile -Value "[$ts][$level] $msg" -Encoding UTF8
    Write-Host "[$level] $msg"
}

# ---------- Detect agent ----------
function Get-AgentBat {
    $dirs = @()
    if ($AgentDir) { $dirs += Join-Path $AgentDir 'bin'; $dirs += $AgentDir }
    $dirs += 'C:\Program Files\GLPI-Agent\bin'
    $dirs += 'C:\Program Files\GLPI-Agent'
    $dirs += 'C:\Program Files (x86)\GLPI-Agent\bin'
    $dirs += 'C:\Program Files (x86)\GLPI-Agent'
    foreach ($d in $dirs) {
        foreach ($name in @('glpi-agent.bat', 'glpi-agent.exe')) {
            $p = Join-Path $d $name
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

# ---------- NWinfo ----------
function Test-NwHwIo {
    # Devuelve: 'PRESENT' | 'MISSING'
    $sys = Join-Path $toolDir 'NwHwIox64.sys'
    if (Test-Path $sys) { return 'PRESENT' }
    return 'MISSING'
}

function Get-NWinfoJson {
    $exe = Join-Path $toolDir 'nwinfo.exe'
    if ($ForceRedownload -or -not (Test-Path $exe)) {
        $zip = Join-Path $toolDir 'NWinfo.zip'
        if (-not $ForceRedownload -and (Test-Path $zip)) {
            Write-Log "Extrayendo NWinfo (FULL) desde ZIP presente: $zip"
        } else {
            Write-Log "Descargando NWinfo v1.6.6 (FULL: nwinfo.exe + PawnIO fallback)..."
            $url = 'https://github.com/a1ive/nwinfo/releases/download/v1.6.6/NWinfo.zip'
            try {
                Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
                Write-Log "Descargado: $zip"
            } catch {
                Write-Log "Fallo de red al bajar NWinfo (FULL): $($_.Exception.Message)" 'ERROR'
                throw "Descargar NWinfo manualmente y dejar el ZIP en: $toolDir"
            }
        }
        Expand-Archive -Path $zip -DestinationPath $toolDir -Force
        Write-Log "Extraido (FULL) en: $toolDir"
    }
    if (-not $SkipDriver -and (Test-NwHwIo) -eq 'MISSING') {
        $liteZip = Join-Path $toolDir 'NWinfoLite.zip'
        if (-not (Test-Path $liteZip)) {
            Write-Log "Descargando NWinfo v1.6.6 (LITE: driver NwHwIo de acceso SPD)..."
            $liteUrl = 'https://github.com/a1ive/nwinfo/releases/download/v1.6.6/NWinfoLite.zip'
            try {
                Invoke-WebRequest -Uri $liteUrl -OutFile $liteZip -UseBasicParsing
                Write-Log "Descargado: $liteZip"
            } catch {
                Write-Log "Fallo de red al bajar NWinfo (LITE): $($_.Exception.Message). NWinfo usara solo PawnIO/CPU-Z." 'WARN'
            }
        }
        if (Test-Path $liteZip) {
            Expand-Archive -Path $liteZip -DestinationPath $toolDir -Force
            Write-Log "Extraido (LITE) en: $toolDir"
        }
    }
    if (-not (Test-Path $exe)) { throw "Falta nwinfo.exe en $exe" }
    $st = Test-NwHwIo
    if (-not $SkipDriver) {
        if ($st -eq 'PRESENT') {
            Write-Log "Driver de acceso SPD (NwHwIo): PRESENTE - NWinfo lo usa automaticamente."
        } else {
            Write-Log "Driver NwHwIo NO presente. NWinfo intentara PawnIO o el driver de CPU-Z (si esta abierta)." 'WARN'
        }
    } else {
        Write-Log "Driver NwHwIo omitido (-SkipDriver). NWinfo usara PawnIO/CPU-Z."
    }
    $json = Join-Path $logDir "nwinfo_$ts.json"
    & $exe --format=json --human --output=$json --sys --spd
    if (-not (Test-Path $json)) { throw "NWinfo no genero el JSON: $json" }
    Write-Log "JSON NWinfo: $json"
    return $json
}

# ---------- Parse helpers ----------
function Convert-ToMB {
    param([string]$s)
    if (-not $s) { return 0 }
    $t = "$s".Trim()
    if ($t -match '^([\d\.\,]+)\s*GB$') { return [math]::Round([double](($matches[1] -replace ',', '.')) * 1024) }
    if ($t -match '^([\d\.\,]+)\s*MB$') { return [math]::Round([double]($matches[1] -replace ',', '.')) }
    $n = 0.0
    if ([double]::TryParse($t -replace ',', '.', [System.Globalization.NumberStyles]::Any,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) {
        if ($n -ge 1024) { return [math]::Round($n * 1024) }  # suponemos GB
        return [math]::Round($n)
    }
    return 0
}

# ---------- Run ----------
Write-Host "================================================"
Write-Host " NWinfo evidence -> GLPI  (Correccion de RAM)"
Write-Host " Host   : $env:COMPUTERNAME"
Write-Host " Modo   : $(if($Send){'ENVIO REAL'}else{'DRY-RUN (no envia)'})"
Write-Host "================================================"
Write-Log "Inicio | Host: $env:COMPUTERNAME | Send: $Send"

# A. Inventario local del agente (sin server)
$agentBat = Get-AgentBat
$agentXml = $null
if ($agentBat) {
    $agentOut = Join-Path $logDir 'agent-local'
    New-Item -ItemType Directory -Force -Path $agentOut | Out-Null
    Write-Log "Generando inventario LOCAL del agente (sin enviar): $agentBat --local $agentOut"
    & $agentBat --local $agentOut 2>&1 | Out-Null
    $agentXml = Get-ChildItem $agentOut -Filter '*.xml' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if ($agentXml) {
        Write-Log "Inventario local del agente: $agentXml"
    } else {
        $agentJson = Get-ChildItem $agentOut -Filter '*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
        if ($agentJson) { Write-Log "Inventario local del agente (JSON): $agentJson"; $agentXml = $agentJson }
        else { Write-Log "El agente no dejo inventario local en $agentOut" 'WARN' }
    }
} else {
    Write-Log "AGENTE GLPI NO DETECTADO. Sin el agente no hay pkey que alinear; el dry-run armara content.xml con DESIGNATION generico DIMM<n>." 'WARN'
}

# B. SPD real con NWinfo
$jsonFile = Get-NWinfoJson
$raw = Get-Content -LiteralPath $jsonFile -Raw -Encoding UTF8 | ConvertFrom-Json

$spd = @()
if ($raw.PSObject.Properties.Name -contains 'SPD') {
    foreach ($slot in @($raw.SPD)) {
        if (-not $slot.PSObject.Properties.Name -contains 'ID') { continue }
        $spd += [pscustomobject]@{
            Slot         = [string]$slot.ID
            Type         = [string]$slot.'Memory Type'
            CapacityMB   = Convert-ToMB ([string]$slot.Capacity)
            Speed        = [string]$slot.'Speed (MHz)'
            Manufacturer = [string]$slot.Manufacturer
            Serial       = [string]$slot.'Serial Number'
            PartNumber   = [string]$slot.'Part Number'
            ModuleType   = [string]$slot.'Module Type'
        }
    }
}
if ($spd.Count -eq 0) {
    Write-Log "NWinfo (--spd) no encontro slots: sin acceso real al SPD no hay correccion posible." 'ERROR'
    $nwhwio = Join-Path $toolDir 'NwHwIox64.sys'
    $hasNwhwio = Test-Path $nwhwio
    Write-Log "Diagnostico: NwHwIox64.sys presente = $hasNwhwio (-SkipDriver activo: $SkipDriver)"
    if (-not $hasNwhwio) {
        Write-Log "Falta el driver NwHwIo (pack LITE de NWinfo). Correr SIN -SkipDriver para descargarlo, o abrir CPU-Z antes (el driver de CPU-Z tambien sirve si esta en uso)." 'WARN'
    } else {
        Write-Log "NwHwIo presente pero NWinfo no leyo el SPD: posible VM sin SMBus real, o chipset sin SMBus accesible via este driver." 'WARN'
    }
    Write-Log "Otros casos sin slots: maquina virtual (sin SMBus real), o chipset sin SMBus accesible."
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}
Write-Log "SPD real detectado: $($spd.Count) slot(s)"

# C. MEMORIES actuales del agente (para la pkey de alineacion)
$current = @()
if ($agentXml) {
    try {
        $agentInv = [xml](Get-Content -LiteralPath $agentXml -Raw -Encoding UTF8)
        $memNodes = @()
        $i = 0
        foreach ($c in $agentInv.GetElementsByTagName('MEMORIES')) {
            $memNodes += [pscustomobject]@{
                Index       = $i++
                Designation = ([string]$c.DESIGNATION).Trim()
                Type        = ([string]$c.TYPE).Trim()
                CapacityMB  = Convert-ToMB ([string]$c.CAPACITY)
                Speed       = ([string]$c.SPEED).Trim()
                Serial      = ([string]$c.SERIALNUMBER).Trim()
            }
        }
        $current = $memNodes
        Write-Log "Memorias en inventario local del agente: $($current.Count)"
    } catch {
        Write-Log "No se pudieron parsear los MEMORIES del inventario local: $($_.Exception.Message)" 'WARN'
    }
}

if ($current.Count -gt 0) {
    Write-Host "`n----- MEMORIAS QUE EL AGENTE REPORTABA (local) -----"
    foreach ($c in $current) {
        Write-Host ("  [" + $c.Index + "] " + $c.Designation + " | " + $c.Type + " | " + $c.CapacityMB + " MB | " + $c.Speed + " | " + $c.Serial)
    }
}

Write-Host "`n----- SPD REAL (NWinfo) -----"
foreach ($m in $spd) {
    Write-Host ("  [Slot " + $m.Slot + "] " + $m.Type + " | " + $m.CapacityMB + " MB | " + $m.Speed + " MHz | " + $m.Manufacturer + " | " + $m.Serial + " | " + $m.PartNumber)
}

# D. Alinear: por indice (slot i <-> memoria i del inventario local)
$resumen = @()
for ($i = 0; $i -lt $spd.Count; $i++) {
    $s = $spd[$i]
    $designation = "DIMM$($s.Slot)"
    $antes = ''
    if ($current.Count -gt $i) {
        $designation = $current[$i].Designation
        $antes = $current[$i].Type + ' ' + $current[$i].CapacityMB + ' MB'
    }
    $despues = "$($s.Type) $($s.CapacityMB) MB $($s.Speed) MHz"
    $estado = if ($antes -and $antes -ne $despues) { '<<< CORRIGE' } else { 'OK' }
    $resumen += [pscustomobject]@{
        Slot        = $s.Slot
        Designation = $designation
        Antes       = $antes
        Despues     = $despues
        Estado      = $estado
    }
}

Write-Host "`n----- COMPARACION -----"
Write-Host ("  {0,-10} {1,-14} {2,-28} {3,-24} {4}" -f 'SLOT', 'DESIGNATION', 'ANTES (agente)', 'DESPUES (SPD real)', '')
foreach ($r in $resumen) {
    Write-Host ("  {0,-10} {1,-14} {2,-28} {3,-24} {4}" -f $r.Slot, $r.Designation, $r.Antes, $r.Despues, $r.Estado)
}

# E. Generar content.xml (MEMORIES corregidas)
$contentFile = Join-Path $logDir "nwinfo-additional-content_$ts.xml"
$mem = ''
foreach ($r in $resumen) {
    $s = $spd[$r.Slot]
    $mem += "      <MEMORIES>`n"
    $mem += "         <DESIGNATION>$($r.Designation)</DESIGNATION>`n"
    $mem += "         <TYPE>$($s.Type)</TYPE>`n"
    if ($s.CapacityMB) { $mem += "         <CAPACITY>$($s.CapacityMB)</CAPACITY>`n" }
    if ($s.Speed)      { $mem += "         <SPEED>$($s.Speed)</SPEED>`n" }
    if ($s.Serial)     { $mem += "         <SERIALNUMBER>$($s.Serial)</SERIALNUMBER>`n" }
    if ($s.Manufacturer){ $mem += "         <MANUFACTURER>$($s.Manufacturer)</MANUFACTURER>`n" }
    $mem += "      </MEMORIES>`n"
}
$xml = @"
<?xml version="1.0" encoding="UTF-8" ?>
<REQUEST>
   <CONTENT>
$mem   </CONTENT>
   <DEVICEID>$env:COMPUTERNAME</DEVICEID>
   <QUERY>INVENTORY</QUERY>
</REQUEST>
"@
Set-Content -Path $contentFile -Value $xml -Encoding UTF8
Write-Log "Content adicional generado: $contentFile"

# F. Envio / instrucciones
if ($Send) {
    if (-not $agentBat) {
        Write-Log "No hay glpi-agent para enviar. Abortando envio." 'ERROR'
        Read-Host "`nPresiona Enter para cerrar"
        exit 1
    }
    Write-Log "Enviando al servidor con --force --additional-content..."
    & $agentBat --force --additional-content=$contentFile 2>&1 | Tee-Object -FilePath (Join-Path $logDir "envio_$ts.log")
    Write-Log "Comando de envio ejecutado. Verificar en GLPI (Computadores > RREI08 > Memorias)."
} else {
    Write-Host "`n=================================================="
    Write-Host " CONTENT XML listo (dry-run): $contentFile"
    Write-Host "`n PARA CORREGIR EN GLPI (paso explicito, por separado):"
    if ($agentBat) {
        Write-Host "  `"$agentBat`" --force --additional-content=`"$contentFile`""
    } else {
        Write-Host "  (sin agente detectado: instalar/configurar glpi-agent y repetir con -Send)"
    }
    Write-Host "`n Este dry-run NO envio nada al servidor." -ForegroundColor Green
    Write-Host " Log: $logFile"
    Write-Host "=================================================="
    Write-Log "Dry-run OK. Nada fue enviado."
}
Read-Host "`nPresiona Enter para cerrar"
#Requires -RunAsAdministrator
# ============================================================
#  glpi-agent-install.ps1 - Instalacion silenciosa - GLPI Agent
#  Servidor: https://soporte.igeek.ar
#  Version: 3.0  (2026-04-30)
# ============================================================

$ErrorActionPreference = 'Stop'

$AGENT_DIR     = "C:\Program Files\GLPI-Agent"
$REPO_GLPI     = "C:\repositorio\GLPI"
$LOG_DIR       = "C:\repositorio\GLPI\logs"
$SHORTCUT_NAME = "GLPI Agent"
$WINGET_ID     = "GLPI-Project.GLPI-Agent"
$SERVER_URL    = "https://soporte.igeek.ar"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ── 0. Detectar instalacion existente ───────────────────────
$instalado = Get-WmiObject -Class Win32_Product -Filter "Name LIKE 'GLPI Agent%'" -ErrorAction SilentlyContinue
if ($instalado) {
    Write-Host "`n[AVISO] GLPI Agent ya esta instalado (version $($instalado.Version))." -ForegroundColor Yellow
    $confirm = Read-Host "Desinstalar la version actual y continuar? [S/N]"
    if ($confirm -notmatch '^[Ss]') {
        Write-Host "Instalacion cancelada." -ForegroundColor Yellow
        pause; exit 0
    }
    Write-Step "Desinstalando version anterior..."
    $proc = Start-Process msiexec -ArgumentList "/x `"$($instalado.LocalPackage)`" /quiet /norestart" -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Err "No se pudo desinstalar. Codigo: $($proc.ExitCode)"
        pause; exit 1
    }
    Write-OK "Desinstalacion completada."
}

# ── 1. Preguntar por AGENTMONITOR ────────────────────────────
Write-Step "Opciones de instalacion"
$respuesta    = Read-Host "Instalar icono de bandeja (AGENTMONITOR)? [S/N]"
$AGENTMONITOR = if ($respuesta -match '^[Ss]') { 1 } else { 0 }

# ── 2. Instalar via winget ───────────────────────────────────
Write-Step "Instalando GLPI Agent via winget..."
$overrideArgs = "/quiet /norestart SERVER=`"$SERVER_URL`" RUNNOW=1 EXECMODE=1 ADD_FIREWALL_EXCEPTION=1 AGENTMONITOR=$AGENTMONITOR"
try {
    winget install -e --id $WINGET_ID --silent --accept-package-agreements --accept-source-agreements --override $overrideArgs
    Write-OK "Instalacion completada correctamente."
} catch {
    Write-Err "La instalacion fallo: $_"
    pause; exit 1
}

# ── 3. Forzar envio al servidor ──────────────────────────────
Write-Step "Forzando envio de inventario al servidor..."
try {
    & "$AGENT_DIR\glpi-agent.bat" --force
    Write-OK "Inventario enviado al servidor."
} catch {
    Write-Err "No se pudo forzar el envio: $_"
}

# ── 4. Generar XML local ─────────────────────────────────────
Write-Step "Generando inventario local XML..."
if (-not (Test-Path $LOG_DIR)) { New-Item $LOG_DIR -ItemType Directory -Force | Out-Null }
$xmlFile = "$LOG_DIR\$env:COMPUTERNAME.xml"
try {
    & "$AGENT_DIR\glpi-inventory.bat" | Out-File $xmlFile -Encoding UTF8
    Write-OK "XML guardado en: $xmlFile"
} catch {
    Write-Err "No se pudo generar el XML: $_"
}

# ── 5. Crear accesos directos ────────────────────────────────
Write-Step "Creando accesos directos al agente..."
if (-not (Test-Path $REPO_GLPI)) { New-Item $REPO_GLPI -ItemType Directory -Force | Out-Null }

# .url
$urlFile = "$REPO_GLPI\$SHORTCUT_NAME.url"
@"
[InternetShortcut]
URL=http://localhost:62354
"@ | Out-File $urlFile -Encoding ASCII
Write-OK "Acceso directo .url creado: $urlFile"

# .lnk
$lnkFile = "$REPO_GLPI\$SHORTCUT_NAME.lnk"
$ws  = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($lnkFile)
$lnk.TargetPath  = "http://localhost:62354"
$lnk.Description = "GLPI Agent - Interfaz local"
$lnk.Save()
Write-OK "Acceso directo .lnk creado: $lnkFile"

Write-Host "`nListo. El agente reportara al servidor en los proximos minutos." -ForegroundColor Green
pause

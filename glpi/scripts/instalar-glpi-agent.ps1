#Requires -RunAsAdministrator
# ============================================================
#  Instalacion silenciosa - GLPI Agent
#  Servidor: https://soporte.igeek.ar
#  Version: 2.0  (2026-04-30)
#
#  TODO: Reemplazar version fija por consulta dinamica a la API de
#        GitHub Releases, validando compatibilidad con la version
#        del servidor GLPI antes de descargar.
#        Ref: https://github.com/glpi-project/glpi-agent/releases
# ============================================================

$ErrorActionPreference = 'Stop'

$GLPI_AGENT_VERSION = "1.17"
$MSI_NAME           = "GLPI-Agent-$GLPI_AGENT_VERSION-x64.msi"
$DOWNLOAD_URL       = "https://github.com/glpi-project/glpi-agent/releases/download/$GLPI_AGENT_VERSION/$MSI_NAME"
$MSI_FILE           = "$env:TEMP\$MSI_NAME"
$AGENT_DIR          = "C:\Program Files\GLPI-Agent"
$REPO_GLPI          = "C:\repositorio\GLPI"
$LOG_DIR            = "C:\repositorio\GLPI\logs"
$SHORTCUT_NAME      = "GLPI Agent"

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

# ── 1. Descargar MSI ─────────────────────────────────────────
Write-Step "Descargando $MSI_NAME desde GitHub..."
try {
    curl.exe -L --fail --silent --show-error --ssl-no-revoke $DOWNLOAD_URL -o $MSI_FILE
    Write-OK "Descarga completada."
} catch {
    Write-Err "No se pudo descargar el instalador."
    Write-Host "URL: $DOWNLOAD_URL"
    Write-Host "Descargue manualmente desde: https://github.com/glpi-project/glpi-agent/releases"
    pause; exit 1
}

# ── 2. Preguntar por AGENTMONITOR ────────────────────────────
Write-Step "Opciones de instalacion"
$respuesta = Read-Host "Instalar icono de bandeja (AGENTMONITOR)? [S/N]"
$AGENTMONITOR = if ($respuesta -match '^[Ss]') { 1 } else { 0 }

# ── 3. Instalar ──────────────────────────────────────────────
Write-Step "Instalando $MSI_NAME..."

$msiArgs = @(
    "/i", $MSI_FILE,
    "/quiet", "/norestart",
    "SERVER=https://soporte.igeek.ar",
    "RUNNOW=1",
    "EXECMODE=1",
    "ADD_FIREWALL_EXCEPTION=1",
    "AGENTMONITOR=$AGENTMONITOR"
)

$proc = Start-Process msiexec -ArgumentList $msiArgs -Wait -PassThru
$installCode = $proc.ExitCode
del $MSI_FILE -Force -ErrorAction SilentlyContinue

if ($installCode -ne 0) {
    Write-Err "La instalacion fallo con codigo: $installCode"
    Write-Host "Revise el log en: C:\Windows\Temp\glpi-agent-install.log"
    pause; exit 1
}
Write-OK "Instalacion completada correctamente."

# ── 4. Forzar envio al servidor ──────────────────────────────
Write-Step "Forzando envio de inventario al servidor..."
try {
    & "$AGENT_DIR\glpi-agent.bat" --force
    Write-OK "Inventario enviado al servidor."
} catch {
    Write-Err "No se pudo forzar el envio: $_"
}

# ── 5. Generar XML local ─────────────────────────────────────
Write-Step "Generando inventario local XML..."
if (-not (Test-Path $LOG_DIR)) { New-Item $LOG_DIR -ItemType Directory -Force | Out-Null }
$xmlFile = "$LOG_DIR\$env:COMPUTERNAME.xml"
try {
    & "$AGENT_DIR\glpi-inventory.bat" | Out-File $xmlFile -Encoding UTF8
    Write-OK "XML guardado en: $xmlFile"
} catch {
    Write-Err "No se pudo generar el XML: $_"
}

# ── 6. Crear accesos directos ────────────────────────────────
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
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($lnkFile)
$lnk.TargetPath = "http://localhost:62354"
$lnk.Description = "GLPI Agent - Interfaz local"
$lnk.Save()
Write-OK "Acceso directo .lnk creado: $lnkFile"

Write-Host "`nListo. El agente reportara al servidor en los proximos minutos." -ForegroundColor Green
pause

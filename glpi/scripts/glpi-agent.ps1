#Requires -RunAsAdministrator
# ============================================================
#  glpi-agent.ps1 - Instalacion silenciosa - GLPI Agent
#  Servidor: configurable al ejecutar
#  Version: 3.1  (2026-09-12)
#  v3.1: opcion "solo cambiar servidor" sin reinstalar +
#        comparador de version instalada/disponible
# ============================================================
$ErrorActionPreference = 'Stop'
$AGENT_DIR     = "C:\Program Files\GLPI-Agent"
$REPO_GLPI     = "C:\repositorio\GLPI"
$LOG_DIR       = "C:\repositorio\GLPI\logs"
$SHORTCUT_NAME = "GLPI Agent"
$WINGET_ID     = "GLPI-Project.GLPI-Agent"
Write-Host "`nURL del servidor GLPI (ej: https://servidor.example.com):" -ForegroundColor Cyan
$SERVER_URL    = Read-Host "Servidor"
if ([string]::IsNullOrWhiteSpace($SERVER_URL)) {
    Write-Host "URL requerida. Saliendo." -ForegroundColor Red
    exit 1
}

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ── Cambiar servidor sin reinstalar ─────────────────────────
function Update-Server {
    param([string]$NewUrl)

    Write-Step "Cambiando servidor GLPI..."
    $actual = (Get-ItemProperty -Path "HKLM:\SOFTWARE\GLPI-Agent" -Name "server" -ErrorAction SilentlyContinue).server

    # Idempotencia: si ya esta configurado con el mismo server
    if ($actual -and $actual -eq $NewUrl) {
        Write-Host "[AVISO] El servidor ya esta configurado con esa URL ($actual)." -ForegroundColor Yellow
        $rehacer = Read-Host "Re-hacer? (S/N)"
        if ($rehacer -notmatch '^[Ss]') {
            Write-Host "Sin cambios. Saliendo." -ForegroundColor Yellow
            pause; exit 0
        }
    }

    Set-ItemProperty -Path "HKLM:\SOFTWARE\GLPI-Agent" -Name "server" -Value $NewUrl
    Write-OK "Registro actualizado: $NewUrl"

    # Variante 32-bit (solo si existe)
    if (Test-Path "HKLM:\SOFTWARE\Wow6432Node\GLPI-Agent") {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\GLPI-Agent" -Name "server" -Value $NewUrl
        Write-OK "Registro 32-bit (Wow6432Node) actualizado."
    }

    # Reiniciar el servicio para que tome la config
    Write-Step "Reiniciando servicio GLPI-Agent..."
    try {
        Restart-Service -Name "GLPI-Agent" -Force
        Write-OK "Servicio reiniciado."
    } catch {
        Write-Err "No se pudo reiniciar el servicio: $_"
    }

    # Forzar envio al servidor
    Write-Step "Forzando envio de inventario al servidor..."
    try {
        & "$AGENT_DIR\glpi-agent.bat" --force
        Write-OK "Inventario enviado al servidor."
    } catch {
        Write-Err "No se pudo forzar el envio: $_"
    }
}

# ── 0. Detectar instalacion existente ───────────────────────
$instalado = Get-WmiObject -Class Win32_Product -Filter "Name LIKE 'GLPI Agent%'" -ErrorAction SilentlyContinue
if ($instalado) {
    $verInstalada  = "v" + ($instalado.Version -replace '^v','')
    # Version disponible via winget (no bloqueante: si falla, se omite el dato)
    $verDisponible = ""
    try {
        $wingetOut = winget show -e --id $WINGET_ID --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
        $m = [regex]::Match($wingetOut, "(?:Available\s+Version|Versi[oó]n\s+(?:disponible|available))\s*:\s*([^\r\n]+)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { $verDisponible = "v" + ($m.Groups[1].Value.Trim() -replace '^v','') }
    } catch { }

    $serverActual = (Get-ItemProperty -Path "HKLM:\SOFTWARE\GLPI-Agent" -Name "server" -ErrorAction SilentlyContinue).server

    Write-Host "`n=== GLPI Agent ya esta instalado ===" -ForegroundColor Yellow
    Write-Host "  Version instalada:   $verInstalada"
    if ($verDisponible) {
        $estado = if ($verDisponible -ne $verInstalada) { " (hay actualizacion)" } else { " (actualizada)" }
        Write-Host "  Version disponible:  $verDisponible$estado"
    } else {
        Write-Host "  Version disponible:  no se pudo consultar"
    }
    if ($serverActual) { Write-Host "  Servidor actual:     $serverActual" }
    Write-Host "  Servidor a usar:     $SERVER_URL"
    Write-Host ""
    Write-Host "[1] Solo cambiar servidor (sin reinstalar)" -ForegroundColor Cyan
    Write-Host "[2] Reinstalar (actualiza version + configura)" -ForegroundColor Cyan
    Write-Host "[3] Cancelar" -ForegroundColor Cyan
    $opcion = Read-Host "Opcion"
    switch ($opcion) {
        "1" {
            Update-Server -NewUrl $SERVER_URL
            Write-Host "`nListo. El agente reportara al nuevo servidor en los proximos minutos." -ForegroundColor Green
            pause; exit 0
        }
        "2" { }  # sigue al flujo de desinstalacion abajo
        default {
            Write-Host "Instalacion cancelada." -ForegroundColor Yellow
            pause; exit 0
        }
    }

    # Opcion 2: desinstalar version actual e instalar la nueva
    Write-Step "Reinstalando: desinstalando version anterior..."
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

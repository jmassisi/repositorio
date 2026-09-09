# instalar-aplicaciones.ps1
# Instala aplicaciones via winget desde una lista (apps.json).
# Seleccion multiple: numeros separados por coma (1,3,5), 't' = todas, Enter = cancelar.
# Requiere: Administrador | winget disponible (Windows 11 / Win10 reciente)

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'

$root    = Split-Path $PSScriptRoot -Parent
$appsJson = Join-Path $root 'apps.json'
$logDir  = Join-Path $root 'logs'
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logFile = Join-Path $logDir "instalar-aplicaciones_$ts.log"

if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    Add-Content -Path $logFile -Value "[$ts][$level] $msg" -Encoding UTF8
}

function Get-WingetExe {
    # (a) alias / PATH normal
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
        return $cmd.Source
    }
    # (b) motor Appx directo (alias de WindowsApps roto o desactivado)
    $pkg = Get-AppxPackage Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg -and $pkg.InstallLocation) {
        $exe = Join-Path $pkg.InstallLocation 'winget.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

$wingetExe = Get-WingetExe
if (-not $wingetExe) {
    Write-Host "`n   [-] winget no esta disponible en este equipo." -ForegroundColor Red
    Write-Host "   [!] Instalalo desde la Microsoft Store o https://github.com/microsoft/winget-cli" -ForegroundColor Yellow
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}
Write-Host "   Winget  : $wingetExe" -ForegroundColor DarkGray
Write-Log "Winget resuelto: $wingetExe"

if (-not (Test-Path $appsJson)) {
    Write-Host "`n   [-] No se encontro apps.json en: $appsJson" -ForegroundColor Red
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

$apps = Get-Content -Raw $appsJson -Encoding UTF8 | ConvertFrom-Json
if ($apps -isnot [System.Array]) { $apps = @($apps) }
if ($apps.Count -eq 0) {
    Write-Host "`n   [-] apps.json no tiene aplicaciones." -ForegroundColor Red
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

Write-Host "================================================"
Write-Host " WINGET - INSTALACION DE APLICACIONES"
Write-Host " Host   : $env:COMPUTERNAME"
Write-Host "================================================"
Add-Content -Path $logFile -Value "================================================
 WINGET  |  $ts
 Host   : $env:COMPUTERNAME
 Usuario: $env:USERDOMAIN\$env:USERNAME
================================================" -Encoding UTF8

Write-Host ""
Write-Host "   Aplicaciones disponibles:" -ForegroundColor White
for ($i = 0; $i -lt $apps.Count; $i++) {
    Write-Host ("   {0,2}) {1}" -f ($i + 1), $apps[$i].nombre) -ForegroundColor Yellow
}
Write-Host ""
Write-Host "   Seleccion multiple: 1,3,5   |   t = todas   |   Enter = cancelar" -ForegroundColor Cyan

$input = Read-Host "   Seleccione"

if ([string]::IsNullOrWhiteSpace($input)) {
    Write-Host "   Cancelado." -ForegroundColor Gray
    exit 0
}

$indices = @()
if ($input -match '^t$') {
    $indices = @(0..($apps.Count - 1))
} else {
    $tokens = $input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    foreach ($tok in $tokens) {
        $n = 0
        if ([int]::TryParse($tok, [ref]$n) -and $n -ge 1 -and $n -le $apps.Count) {
            $indices += ($n - 1)
        } else {
            Write-Host ("   [!] Ignorando seleccion invalida: '{0}'" -f $tok) -ForegroundColor Red
        }
    }
}

$indices = $indices | Select-Object -Unique
if ($indices.Count -eq 0) {
    Write-Host "   Ninguna seleccion valida. Saliendo." -ForegroundColor Red
    exit 1
}

$total = $indices.Count
$ok = 0
$fail = 0

for ($k = 0; $k -lt $total; $k++) {
    $idx   = $indices[$k]
    $app   = $apps[$idx]
    $num   = $k + 1

    Write-Host ("`n[{0}/{1}] Instalando: {2} ({3})" -f $num, $total, $app.nombre, $app.id) -ForegroundColor Cyan
    Add-Content -Path $logFile -Value "--- [$num/$total] $($app.nombre) ($($app.id)) ---" -Encoding UTF8

    $wingetArgs = @('install','-e','--id',$app.id,'--silent','--accept-package-agreements','--accept-source-agreements')
    if ($app.args) { $wingetArgs += $app.args.Trim() -split '\s+' }
    $exitCode = 0
    try {
        & $wingetExe @wingetArgs *>&1 | ForEach-Object {
            Write-Host "   $_"
            Add-Content -Path $logFile -Value "   $_" -Encoding UTF8
        }
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 1
        $msg = "Error ejecutando winget: $_"
        Write-Host "   $msg" -ForegroundColor Red
        Add-Content -Path $logFile -Value "   $msg" -Encoding UTF8
    }

    if ($exitCode -eq 0) {
        Write-Host "   [+] OK: $($app.nombre)" -ForegroundColor Green
        Add-Content -Path $logFile -Value "   OK: $($app.nombre) (exit $exitCode)" -Encoding UTF8
        $ok++
    } else {
        Write-Host "   [!] FALLO: $($app.nombre) (exit $exitCode). Ver detalle en el log por app." -ForegroundColor Yellow
        Add-Content -Path $logFile -Value "   FALLO: $($app.nombre) (exit $exitCode)" -Encoding UTF8
        $fail++
    }
}

Write-Host ""
Write-Host ("   Resultado: {0} OK  |  {1} FALLO" -f $ok, $fail)
if ($fail -gt 0) { Write-Host "   Revisa el log por app:" -ForegroundColor Yellow; Write-Host "   $logFile" -ForegroundColor Yellow }
Write-Host ""
Read-Host "   Presiona Enter para cerrar"
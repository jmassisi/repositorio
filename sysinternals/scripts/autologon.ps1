# autologon.ps1
# Descarga Autologon y Autologon64 de Sysinternals a C:\repositorio\sysinternals\autologon\
# Idempotente: si los binarios ya existen, avisa y pregunta si re-descargar.

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'

$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$destDir = 'C:\repositorio\sysinternals\autologon'
$logDir  = "$destDir\logs"
$logFile = "$logDir\autologon_$ts.log"

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

function Abrir-Autologon {
    Write-Host ""
    $abrir = Read-Host "Abrir Autologon ahora? (S/N)"
    if ($abrir -match '^[sS]$') {
        $exe = if ([Environment]::Is64BitOperatingSystem) { 'Autologon64.exe' } else { 'Autologon.exe' }
        $path = Join-Path $destDir $exe
        if (Test-Path $path) {
            Start-Process $path
            Write-Log "OK: se abrio $path"
        } else {
            Write-Log "ERROR: no se pudo abrir $path"
        }
    }
}

Add-Content -Path $logFile -Value "================================================" -Encoding UTF8
Add-Content -Path $logFile -Value " autologon  |  $ts"                       -Encoding UTF8
Add-Content -Path $logFile -Value " Host   : $env:COMPUTERNAME"                       -Encoding UTF8
Add-Content -Path $logFile -Value " Usuario: $env:USERDOMAIN\$env:USERNAME"           -Encoding UTF8
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8

$binarios = @('Autologon.exe', 'Autologon64.exe')
$faltantes = @($binarios | Where-Object { -not (Test-Path (Join-Path $destDir $_)) })

if ($faltantes.Count -eq 0) {
    Write-Host ""
    Write-Host "[=] Autologon ya esta descargado en: $destDir" -ForegroundColor Yellow
    foreach ($bin in $binarios) { Write-Host "    - $destDir\$bin" }
    $re = Read-Host "`nRe-descargar de todas formas? (S/N)"
    if ($re -notmatch '^[sS]$') {
        Write-Log "SKIP: binarios ya presentes, no se re-descargo"
        Abrir-Autologon
        Write-Host ""
        Write-Host "Listo." -ForegroundColor Green
        Read-Host "`nPresiona Enter para volver al menu"
        exit 0
    }
    Write-Log "AVISO: re-descarga forzada por el usuario"
}

$totalSteps = 2

foreach ($i in 0..($binarios.Count - 1)) {
    $bin  = $binarios[$i]
    $url  = "https://live.sysinternals.com/$bin"
    $dest = "$destDir\$bin"

    Write-Step ($i + 1) $totalSteps "Descargando $bin..."

    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        $size = (Get-Item $dest).Length
        Write-Log "OK: $dest ($size bytes)"
    } catch {
        Write-Log "FALLO descarga de $bin : $_" 'ERROR'
    }
}

Write-Host ""
Write-Host "Autologon instalado en:" -ForegroundColor Cyan
Write-Host "   $destDir" -ForegroundColor Green
foreach ($bin in $binarios) { Write-Host "   $destDir\$bin" -ForegroundColor Green }
Abrir-Autologon

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
Write-Host ("`nListo. Log guardado en:`n   " + $logFile)
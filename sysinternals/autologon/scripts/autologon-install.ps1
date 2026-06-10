# autologon-install.ps1
# Descarga Autologon y Autologon64 de Sysinternals a C:\repositorio\sysinternals\autologon\

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'

$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$destDir = 'C:\repositorio\sysinternals\autologon'
$logDir  = "$destDir\logs"
$logFile = "$logDir\instalar-autologon_$ts.log"

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

$totalSteps = 2

Add-Content -Path $logFile -Value "================================================" -Encoding UTF8
Add-Content -Path $logFile -Value " instalar-autologon  |  $ts"                       -Encoding UTF8
Add-Content -Path $logFile -Value " Host   : $env:COMPUTERNAME"                       -Encoding UTF8
Add-Content -Path $logFile -Value " Usuario: $env:USERDOMAIN\$env:USERNAME"           -Encoding UTF8
Add-Content -Path $logFile -Value "================================================" -Encoding UTF8

$binarios = @('Autologon.exe', 'Autologon64.exe')

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

Add-Content -Path $logFile -Value "`n================================================`n" -Encoding UTF8
Write-Host ("`nListo. Log guardado en:`n   " + $logFile)

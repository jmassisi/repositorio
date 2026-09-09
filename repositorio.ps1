param([switch]$Actualizar)

$ErrorActionPreference = 'Stop'

# Auto-elevacion: renombrar/mover en C:\ requiere admin. Si no lo somos,
# relanzarse elevado (mismo contenido) y salir del proceso actual.
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Solicitando permisos de administrador..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command "irm repositorio.igeek.ar | iex"'
    return
}

$d       = "C:\repositorio"
$z       = "$env:TEMP\r.zip"
$logsBak = "$env:TEMP\repositorio_logs"
$ts      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$log     = "$env:TEMP\repositorio_$ts.log"

# Fix causa raiz: el proceso hereda CWD=C:\repositorio (lo lanza el menu) y eso
# bloquea el Rename-Item de la carpeta -> "proceso en uso". Forzamos CWD fuera.
$origCwd = (Get-Location).Path
Set-Location $env:TEMP

Add-Content $log -Value "$ts  === repositorio.ps1 inicio (PID $PID) ===" -Encoding UTF8

function Log {
    param([string]$m)
    Add-Content $log -Value "$(Get-Date -Format 'HH:mm:ss')  $m" -Encoding UTF8
}

function Descargar {
    Log "Descargar: comienza"
    try {
        $shell = New-Object -ComObject Shell.Application
        $shell.Windows() | Where-Object { $_.LocationURL -like "*repositorio*" } | ForEach-Object { $_.Quit() }
    } catch {
        Log "aviso: no se cerraron ventanas explorer: $_"
    }
    Start-Sleep -Seconds 1

    if (Test-Path $logsBak) { Remove-Item $logsBak -Recurse -Force }
    Copy-Item "$d\*\logs" $logsBak -Recurse -Force -EA 0
    Log "logs actuales respaldados en $logsBak"

    Log "descargando main.zip..."
    irm https://github.com/jmassisi/repositorio/archive/refs/heads/main.zip -OutFile $z
    Log "zip: $z ($((Get-Item $z).Length) bytes)"

    Expand-Archive $z "$env:TEMP\rextract" -Force
    Log "extraido hacia $env:TEMP\rextract"

    $renamed = $false
    if (Test-Path $d) {
        $bkp = "C:\repositorio_bkp_$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"
        if (Test-Path $bkp) { Rename-Item $bkp "$bkp.old" -Force }
        try {
            Rename-Item $d $bkp -Force
            Log "OK: rename $d -> $bkp"
            $renamed = $true
        } catch {
            $renamed = $false
            Log "aviso: rename fallo (${d} en uso): $($_.Exception.Message) -> sync robocopy"
        }
        if (-not $renamed) {
            robocopy $d $bkp /E /H /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
            Log "OK: bkp por copia $d -> $bkp (solo sobrevive a carpeta en uso)"
        }
    }

    if ($renamed -or -not (Test-Path $d)) {
        Move-Item "$env:TEMP\rextract\repositorio-main" $d -Force
        Log "movido repositorio-main -> $d"
    } else {
        robocopy "$env:TEMP\rextract\repositorio-main" $d /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
        Log "sync robocopy repositorio-main -> $d"
    }

    Remove-Item "$env:TEMP\rextract",$z -Recurse -Force
    Get-ChildItem $logsBak -Directory -EA 0 | ForEach-Object {
        $dest = "$d\$($_.Name)\logs"
        if (Test-Path $dest) { Copy-Item "$($_.FullName)\*" $dest -Recurse -Force -EA 0 }
    }
    Remove-Item $logsBak -Recurse -Force -EA 0
    Remove-Item "$d\.gitignore","$d\PENDIENTES.md" -Force -EA 0
    Get-ChildItem $d -Recurse -Filter '.gitkeep' | Remove-Item -Force -EA 0
    Log "Descargar: fin OK"
}

try {
    if (-not (Test-Path $d)) {
        Log "C:\repositorio no existe -> instalacion inicial"
        Descargar
    } else {
        $local = (Get-Item $d).LastWriteTime
        $commit = (irm 'https://api.github.com/repos/jmassisi/repositorio/commits?per_page=1')[0].commit
        $remoto = ([datetime]$commit.committer.date).ToLocalTime()
        Log "local=$local remoto=$remoto"
        if ($remoto -gt $local) {
            Write-Host "Actualizacion disponible (GitHub: $($remoto.ToLocalTime()))" -ForegroundColor Yellow
            if ($Actualizar) {
                Descargar
            } else {
                Write-Host "[A] Actualizar   [Enter] Cancelar" -ForegroundColor Cyan
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                if ($key.Character -eq 'a' -or $key.Character -eq 'A') { Descargar }
            }
        } else {
            Log "todo actualizado ($local)"
            Write-Host "Todo actualizado ($local)" -ForegroundColor Green
        }
    }
} catch {
    Log "ERROR GLOBAL: $($_.Exception.Message)"
    Log $_.ScriptStackTrace
    Write-Host "`n[ERR] La actualizacion fallo. Detalle en el log:" -ForegroundColor Red
    Write-Host "   $log" -ForegroundColor Yellow
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

if ($Actualizar) {
    Log "repositorio actualizado"
    Write-Host "Repositorio actualizado." -ForegroundColor Green
    Write-Host "Log: $log" -ForegroundColor Yellow
    Read-Host "`nPresiona Enter para cerrar"
} else {
    Remove-Item (Get-PSReadLineOption).HistorySavePath -EA 0; Clear-History
    Set-Location $origCwd
    Write-Host "Listo. Presione cualquier tecla para abrir la carpeta..." -ForegroundColor Green
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Start-Process explorer.exe $d
}
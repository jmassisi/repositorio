while ($true) {
    Clear-Host
    Write-Host "================================="
    Write-Host "           REPOSITORIO           "
    Write-Host "================================="
    Write-Host ""
    $local = (Get-Item C:\repositorio).LastWriteTime
    try {
        $commit = (irm 'https://api.github.com/repos/jmassisi/repositorio/commits?per_page=1')[0].commit
        $remoto = [datetime]$commit.committer.date
        $github = $remoto.ToLocalTime()
    } catch {
        $github = $null
    }
    $formato = 'dd/MM/yyyy HH:mm:ss'
    Write-Host "Local:  $($local.ToString($formato))"
    if ($github) {
        Write-Host "GitHub: $($github.ToString($formato))"
        if ($github -gt $local) {
            Write-Host "[A] Actualizar ahora" -ForegroundColor Yellow
        } else {
            Write-Host "Todo actualizado" -ForegroundColor Green
        }
    } else {
        Write-Host "GitHub: consulta fallida (revisa conexion)" -ForegroundColor Red
        Write-Host "Todo actualizado" -ForegroundColor Green
    }
    Write-Host "----------------------------"
    Write-Host ""
    $rutas = Get-ChildItem "C:\repositorio\*\scripts\*.ps1" | Where-Object { $_.Name -notmatch "check" }
    $utilidades = $rutas | Group-Object { $_.Directory.Parent.Name } | Sort-Object Name
    $i = 1
    $utilidades | ForEach-Object { Write-Host "[$i] $($_.Name)"; $i++ }
    Write-Host ""
    Write-Host "----------------------------"
    Write-Host "[0] Salir"
    Write-Host ""
    $sel = Read-Host "Seleccione"
    if ($sel -eq "0") { exit }
    if ($sel -eq "A" -or $sel -eq "a") {
        Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\repositorio.ps1" -Actualizar' -Verb RunAs
        exit
    }
    $utilidad = $utilidades[$sel - 1]
    if (-not $utilidad) {
        Write-Host "Opcion invalida" -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }
    if ($utilidad.Count -eq 1) {
        $elegido = $utilidad.Group
        Set-Location $elegido.DirectoryName
        powershell -ExecutionPolicy Bypass -File $elegido.FullName
    } else {
        while ($true) {
            Clear-Host
            Write-Host "================================="
            Write-Host "           $($utilidad.Name.ToUpper())           "
            Write-Host "================================="
            Write-Host ""
            $j = 1
            $utilidad.Group | ForEach-Object { Write-Host "[$j] $($_.BaseName)"; $j++ }
            Write-Host ""
            Write-Host "[0] Volver"
            Write-Host ""
            $sub = Read-Host "Seleccione"
            if ($sub -eq "0") { break }
            $elegido = $utilidad.Group[$sub - 1]
            if ($elegido) {
                Set-Location $elegido.DirectoryName
                powershell -ExecutionPolicy Bypass -File $elegido.FullName
            } else {
                Write-Host "Opcion invalida" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}
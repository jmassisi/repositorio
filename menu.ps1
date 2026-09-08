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
    $scripts = Get-ChildItem "C:\repositorio\*\scripts\*.ps1" | Where-Object { $_.Name -notmatch "check" }
    $i = 1
    $scripts | ForEach-Object { Write-Host "[$i] $($_.BaseName)"; $i++ }
    Write-Host ""
    Write-Host "----------------------------"
    Write-Host "[0] Salir"
    Write-Host ""
    $sel = Read-Host "Seleccione"
    if ($sel -eq "0") { exit }
    if ($sel -eq "A" -or $sel -eq "a") {
        Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\repositorio.ps1"' -Verb RunAs
        exit
    }
    $elegido = $scripts[$sel - 1]
    if ($elegido) {
        Set-Location $elegido.DirectoryName
        powershell -ExecutionPolicy Bypass -File $elegido.FullName
    } else {
        Write-Host "Opcion invalida" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}
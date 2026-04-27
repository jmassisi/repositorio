$local = (Get-Item C:\repositorio).LastWriteTime
$remoto = [datetime](irm https://api.github.com/repos/jmassisi/repositorio/commits/main).commit.author.date
Write-Host "Local:  $local"
Write-Host "GitHub: $($remoto.ToLocalTime())"
if ($remoto -gt $local) { 
    Write-Host "HAY ACTUALIZACIONES DISPONIBLES" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[A] Actualizar ahora   [Enter] Salir" -ForegroundColor Cyan
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.Character -eq 'a' -or $key.Character -eq 'A') {
        irm repositorio.igeek.ar | iex
    }
} else { 
    Write-Host "Todo actualizado" -ForegroundColor Green
    pause
}
$local = (Get-Item C:\repositorio).LastWriteTime
$remoto = [datetime](irm https://api.github.com/repos/jmassisi/repositorio/commits/main).commit.author.date
Write-Host "Local:  $local"
Write-Host "GitHub: $($remoto.ToLocalTime())"
if ($remoto -gt $local) { 
    Write-Host "HAY ACTUALIZACIONES DISPONIBLES - correr: irm repositorio.igeek.ar | iex" -ForegroundColor Yellow 
} else { 
    Write-Host "Todo actualizado" -ForegroundColor Green 
}
pause
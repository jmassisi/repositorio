$d="C:\repositorio";$z="$env:TEMP\r.zip"
irm https://github.com/jmassisi/repositorio/archive/refs/heads/main.zip -OutFile $z
Expand-Archive $z $env:TEMP\rextract -Force
if (Test-Path $d) { Remove-Item $d -Recurse -Force }
Move-Item "$env:TEMP\rextract\repositorio-main" $d -Force
Remove-Item "$env:TEMP\rextract" -Recurse -Force
Remove-Item $z -Force
Remove-Item (Get-PSReadLineOption).HistorySavePath -EA 0;Clear-History
Write-Host "Listo. Presione cualquier tecla para cerrar y abrir la carpeta..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Process explorer.exe $d
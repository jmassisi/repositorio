$d="C:\repositorio";$z="$env:TEMP\r.zip"
if (Test-Path $d) {
    $shell = New-Object -ComObject Shell.Application
    $shell.Windows() | Where-Object {$_.LocationURL -like "*repositorio*"} | ForEach-Object {$_.Quit()}
    Start-Sleep -Seconds 1
    # Preservar logs
    $logsBak = "$env:TEMP\repositorio_logs"
    if (Test-Path $logsBak) { Remove-Item $logsBak -Recurse -Force }
    Copy-Item "$d\*\logs" $logsBak -Recurse -Force -EA 0
    Remove-Item $d -Recurse -Force
}
irm https://github.com/jmassisi/repositorio/archive/refs/heads/main.zip -OutFile $z
Expand-Archive $z $env:TEMP\rextract -Force
Move-Item "$env:TEMP\rextract\repositorio-main" $d -Force
Remove-Item "$env:TEMP\rextract" -Recurse -Force
Remove-Item $z -Force
# Restaurar logs
Get-ChildItem $logsBak -Directory -EA 0 | ForEach-Object {
    $dest = "$d\$($_.Name)\logs"
    if (Test-Path $dest) { Copy-Item "$($_.FullName)\*" $dest -Recurse -Force -EA 0 }
}
Remove-Item $logsBak -Recurse -Force -EA 0
Remove-Item "$d\.gitignore" -Force -EA 0
Remove-Item "$d\repositorio.ps1" -Force -EA 0
Remove-Item "$d\PENDIENTES.md" -Force -EA 0
Get-ChildItem $d -Recurse -Filter '.gitkeep' | Remove-Item -Force -EA 0
Remove-Item (Get-PSReadLineOption).HistorySavePath -EA 0;Clear-History
Write-Host "Listo. Presione cualquier tecla para cerrar y abrir la carpeta..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Process explorer.exe $d

$d="C:\repositorio";$z="$env:TEMP\r.zip"
if (Test-Path $d) { 
    $shell = New-Object -ComObject Shell.Application
    $shell.Windows() | Where-Object {$_.LocationURL -like "*repositorio*"} | ForEach-Object {$_.Quit()}
    Start-Sleep -Seconds 1
    Rename-Item $d "C:\repositorio_OLD" -Force 
}
irm https://github.com/jmassisi/repositorio/archive/refs/heads/main.zip -OutFile $z
Expand-Archive $z $env:TEMP\rextract -Force
Move-Item "$env:TEMP\rextract\repositorio-main" $d -Force
Remove-Item "$env:TEMP\rextract" -Recurse -Force
Remove-Item $z -Force
Remove-Item "$d\.gitignore" -Force -EA 0
Remove-Item "$d\repositorio.ps1" -Force -EA 0
Remove-Item "$d\PENDIENTES.md" -Force -EA 0
Remove-Item (Get-PSReadLineOption).HistorySavePath -EA 0;Clear-History
Write-Host "Listo. Presione cualquier tecla para cerrar y abrir la carpeta..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Process explorer.exe $d
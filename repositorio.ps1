$d="C:\repositorio";$z="$env:TEMP\r.zip";$logsBak="$env:TEMP\repositorio_logs"

function Descargar {
    if (Test-Path $logsBak) { Remove-Item $logsBak -Recurse -Force }
    Copy-Item "$d\*\logs" $logsBak -Recurse -Force -EA 0
    if (Test-Path $d) { 
        $shell = New-Object -ComObject Shell.Application
        $shell.Windows() | Where-Object {$_.LocationURL -like "*repositorio*"} | ForEach-Object {$_.Quit()}
        Start-Sleep -Seconds 1
        Rename-Item $d "C:\repositorio_bkp_$(Get-Date -Format 'yyyy-MM-dd')" -Force 
    }
    irm https://github.com/jmassisi/repositorio/archive/refs/heads/main.zip -OutFile $z
    Expand-Archive $z $env:TEMP\rextract -Force
    Move-Item "$env:TEMP\rextract\repositorio-main" $d -Force
    Remove-Item "$env:TEMP\rextract",$z -Recurse -Force
    Get-ChildItem $logsBak -Directory -EA 0 | ForEach-Object {
        $dest = "$d\$($_.Name)\logs"
        if (Test-Path $dest) { Copy-Item "$($_.FullName)\*" $dest -Recurse -Force -EA 0 }
    }
    Remove-Item $logsBak -Recurse -Force -EA 0
    Remove-Item "$d\.gitignore","$d\repositorio.ps1","$d\PENDIENTES.md" -Force -EA 0
    Get-ChildItem $d -Recurse -Filter '.gitkeep' | Remove-Item -Force -EA 0
}

if (-not (Test-Path $d)) {
    Descargar
} else {
    $local = (Get-Item $d).LastWriteTime
    $remoto = [datetime](irm https://repositorio.igeek.ar/version.txt)
    if ($remoto.ToLocalTime() -gt $local) {
        Write-Host "Actualizacion disponible (GitHub: $($remoto.ToLocalTime()))" -ForegroundColor Yellow
        Write-Host "[A] Actualizar   [Enter] Cancelar" -ForegroundColor Cyan
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.Character -eq 'a' -or $key.Character -eq 'A') { Descargar }
    } else {
        Write-Host "Todo actualizado ($local)" -ForegroundColor Green
    }
}

Remove-Item (Get-PSReadLineOption).HistorySavePath -EA 0;Clear-History
Write-Host "Listo. Presione cualquier tecla para abrir la carpeta..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Process explorer.exe $d

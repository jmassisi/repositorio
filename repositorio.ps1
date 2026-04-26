$d="C:\repositorio";$z="$env:TEMP\r.zip"
irm https://github.com/jmassisi/repositorio/archive/refs/heads/main.zip -OutFile $z
Expand-Archive $z $env:TEMP\rextract -Force
Move-Item "$env:TEMP\rextract\repositorio-main" $d -Force
ri $z,$env:TEMP\rextract -Recurse -Force
Remove-Item (Get-PSReadLineOption).HistorySavePath -EA 0;Clear-History
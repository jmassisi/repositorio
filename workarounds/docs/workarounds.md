# WORKAROUND — Alias de winget roto (stub de WindowsApps no generado)

> **Esto es un workaround de esta maquina/alias. NO repara el sistema.**
> Aplica cuando `winget` no resuelve en la terminal (`where.exe winget` no encuentra nada)
> pero el motor real existe (via `Get-AppxPackage Microsoft.DesktopAppInstaller`).

## Síntoma

- `where.exe winget` → no resuelve.
- `Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"` → `False` (no hay stub).
- El toggle de **Settings → Apps → App execution aliases → winget.exe** no genera el stub.
- `winget upgrade` → error de alias en vez de listar paquetes.

## Causa raíz

En Windows, `winget` **no es un binario del sistema**: es un *AppExecutionAlias* (stub) que
Windows genera en `%LOCALAPPDATA%\Microsoft\WindowsApps` cuando el paquete
`Microsoft.DesktopAppInstaller` esta registrado. No es una clave de registro.

Tras una actualizacion del paquete/Windows el re-registro se rompe y el stub deja de generarse.
Re-registrar el paquete puede fallar con:

- `0x80073CF6` (registro de paquete fallido)
- `0x80070005 Acceso denegado` en la extension `windows.appExecutionAlias` (ACLs de
  `C:\Program Files\WindowsApps` dañadas)

Lo importante: **el motor `winget.exe` sigue existiendo** dentro del paquete
(`%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe` es distinto; el real vive en
`Get-AppxPackage ... | % InstallLocation\winget.exe`). Solo falta el alias.

## Solución (workaround)

Un shim `winget.cmd` en `%USERPROFILE%\bin` que llama directo al motor real
(resolviendo el path dinámicamente, aguanta updates del paquete), y esa carpeta
agregada al **PATH de usuario**.

Aplicar con un solo comando (no requiere admin):

```powershell
pwsh -NoProfile -File "C:\repositorio\workarounds\scripts\fix-alias-winget.ps1"
```

Verificación (en terminal **nueva**, el PATH no se refresca en la abierta):

```powershell
winget --version
where.exe winget   # debe apuntar a C:\Users\<tu-usuario>\bin\winget.cmd
```

## Qué toca y qué no

| | |
|---|---|
| Crea | `%USERPROFILE%\bin\winget.cmd` (shim) |
| Modifica | PATH de usuario (variable de entorno, no registro) |
| NO toca | `C:\Program Files\WindowsApps`, paquete Appx, registro, servicios |
| Permisos | ninguno (no requiere admin) |

## Deshacer

Quitar `%USERPROFILE%\bin` del PATH de usuario
(`[Environment]::GetEnvironmentVariable('Path','User')`) y borrar el archivo
`winget.cmd` (o toda la carpeta si no tenés otra cosa ahi):

```powershell
Remove-Item "$env:USERPROFILE\bin\winget.cmd"
```

## Fix real (alternativa, mas invasiva)

Si se quiere reparar de raiz el registro del paquete (resultado incierto, requiere
admin y posible reinicio):

```powershell
DISM /Online /Cleanup-Image /RestoreHealth
```

y luego re-registrar:

```powershell
Get-AppxPackage Microsoft.DesktopAppInstaller | % {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
}
```

Aplica el workaround primero (rapido, reversible) y deja el fix real como opcional.

## Versiones/contexto validado

- El shim y `fix-alias-winget.ps1` se aplican con **pwsh** (PowerShell 7), que es la shell personal del usuario. Con 5.1 el parseo de JSON rompe en silencio; por eso ese script usa `-Raw` + normalización a array (ver `instalar-aplicaciones.ps1`).
- Motor winget v1.29.290 validado funcionando con este workaround.
- **Decisión 2026-09-09:** los lanzadores `.cmd` del repo se mantienen en Windows PowerShell 5.1 (no se migra a pwsh).
# Instalar aplicaciones con Winget

Instala aplicaciones en el equipo usando [Winget](https://learn.microsoft.com/windows/package-manager/) de forma silenciosa y no interactiva, seleccionando una o varias desde una lista.

## Cómo usar

Desde el menú del repositorio (`C:\repositorio\menu.cmd`), elegir la opción `winget`:

1. Se lista las aplicaciones disponibles (se leen de `apps.json`).
2. Ingresar los números de las apps a instalar separados por coma (ej. `1,3,5`).
   Un solo número instala solo esa app (ej. `4`).
   `t` instala todas. `Enter` vacío cancela.
3. Se instalan en orden, una por una, con log por app.

También se puede ejecutar directo el lanzador elevado:

```powershell
C:\repositorio\winget\scripts\instalar-aplicaciones.cmd
```

## Lista de aplicaciones (`apps.json`)

La lista vive en `apps.json` en el repo. Cada entrada:

```json
{ "nombre": "7-Zip", "id": "7zip.7zip", "args": "" }
```

- `nombre` — etiqueta legible que se muestra en el menú
- `id` — identificador de Winget (`winget search <id>` para encontrarlo)
- `args` — argumentos extra para esa app (opcional, ej. `--scope machine`)

El comando que se ejecuta por app:

```powershell
winget install -e --id <id> --silent --accept-package-agreements --accept-source-agreements <args>
```

### Mis apps (2026-09-08)

Al agregar una app a la lista del repositorio, mantener orden alfabetico por nombre de etiqueta.

## Requisitos

- Administrador (el lanzador eleva)
- Winget disponible: Windows 11 o Windows 10 reciente (ya viene integrado); si no, instalarlo desde la Microsoft Store

## Resolucion de winget (fallback)

El script localiza `winget` en este orden:

1. `Get-Command winget` (alias en el PATH / WindowsApps)
2. Motor Appx directo: `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe` via `Get-AppxPackage Microsoft.DesktopAppInstaller`

Si el alias de WindowsApps esta desactivado o roto (Settings → Apps → App execution aliases), el paso 2 lo encuentra igual. El path resuelto se muestra al inicio y queda en el log.
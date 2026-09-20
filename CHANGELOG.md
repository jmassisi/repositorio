# Changelog

Todos los cambios notables del toolkit. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
(estandar: [github.com/olivierlacan/keep-a-changelog](https://github.com/olivierlacan/keep-a-changelog)).

> Este proyecto **no usa versiones semver**: la referencia para los clientes es la
> última fecha de deploy (`C:\repositorio`). Cada entrada se agrupa por **fecha** de
> arriba hacia abajo. Se actualiza al cerrar sesión / mergear a `main`.

## [2026-09-20]

### Agregado

- `workarounds/mas-activation`: item de menú que solo ejecuta el oneliner oficial de
  MAS (MassGrave): `irm https://get.activated.win | iex` (abre su menú interactivo). Sin
  lógica extra ni logs. Rótulo en menu: `mas-activation (Activador MAS)`. Referencias en
  doc: repo github.com/massgravel/Microsoft-Activation-Scripts y web massgrave.dev.
- `workarounds/keyboard-leds`: instalador **Keyboard LEDs 2.7.1.59** (KARPOLAN, último
  release) versionado en `workarounds/bin/keyboard-leds-2.7.1.59.exe` + script
  `keyboard-leds-install.ps1/.cmd` que instala silenciosamente (`/S`, NSIS) con
  idempotencia (detecta instalación previa), verificación final y log. El canal oficial
  de descarga está muerto (404), por eso el binario viaja en el repo con su SHA-256
  documentado. Rótulo en menu: `keyboard-leds-install (Instalar Keyboard LEDs)`.
  Referencias en doc: karpolan.com, Wayback, Software Informer (AV limpio) y mirrors.

## [2026-09-19]

### Agregado

- `workarounds/copy-path-file-context-menu-w10`: agrega "Copiar ruta del archivo" al
  menú contextual de archivos/carpetas del Explorador (Windows 10), via key
  `HKCR\AllFilesystemObjects\shell\windows.copyaspath` (mismo efecto que el
  `copy_path_file_context_menu_W10.reg` original). Verificación de OS (build < 22000,
  solo W10 en es), idempotencia, log y `.reg` de undo. Rótulo en menu:
  `copy-path-file-context-menu-w10 (Windows 10 only)`.

### Cambiado

- `workarounds/hide-3d-objects` renombrado a `hide-3d-objects-w10` (filenames
  `hide-3d-objects-w10.ps1`/`hide-3d-objects-w10.cmd`, log y `.reg` de restauración
  con el sufijo `-w10`) para reflejar en el nombre que es solo Windows 10. Rótulo en
  menu: `hide-3d-objects-w10 (Windows 10 only)`.

## [2026-09-16]

### Agregado

- `workarounds/hide-3d-objects`: oculta la biblioteca "3D Objects" del Explorador
  (Windows 10) y elimina la carpeta fisica vacia por perfil. Aborta todo si alguna
  carpeta tiene contenido (evita borrar datos). Rótulo en menu: `hide-3d-objects (Windows 10 only)`.
- Tag `# menu:` opcional en la cabecera de los `.ps1` de colecciones: permite rótulo
  custom en el submenu (`menu.ps1`); sin tag cae al nombre de archivo actual.
- **Se adopta `CHANGELOG.md`** (este archivo, formato Keep a Changelog — ver enlace
  arriba) como historial del repo. A partir de acá cada sesión/merge agrega su entrada
  por fecha; la entrada de hoy es tambien el registro de su propia adopcion.

### Corregido

- `hide-3d-objects`: ignora `desktop.ini` en la deteccion de contenido (la carpeta con
  solo `desktop.ini` se considera vacia).

### Cambiado

- `repositorio.ps1`: al actualizar preserva el **runtime** de cada elemento (todas las
  subcarpetas que no sean `scripts/` ni `docs/`). Los `logs/` siempre se mezclan; el
  resto se restaura solo si el deploy no lo trajo (merge de `feat/actualizar-preserva-runtime`).

## [2026-09-12]

### Agregado

- `glpi`: cambiar el servidor GLPI sin reinstalar el agente + comparador de versiones.

## [2026-09-09]

### Agregado

- `winget`: instalador de aplicaciones con seleccion multiple (`apps.json`), con
  `t` = todas y Enter = cancelar. Fallback al motor Appx cuando el alias esta roto.
- `workarounds/`: carpeta propia para workarounds (fix de alias winget), visible en el menu.
- `AGENTS.md` del repo con convenciones (shell objetivo Windows PowerShell 5.1, idempotencia
  y resultado visible en scripts, main sagrado).

### Cambiado

- `sysinternals` y `workarounds` siempre muestran submenu (colecciones), base para futuros scripts.
- `autologon` idempotente: verifica si ya esta descargado, registra donde quedo y ofrece
  abrirlo sin re-descargar.
- Convencion de nombres por herramienta: docs y scripts renombrados
  (`fix-alias-winget` -> `fix-winget-alias`, `instalar-winget` -> `instalar-aplicaciones`, etc.).
- `apps.json` reordenado alfabeticamente por vendor (VCRedist antes que VS Code en bloque Microsoft).
- Decision 2026-09-09: los lanzadores `.cmd` se mantienen en **Windows PowerShell 5.1** (no migrar a pwsh);
  el workaround de alias winget se aplica con pwsh (shell personal del operador).

### Corregido

- `winget`: lectura de `apps.json` con `-Raw` y normalizacion del array para compatibilidad PS 5.1.

## [2026-09-08]

### Agregado

- `defprof`: auto-descarga y verificacion por **hash + firma** de `defprof.exe`
  (servido desde `defprof/bin/`, se elimina la descarga a Forensit bloqueada por Cloudflare).
- `defprof`: `fix-winx` para reparar el menu Win+X post-defprof, con seleccion numerada del usuario origen.
- `menu.ps1`: fecha del ultimo commit via GitHub API (elimina `version.txt`);
  `[A]` actualiza en un solo pulso con flag `-Actualizar` (evita fallo de PSReadLine con `-NoProfile`).
- Documentacion versionada como `.md` en `docs/` de cada utilidad.

### Cambiado

- `repositorio.ps1`: auto-elevacion al inicio; backup de la carpeta existente con timestamp
  `yyyy-MM-dd_HHmmss` (evita colision de Rename-Item); fallback `robocopy /MIR` cuando
  `C:\repositorio` esta en uso; final unificado para `[A]` y `irm | iex`;
  ya **no elimina** `repositorio.ps1` tras el deploy (era la causa de que `[A]` no actualizara).
- `defprof`: ejecuta `defprof.exe` directo desde `defprof/bin/` (elimina la copia a `C:\IT`).

### Removido

- PDF/HTML de documentacion del repo (convencion 2026-09-08: solo `.md`; `.pdf/.docx/.html`
  deprecados, viven en Drive).
- `version.txt` de prueba (flujo `[A]` validado via GitHub API).

### Corregido

- `defprof`: fecha DD/MM/AAAA en el menu; uso de `curl.exe` en vez de `Invoke-WebRequest`
  para pasar el challenge de Cloudflare; `${defprof}` en strings (ParserError).
- `menu.ps1`: Enter vacio ya no selecciona opcion.

## [2026-07-15]

- Pruebas del flag de actualizacion `version.txt` + check via Cloudflare Pages
  (transitorio: el mecanismo definitivo llega el 2026-09-08 con GitHub API).

## [2026-06-13]

### Cambiado

- `glpi`: script renombrado a `glpi-agent-install`, instalacion via **winget**;
  `.cmd` lanzador unificado con anydesk.

## [2026-06-12]

### Cambiado

- `anydesk` v5: instalacion via winget, restauracion de roster, filtro de UnInst,
  fix en deteccion por ProductName.

## [2026-06-10]

### Agregado

- `menu.ps1` interactivo (reemplaza a `check.ps1`/`check.cmd`).
- `sysinternals/autologon`: descarga Autologon y Autologon64 desde `live.sysinternals.com`.
- `office` v1.2: deteccion de instalacion, uninstall via GetHelpCmd, ventana unica de PS.

## [2026-06-08]

### Agregado

- Verificacion de version antes de descargar; carpeta existente se renombra a
  `repositorio_bkp_yyyy-MM-dd` antes de actualizar.

## [2026-06-07]

### Cambiado

- `office` v1.1: los 6 perfiles disponibles, fix de version de ODT.

## [2026-05-17]

### Agregado

- `defprof`: scripts de actualizacion del perfil por defecto y documentacion.

### Cambiado

- Ejecucion de la actualizacion fuera de `C:\repositorio` (evita bloqueos por CWD).
- README con seccion de gestion (`check.ps1`).

## [2026-05-09]

### Agregado

- `office`: scripts de instalacion desatendida y normalizacion de nombres en minusculas.

## [2026-05-01]

### Cambiado

- Nombres de archivos a minusculas (convencion); `.gitkeep` versionado en `logs/`.
- Limpieza en deploy: se eliminan archivos internos del cliente (`PENDIENTES.md`).

### Removido

- `.pdf/.html` de documentacion de GLPI del repo (viven en Drive).

## [2026-04-30]

### Cambiado

- `glpi` migrado a `ps1` + `.cmd` lanzador, logs en `glpi/logs`, accesos directos al agente.

## [2026-04-28]

### Agregado

- `anydesk`: script `.cmd` wrapper y `Reset-AnyDesk` v3/v4: deteccion por ProductName,
  fallback UserAssist/Prefetch, relaunch por servicio si esta instalado, logs en `anydesk/logs/`.

## [2026-04-27]

### Agregado

- `glpi`: agente 1.17, batch de instalacion, docs y guia tecnica.

### Cambiado

- Actualizacion: crea/sobreescribe correctamente `C:\repositorio` (fix de despliegue).

### Corregido

- `glpi`: `ssl-no-revoke` en curl para entornos con revocacion bloqueada; captura de
  errorlevel antes de eliminar el MSI; reemplazo de if/else por goto (doble ejecucion).

## [2026-04-26]

### Agregado

- Commit inicial: estructura base de carpetas, README, `.gitignore` y despliegue
  `irm repositorio.igeek.ar | iex` en `C:\repositorio`.
- `check.ps1` de actualizaciones con opcion `[A]` para actualizar directo.
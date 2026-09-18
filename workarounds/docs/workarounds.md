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
pwsh -NoProfile -File "C:\repositorio\workarounds\scripts\fix-winget-alias.ps1"
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

- El shim y `fix-winget-alias.ps1` se aplican con **pwsh** (PowerShell 7), que es la shell personal del usuario. Con 5.1 el parseo de JSON rompe en silencio; por eso ese script usa `-Raw` + normalización a array (ver `winget.ps1`).
- Motor winget v1.29.290 validado funcionando con este workaround.
- **Decisión 2026-09-09:** los lanzadores `.cmd` del repo se mantienen en Windows PowerShell 5.1 (no se migra a pwsh).

---

# WORKAROUND — Ocultar "3D Objects" del Explorador (Windows 10)

Combina dos acciones en un solo script:

1. **Hide (registro):** borra la key del CLSID `{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}`
   del namespace de "Este equipo" en `HKLM` y `WOW6432Node`. Es el mismo efecto que
   el `Hide_3D_Objects.reg` original (referencia en `origen/`, solo local — NO llega al cliente).
2. **Limpieza:** elimina la carpeta fisica `%USERPROFILE%\3D Objects` de cada perfil,
   **solo si esta vacia**.

> **Solo Windows 10.** En Windows 11 el icono ya no existe: el script detecta el OS
> (exige `ProductName -like 'Windows 10*'` y build `< 22000`) y aborta si no aplica.
> Perfiles en ingles (sistema US): la carpeta se busca literalmente `3D Objects`.

## Uso

Desde el menu (`menu.ps1` → `workarounds` → `hide-3d-objects (Windows 10 only)`) o directo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\workarounds\scripts\hide-3d-objects.ps1"
```

Requiere **Administrador** (borra claves en `HKLM`). El lanzador `hide-3d-objects.cmd`
eleva automaticamente si se ejecuta sin permisos.

## Comportamiento de seguridad

- Si alguna carpeta `3D Objects` tiene **contenido** (archivos del usuario), el script
  **ABORTA todo**: no borra la carpeta ni oculta el icono, y lista qué encontró.
  Evita perder datos (ej. modelos `.stl`/`.3mf`) de un perfil que no es nuevo.
  El `desktop.ini` de la carpeta (que crea Windows para localizar el nombre) **no
  cuenta como contenido**: la carpeta con solo `desktop.ini` se considera vacia.
- Idempotencia: si ya esta aplicado (sin keys y sin carpetas), pide "Re-hacer? (S/N)".
- El icono desaparece al refrescar/reabrir el Explorador; si persiste, reiniciar
  Explorer o cerrar sesion (no se toca en el script).

## Qué toca y qué no

| | |
|---|---|
| Borra (registro) | `HKLM\...\MyComputer\NameSpace\{0DB7E03F-...}` y su `WOW6432Node` |
| Borra (disco) | `C:\Users\*\3D Objects` **vacia** de cada perfil |
| Genera (por corrida) | log `logs/hide-3d-objects_<ts>.log` + `.reg` de restauracion `logs/hide-3d-objects-restore_<ts>.reg` |
| NO toca | datos del usuario con contenido, perfiles `Default`/`Public`/`All Users`, Windows 11 | 

## Deshacer

Importar el `.reg` de restauracion generado en `C:\repositorio\workarounds\logs\`
(re-crea las dos keys de registro; el icono vuelve a aparecer).

```powershell
reg import "C:\repositorio\workarounds\logs\hide-3d-objects-restore_<ts>.reg"
```

## Referencia de origen

El `Hide_3D_Objects.reg` original (de `D:\Backups\2026-01-10 - geekom...`) se mantiene
en `origen/` (ignorado por git y **no se despliega al cliente**). El script implementa
su mismo efecto via PowerShell (permite el abort por contenido, logs y verificaciones que
un `.reg` puro no puede).
---

# WORKAROUND — Corrección de memoria RAM en inventario GLPI vía SPD real (NWinfo)

> **Para BIOS viejas que reportan memoria mal por SMBIOS** (ej. placa de la PC de
> banco que dice DDR2 cuando el módulo real es DDR3 SO-DIMM).

## Problema

El GLPI Agent genera el <MEMORIES> de su inventario desde la información SMBIOS
(Win32_PhysicalMemory / tabla 17), que en placas viejas puede estar mal cargada
(datos de fábrica de un módulo que nunca existió, tipo/frecuencia incorrectos).
El SPD real del módulo (EEPROM en el DIMM, leída por SMBus/I2C) puede diferir.

## Solución (workaround)

Script `nwinfo-glpi-evidence.ps1` que:

1. Detecta el agente GLPI instalado y genera un **inventario local** con
   `glpi-agent --local <dir>` (sin `--server`: NO contacta ningún servidor).
   De ahí saca los `<MEMORIES>` actuales (DESIGNATION = pkey del slot).
2. Descarga NWinfo v1.6.6 en `C:\repositorio\workarounds\nwinfo\` (si falta) y corre
   `nwinfo.exe --format=json --human --spd --sys`: lectura **real del SPD**.
3. Alinea slot a slot (usa el mismo `DESIGNATION`/pkey del inventario actual) y arma
   un XML de **contenido adicional** (`nwinfo-additional-content_<ts>.xml`, en logs/)
   con el `<MEMORIES>` corregido (TYPE, SPEED, CAPACITY, SERIALNUMBER, MANUFACTURER).
4. **Dry-run por defecto**: solo deja el XML + reporte comparativo local (qué decía
   el agente vs qué dice el SPD). **NO envía nada.**
5. Envío = paso explícito (por separado, o con `-Send`):
   `glpi-agent.bat --force --additional-content="<ruta>.xml"`

Requiere **Administrador** (descarga a `workarounds\nwinfo\` y driver de acceso SPD
vía SMBus; si NWinfo no lee slots en una VM, no hay corrección posible: aborta avisando).

## Uso

Desde el menú (`menu.ps1` → `workarounds` → `nwinfo-evidence (NWinfo legacy -> GLPI)`) o directo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\workarounds\scripts\nwinfo-glpi-evidence.ps1"
```

- Dry-run (default): muestra la comparación y deja el XML en `logs\`.
- Envío real, una de dos:
  ```powershell
  # opción A: un solo paso, el script corre el agente
  powershell ... -File "C:\repositorio\workarounds\scripts\nwinfo-glpi-evidence.ps1" -Send
  # opción B: copiar el comando que imprime el dry-run y correrlo aparte
  "C:\Program Files\GLPI-Agent\bin\glpi-agent.bat" --force --additional-content="C:\repositorio\workarounds\logs\nwinfo-additional-content_<ts>.xml"
  ```
- Re-descargar NWinfo aunque exista: `-ForceRedownload`
- Override de la carpeta del agente: `-AgentDir <ruta>`

Verificación en GLPI: `Computadores → <host> → pestaña Memorias` (reemplaza la fila
con el mismo slot/designation, no duplica; la pkey del plugin es DESIGNATION).

## Qué toca y qué no

| | |
|---|---|
| Lee | SPD real de los DIMM (SMBus, igual que CPU-Z) |
| Crea | `workarounds\nwinfo\` (NWinfo, ignorado por git), `logs\nwinfo-*.json/html/xml`, log `logs\nwinfo-glpi-evidence_<ts>.log` |
| Envía | **solo** con `-Send` o corriendo el comando de envío a mano; el dry-run nunca contacta el servidor |
| Descarga | NWinfo v1.6.6 de GitHub (una vez) |
| NO toca | GLPI server, data, credenciales, otros campos del inventario |

## Deshacer

El dry-run no modifica nada en GLPI. Si el envío dejó el slot mal, el próximo
inventario normal del agente vuelve a reportar lo que diga el SMBIOS (revertir =
borrar el `--additional-content` y dejar que corra el inventario estándar).

## Referencia de origen

- NWinfo: `https://github.com/a1ive/nwinfo` (v1.6.6, release del 2026-08-03).
- GLPI Agent `--additional-content` (manpage `glpi-agent`): "Additional inventory
  content file. This file should be an XML file, using same syntax as the one
  produced by the agent." — mergeado en el inventario antes de enviar.
- Formato de `<MEMORIES>` y la pkey de alineación (DESIGNATION): documentados en el
  protocolo de inventario de FusionInventory/GLPI-Agent.
- Caso de uso real: RREI08 (banco de la oficina), DDR3 SO-DIMM reportado por la BIOS
  como DDR2. Verificable con el reporte CPU-Z en `C:\repositorio\banco\`.

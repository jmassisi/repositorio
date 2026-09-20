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

Desde el menu (`menu.ps1` → `workarounds` → `hide-3d-objects-w10 (Windows 10 only)`) o directo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\workarounds\scripts\hide-3d-objects-w10.ps1"
```

Requiere **Administrador** (borra claves en `HKLM`). El lanzador `hide-3d-objects-w10.cmd`
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
| Genera (por corrida) | log `logs/hide-3d-objects-w10_<ts>.log` + `.reg` de restauracion `logs/hide-3d-objects-w10-restore_<ts>.reg` |
| NO toca | datos del usuario con contenido, perfiles `Default`/`Public`/`All Users`, Windows 11 | 

## Deshacer

Importar el `.reg` de restauracion generado en `C:\repositorio\workarounds\logs\`
(re-crea las dos keys de registro; el icono vuelve a aparecer).

```powershell
reg import "C:\repositorio\workarounds\logs\hide-3d-objects-w10-restore_<ts>.reg"
```

## Referencia de origen

El `Hide_3D_Objects.reg` original (de `D:\Backups\2026-01-10 - geekom...`) se mantiene
en `origen/` (ignorado por git y **no se despliega al cliente**). El script implementa
su mismo efecto via PowerShell (permite el abort por contenido, logs y verificaciones que
un `.reg` puro no puede).
---

# WORKAROUND — "Copiar ruta del archivo" en el menú contextual (Windows 10)

Agrega la opción **"Copiar ruta del archivo"** al menú contextual del Explorador para
archivos y carpetas, a través de la key
`HKCR\AllFilesystemObjects\shell\windows.copyaspath` (mismo efecto que el
`copy_path_file_context_menu_W10.reg` original, referencia en `H:\Repositorio_OLD\`).

> **Solo Windows 10.** En Windows 11 "Copiar como ruta" ya está integrado en el menú
> contextual: el script detecta el OS (exige `ProductName -like 'Windows 10*'` y build
> `< 22000`) y aborta si no aplica.

## Uso

Desde el menú (`menu.ps1` → `workarounds` → `copy-path-file-context-menu-w10 (Windows 10 only)`) o directo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\workarounds\scripts\copy-path-file-context-menu-w10.ps1"
```

Requiere **Administrador** (escribe en `HKCR`). El lanzador `copy-path-file-context-menu-w10.cmd`
eleva automáticamente si se ejecuta sin permisos.

## Qué toca y qué no

| | |
|---|---|
| Crea (registro) | `HKCR\AllFilesystemObjects\shell\windows.copyaspath` con `(Default)="Copiar ruta del archivo"`, `InvokeCommandOnSelection=1`, `VerbHandler={f3d06e7c-1e45-4a26-847e-f9fcdee59be0}`, `Icon=shell32.dll,134` |
| Genera (por corrida) | log `logs/copy-path-file-context-menu-w10_<ts>.log` + `.reg` de restauración `logs/copy-path-file-context-menu-w10-undo_<ts>.reg` |
| NO toca | Windows 11, `HKCR\*\...` (otros verbos), otros valores del contexto |

## Deshacer

Importar el `.reg` de undo generado en `C:\repositorio\workarounds\logs\` (borra la key).

```powershell
reg import "C:\repositorio\workarounds\logs\copy-path-file-context-menu-w10-undo_<ts>.reg"
```

## Referencia de origen

El `copy_path_file_context_menu_W10.reg` original vive en `H:\Repositorio_OLD\` (fuera del
repo, no se despliega). El script implementa su mismo efecto vía PowerShell (verificación
de OS, idempotencia, undo y logs que un `.reg` puro no puede).
---

# UTILIDAD — Activación Windows con MAS (get.activated.win)

Lanzador del activador **MAS** (Microsoft Activation Scripts) de MassGrave desde el menú.
Solo ejecuta el oneliner oficial (sin verificación previa ni lógica extra):

```powershell
irm https://get.activated.win | iex
```

> **Script de terceros.** MAS es un proyecto open source de MassGrave (activación por
> HWID / Ohook / KMS38 / Online KMS). El oneliner descarga y ejecuta el script en
> memoria y abre su menú interactivo en esta consola.

## Uso

Desde el menú (`menu.ps1` → `workarounds` → `mas-activation (Activador MAS)`) o directo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\workarounds\scripts\mas-activation.ps1"
```

Requiere **Administrador** (el `menu.cmd` ya eleva). El lanzador
`mas-activation.cmd` eleva automáticamente si se ejecuta sin permisos.

## Qué toca y qué no

| | |
|---|---|
| Ejecuta | `irm https://get.activated.win | iex` (menú interactivo de MAS) |
| No deja | binarios, servicios ni instalaciones propias en el equipo |
| Requiere | Administrador y conexión a internet |

> El propio MAS puede dejar su activación (HWID/Ohook/KMS) y, en algunos modos,
> registrar servicios/planificación propios según la opción elegida en su menú.

## Verificación

```powershell
slmgr /xpr
slmgr /dli
```

## Referencias

- Repo: `https://github.com/massgravel/Microsoft-Activation-Scripts`
- Web oficial: `https://massgrave.dev` (mirror del oneliner: `https://get.activated.win`)

---

# UTILIDAD — Keyboard LEDs 2.7.1.59 (installer local en el repo)

Instalador de **Keyboard LEDs** (KARPOLAN/Anton Karpenko) — muestra el estado de
Caps/Num/Scroll Lock en pantalla/bandeja. Ideal para notebooks y teclados inalámbricos
sin LEDs. **2.7.1.59 es el último release** (2014) y el canal oficial está muerto
(`keyboard-leds.com/download/` y `/files/keyboard-leds.exe` devuelven 404), así que el
instalador original (NSIS, firmado) **viaja versionado en `workarounds/bin/`** para no
depender de mirrors que puedan desaparecer.

## Uso

Desde el menú (`menu.ps1` → `workarounds` → `keyboard-leds-install (Instalar Keyboard LEDs)`) o directo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\workarounds\scripts\keyboard-leds-install.ps1"
```

Requiere **Administrador** (el `menu.cmd` ya eleva). El lanzador
`keyboard-leds-install.cmd` eleva automáticamente si se ejecuta sin permisos.

Flujo del script:

1. Verifica que exista el instalador local `workarounds/bin/keyboard-leds-2.7.1.59.exe`.
2. Detecta instalación previa (exe por defecto o entrada de *Panel de control → Programas*);
   si ya está, pregunta `Re-instalar de todos modos? (S/N)`.
3. Cierra el proceso `KeyboardLeds` si está en ejecución.
4. Instala silenciosamente: `keyboard-leds-2.7.1.59.exe /S` (instalador **NSIS**).
5. Verifica el exe instalado y deja registro en
   `logs/keyboard-leds-install_<ts>.log` junto al SHA-256 del instalador.

## Qué toca y qué no

| | |
|---|---|
| Instala | Keyboard LEDs 2.7.1.59 (ruta por defecto del instalador NSIS) |
| Crea (en el repo) | `workarounds/bin/keyboard-leds-2.7.1.59.exe` (522.508 bytes) |
| Genera (por corrida) | log `logs/keyboard-leds-install_<ts>.log` |
| NO toca | registro salvo lo que hace el propio instalador, config de usuario |

## Deshacer

Desinstalar desde *Panel de control → Programas → Keyboard LEDs* o, si se quiere
reproducir la versión, volver a correr el instalador del repo.

## Integridad

SHA-256 del instalador versionado:

```
4b2e12eea8116f0670919dc0b782019776dbec09614e821132636679421c50f5
```

Coincide con el instalador original firmado por KARPOLAN (copia recuperada del Wayback
Machine) y con el que reporta el mirror LO4D (522.508 bytes).

## Referencias

- Autor (página viva, descarga muerta): `https://software.karpolan.com/keyboard-leds/`
- Official (404): `https://keyboard-leds.com` / `https://keyboard-leds.com/download/`
- Wayback del original: `https://web.archive.org/web/*/keyboard-leds.com/files/keyboard-leds.exe`
- Software Informer (v2.7.1.59, `keyboard-leds.zip`, escaneado por 76 AV — limpio, 2025-01-09):
  `https://keyboard-leds.software.informer.com/download/`
- Mirrors adicionales: LO4D `https://keyboard-leds.en.lo4d.com/windows`, CNET
  `https://download.cnet.com/keyboard-leds/3000-2094_4-75219806.html`, Softpedia
  `https://www.softpedia.com/get/System/System-Miscellaneous/Keyboard-Leds.shtml`,
  SoftDeluxe `https://softdeluxe.com/Keyboard-Leds-1674842/`

---

# WORKAROUND — Corrección de memoria RAM en inventario GLPI vía SPD real (NWinfo) — **DEPRECADO**

> **DEPRECADO 2026-09-18.** Este workaround se descarta: el reemplazo del `<MEMORIES>`
> por `--additional-content` no actualiza los items existentes en GLPI (FusionInventory
> alinea por DESIGNATION/seed del device; con DESIGNATION vacía crea/mergea mal — en
> RREI08 quedó "2 DDR2 + 1 DDR3" en vez de reemplazar las 2 DDR2). Se mantiene el
> código preservado en `workarounds/scripts/deprecated/nwinfo-glpi-evidence.*` (fuera
> del menú) solo como referencia. La vía real de corrección de memoria en GLPI queda a
> definir (opciones pendientes: edición manual de la ficha, SQL sobre la DB, o bien
> aceptar el dato SMBIOS erróneo y corregir el SMBIOS de la BIOS).

---

## Hallazgo documentado — Escaneo erróneo DDR2 en lugar de DDR3 (2026-09-18)

Durante la investigación de este workaround se **detectó y confirmó** el siguiente
escaneo erróneo en el inventario GLPI de RREI08 (PC del banco de la oficina):

- **GLPI reporta**: 2 memorias DDR2 4 GB (800 MHz), SO-DIMM, seriales `1234-B0` /
  `1234-B1`, según datos `Win32_PhysicalMemory`/tabla SMBIOS 17.
- **SPD real (leído por CPU-Z y por NWinfo vía driver NwHwIo|SMBus i801, ICH9-M)**:
  **2 módulos DDR3 SO-DIMM 4 GB (1066 MHz)**, timings 7-7-7-20, CPU Core2 Duo
  T6600 @ 2.20GHz, chipset GL40/ICH9-M.
- **Conclusión**: la BIOS de esa placa carga en SMBIOS el tipo/frecuencia de un módulo
  que no corresponde (DDR2 800) mientras el módulo físico real es DDR3 SO-DIMM 1066.
  Los 8 GB son reales y coinciden (2×4 GB); lo erróneo es **tipo y frecuencia**
  (DDR2 vs DDR3, 800 vs 1066), no la capacidad.

**Implicación**: el inventario GLPI de RREI08 queda con tipo de memoria incorrecto
(DDR2) hasta que se corrija por otra vía (no re-escanear sin corrección: el re-scan
vuelve a traer DDR2 porque nace del SMBIOS). La evidencia del SPD real quedó en
`~/reports/raw/cpuz/RREI08.txt` (reporte CPU-Z) y en los logs NWinfo de RREI08.

---

## (Referencia — versión original del workaround, DEPRECADA)

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
2. Descarga NWinfo v1.6.6 en `C:\repositorio\workarounds\nwinfo\` (si falta) — pack
   **FULL + LITE** — y corre `nwinfo.exe --format=json --human --spd --sys`: lectura
   **real del SPD**.
3. Alinea slot a slot (usa el mismo `DESIGNATION`/pkey del inventario actual) y arma
   un XML de **contenido adicional** (`nwinfo-additional-content_<ts>.xml`, en logs/)
   con el `<MEMORIES>` corregido (TYPE, SPEED, CAPACITY, SERIALNUMBER, MANUFACTURER).
4. **Dry-run por defecto**: muestra la comparación local (qué decía el agente vs qué
   dice el SPD) y deja el XML + reporte en `logs/`. **NO envía nada todavía.**
5. **Confirmación interactiva al final**: pregunta `Enviar a GLPI ahora [S/N]?`
   (Enter = S). Solo con `S` corre el agente contra el servidor y mergea el
   `<MEMORIES>` corregido. Con `N` queda todo local (paso explícito pendiente
   según el comando que se imprime). `-Send` salta la pregunta y envía directo.

Requiere **Administrador**. No instala servicios en el sistema: el driver de acceso
al SPD (**NwHwIo**, del pack LITE de NWinfo) se registra y arranca a demanda por el
propio `nwinfo.exe` — NWinfo lo elige automáticamente (segundo en su orden de
drivers, antes que PawnIO) y es quien lee el SPD por scan PCI directo en chipsets
Intel legacy (ICH6-10) donde PawnIO falla. Si `NwHwIox64.sys` no está a la vista
junto al exe, NWinfo cae en PawnIO o en el driver de CPU-Z (si CPU-Z está abierta).
Se omite la bajada del LITE con `-SkipDriver`. Si NWinfo no lee slots en una VM, no
hay corrección posible: aborta avisando si falta el driver.

## Uso

Desde el menú (`menu.ps1` → `workarounds` → `nwinfo-evidence (NWinfo legacy -> GLPI)`) o directo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\repositorio\workarounds\scripts\nwinfo-glpi-evidence.ps1"
```

- Dry-run (default): muestra la comparación y al final pregunta si enviar (`[S]/[N]`, Enter = S).
- Envío sin pasar por la pregunta:
  ```powershell
  powershell ... -File "C:\repositorio\workarounds\scripts\nwinfo-glpi-evidence.ps1" -Send
  ```
- Re-descargar NWinfo aunque exista: `-ForceRedownload`
- Override de la carpeta del agente: `-AgentDir <ruta>`
- No tocar el driver de SPD (no baja el LITE; usa solo PawnIO/CPU-Z si ya están): `-SkipDriver`

Verificación en GLPI: `Computadores → <host> → pestaña Memorias` (reemplaza la fila
con el mismo slot/designation, no duplica; la pkey del plugin es DESIGNATION).

## Qué toca y qué no

| | |
|---|---|
| Lee | SPD real de los DIMM (SMBus, igual que CPU-Z) |
| Instala | nada en el sistema: el driver NwHwIo (del pack LITE) se registra/arranca a demanda por `nwinfo.exe`; limpiar con `sc.exe delete NwHwIo` si quedó el servicio |
| Crea | `workarounds\nwinfo\` (NWinfo, ignorado por git), `logs\nwinfo-*.json/html/xml`, log `logs\nwinfo-glpi-evidence_<ts>.log` |
| Envía | **solo** respondiendo `S` a la confirmación final, con `-Send`, o corriendo el comando de envío a mano; con `N` el dry-run no contacta el servidor |
| Descarga | NWinfo v1.6.6 (FULL + LITE) de GitHub (una vez) |
| NO toca | GLPI server, data, credenciales, otros campos del inventario |

## Deshacer

Con `N` en la confirmación no se modifica nada en GLPI. Si el envío dejó el slot mal,
el próximo inventario normal del agente vuelve a reportar lo que diga el SMBIOS
(revertir = borrar el `--additional-content` y dejar que corra el inventario estándar).

## Referencia de origen

- NWinfo: `https://github.com/a1ive/nwinfo` (v1.6.6, release del 2026-08-03).
- GLPI Agent `--additional-content` (manpage `glpi-agent`): "Additional inventory
  content file. This file should be an XML file, using same syntax as the one
  produced by the agent." — mergeado en el inventario antes de enviar.
- Formato de `<MEMORIES>` y la pkey de alineación (DESIGNATION): documentados en el
  protocolo de inventario de FusionInventory/GLPI-Agent.
- Caso de uso real: RREI08 (banco de la oficina), DDR3 SO-DIMM reportado por la BIOS
  como DDR2. Verificable con el reporte CPU-Z en `C:\repositorio\banco\`.

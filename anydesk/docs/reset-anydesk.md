# Reset AnyDesk en Windows

**Versión del documento:** 1.0
**Scripts incluidos:** Reset-AnyDesk.ps1 / Reset-AnyDesk.cmd

---

## Descripción

Solución para resetear el ID y la configuración de AnyDesk en equipos Windows. Funciona tanto para instalaciones convencionales como para ejecuciones standalone (sin instalación), es agnóstico del idioma del sistema operativo y de la ruta del ejecutable.

---

## Requisitos previos

- Windows 10/11 o Windows Server 2016+ (64 bits)
- Privilegios de administrador local
- PowerShell 5.1 o superior (incluido en Windows 10+)
- AnyDesk corriendo o instalado en el equipo

---

## Archivos

| Archivo | Descripción |
|---|---|
| `Reset-AnyDesk.ps1` | Script principal. Detección, kill, reset, backup y log |
| `Reset-AnyDesk.cmd` | Lanzador. Eleva privilegios y ejecuta el `.ps1` |

> [!IMPORTANT]
> Ambos archivos deben estar en el mismo directorio. El usuario debe ejecutar únicamente el `.cmd`.

---

## Uso

1. Copiar `Reset-AnyDesk.ps1` y `Reset-AnyDesk.cmd` al equipo destino.
2. Hacer doble clic sobre `Reset-AnyDesk.cmd`.
3. Aceptar la elevación de privilegios (UAC).
4. El script se ejecuta automáticamente y relanza AnyDesk al finalizar.

> [!NOTE]
> Si AnyDesk no está corriendo al momento de ejecutar el script, se busca la instalación en `%ProgramFiles%` y `%ProgramFiles(x86)%`. Si tampoco se encuentra ahí, colocar el `.cmd` y el `.ps1` en el mismo directorio que `AnyDesk.exe` y ejecutar desde allí.

---

## Comportamiento del script

### Detección automática

El script busca la ruta del ejecutable en el siguiente orden, deteniéndose en el primer éxito:

1. **Proceso activo** — extrae la ruta directamente desde el proceso en memoria.
2. **ProgramFiles** — busca instalación convencional en `%ProgramFiles%` y `%ProgramFiles(x86)%`.
3. **UserAssist** (registro) — lee `HKCU\...\Explorer\UserAssist`, decodifica ROT13 y busca `AnyDesk.exe`. Efectivo para standalone que se ejecutó al menos una vez.
4. **Prefetch** — busca `C:\Windows\Prefetch\ANYDESK*.pf` y extrae la ruta del exe desde el contenido del archivo.

Si la ruta es encontrada pero el exe ya no existe físicamente, el script **aborta sin resetear** para evitar dejar el sistema sin posibilidad de relaunch. Todo queda registrado en el log.

Determina si AnyDesk está instalado o corre en modo standalone comparando la ruta contra las variables `%ProgramFiles%` del sistema.

### Kill de procesos

Termina todos los procesos `AnyDesk.exe` con `Stop-Process -Force` y espera hasta 5 segundos a que el proceso desaparezca antes de continuar.

### Reset de configuración

Busca archivos `.conf` en todas las ubicaciones posibles:

| Ubicación | Aplica a |
|---|---|
| `%ProgramData%\AnyDesk\` | Instalación estándar |
| `%AppData%\AnyDesk\` | Perfil de usuario |
| `%LocalAppData%\AnyDesk\` | Perfil local |
| Directorio del `.exe` | Standalone |

Archivos reseteados: `system.conf`, `service.conf`, `user.conf`, `ad.trace` (archivo de traza, no de configuración)

### Backup con timestamp

Cada archivo reseteado se renombra con el timestamp de la ejecución en lugar de eliminarse. Ejemplo:

```
system.conf.2026-04-27_143022.backup
service.conf.2026-04-27_143022.backup
```

Esto preserva el historial completo: cada reset genera sus propios backups sin pisar los anteriores.

### Relaunch

Una vez completado el reset, AnyDesk se relanza automáticamente desde la misma ruta donde fue detectado.

---

## Log

Cada ejecución genera un archivo de log independiente en:

```
%ProgramData%\AnyDesk\reset-logs\reset_YYYY-MM-DD_HHmmss.log
```

### Información registrada

| Campo | Descripción |
|---|---|
| Fecha y hora | Timestamp de la ejecución |
| Hostname | Nombre del equipo |
| Usuario | Dominio y usuario que ejecutó el script |
| PID | ID del proceso antes del kill |
| AnyDesk ID | ID de la instancia antes del reset (extraído de `system.conf`) |
| Versión | Versión del ejecutable `AnyDesk.exe` |
| Tipo | `INSTALADO` o `STANDALONE` |
| Ruta del exe | Path completo del ejecutable detectado |
| Archivos reseteados | Lista con ruta completa de cada `.conf` renombrado |
| Relaunch | Confirmación de éxito o error al relanzar |

### Ejemplo de log

```
================================================
 Reset-AnyDesk  |  2026-04-27_143022
 Host   : PC-RECEPCION
 Usuario: DOMINIO\juan
================================================

--- Buscando proceso AnyDesk... ---
[2026-04-27_143022][INFO] Proceso activo - PID: 4821
[2026-04-27_143022][INFO] Ruta exe: C:\Users\juan\Downloads\AnyDesk.exe
[2026-04-27_143022][INFO] AnyDesk ID (antes del reset): 123 456 789
[2026-04-27_143022][INFO] Version: 8.0.8
[2026-04-27_143022][INFO] Tipo: STANDALONE

--- Terminando procesos AnyDesk... ---
[2026-04-27_143022][INFO] Terminado PID 4821
[2026-04-27_143022][INFO] Procesos terminados (espera: 1s)

--- Reseteando configuracion... ---
[2026-04-27_143022][INFO] Backup: C:\ProgramData\AnyDesk\system.conf.2026-04-27_143022.backup
[2026-04-27_143022][INFO] 1 archivo(s) reseteado(s)

--- Relanzando AnyDesk... ---
[2026-04-27_143022][INFO] Relaunch OK: C:\Users\juan\Downloads\AnyDesk.exe
================================================
```

> [!TIP]
> Si el AnyDesk ID no aparece en el log, significa que `system.conf` no existía o no contenía el campo `ad.anynet.id` al momento de la ejecución. Esto puede ocurrir en instalaciones muy nuevas o en algunas versiones standalone.

---

## Troubleshooting

**AnyDesk no se relanza después del reset**
Verificar que el ejecutable sigue en la ruta registrada en el log. En modo standalone, si el usuario movió el archivo entre ejecuciones, el relaunch fallará.

**"No se encontro AnyDesk instalado ni corriendo"**
El script agotó los cuatro métodos de detección (proceso activo, ProgramFiles, UserAssist, Prefetch). Colocar los scripts en el mismo directorio que `AnyDesk.exe` no aplica en este caso — significa que AnyDesk nunca se ejecutó en este equipo o fue instalado/ejecutado con un perfil de usuario diferente. Verificar en otro perfil de usuario.

**El AnyDesk ID no cambió después del reset**
Verificar en el log que al menos `system.conf` fue reseteado. Si AnyDesk regenera el mismo ID, puede deberse a que existe otro `system.conf` en una ubicación no contemplada — revisar el log para identificar cuáles archivos fueron encontrados.

**Error de ExecutionPolicy en PowerShell**
El lanzador `.cmd` aplica `-ExecutionPolicy Bypass` solo para esa ejecución. Si el error persiste, verificar que se está ejecutando el `.cmd` y no el `.ps1` directamente.

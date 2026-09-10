# Reset AnyDesk en Windows

**Versión del documento:** 2.0
**Scripts incluidos:** anydesk.ps1 / anydesk.cmd

---

## Descripción

Solución para resetear el ID y la configuración de AnyDesk en equipos Windows. Funciona tanto para instalaciones convencionales como para ejecuciones standalone (sin instalación), es agnóstico del idioma del sistema operativo y de la ruta del ejecutable. Si AnyDesk no está instalado, lo instala automáticamente via winget.

---

## Requisitos previos

- Windows 10/11 o Windows Server 2016+ (64 bits)
- Privilegios de administrador local
- PowerShell 5.1 o superior (incluido en Windows 10+)
- Conexión a internet (requerida solo si AnyDesk no está instalado)

---

## Archivos

| Archivo | Descripción |
|---|---|
| `anydesk.ps1` | Script principal. Detección, kill, reset, backup, restore y log |
| `anydesk.cmd` | Lanzador. Eleva privilegios y ejecuta el `.ps1` |

> [!IMPORTANT]
> Ambos archivos deben estar en el mismo directorio. El usuario debe ejecutar únicamente el `.cmd`.

---

## Uso

1. Copiar `anydesk.ps1` y `anydesk.cmd` al equipo destino.
2. Hacer doble clic sobre `anydesk.cmd`.
3. Aceptar la elevación de privilegios (UAC).
4. El script se ejecuta automáticamente y relanza AnyDesk al finalizar.

> [!NOTE]
> Si AnyDesk no está corriendo ni instalado, el script lo instala automáticamente via winget antes de continuar.

---

## Comportamiento del script

### Paso 1 — Sincronización de hora

Antes de cualquier otra acción, el script verifica la hora del sistema contra `time.windows.com` via NTP (UDP 123). Si el desfase es mayor a 60 segundos, ejecuta `w32tm /resync /force` y espera 3 segundos antes de continuar.

> [!IMPORTANT]
> Un desfase horario significativo impide que AnyDesk valide certificados TLS y obtenga ID. Este paso resuelve el problema de forma automática en instalaciones limpias de Windows donde la hora no fue configurada.

### Paso 2 — Detección automática

El script busca la ruta del ejecutable en el siguiente orden, deteniéndose en el primer éxito:

| Método | Aplica a |
|---|---|
| Proceso activo | AnyDesk corriendo al momento de ejecutar el script |
| ProgramFiles | Instalación convencional en `%ProgramFiles%`, `%ProgramFiles(x86)%`, `%LocalAppData%\Programs\AnyDesk\` |
| UserAssist (registro) | Standalone ejecutado al menos una vez (decodifica ROT13, verifica ProductName) |
| Prefetch | `C:\Windows\Prefetch\*.pf` — extrae ruta del exe y verifica ProductName |
| winget | Si ningún método anterior funciona, instala `AnyDesk.AnyDesk` silenciosamente |

La detección usa `ProductName -like '*AnyDesk*'` en lugar del nombre del proceso — cubre ejecutables renombrados (`remoto.exe`, etc.). El desinstalador (`*Uninst*`) está explícitamente excluido en todos los métodos.

Si la ruta es encontrada pero el exe ya no existe físicamente, el script **aborta sin resetear**. Todo queda registrado en el log.

### Paso 3 — Kill de procesos

Termina todos los procesos AnyDesk por `ProductName` con `Stop-Process -Force`. Si AnyDesk está instalado formalmente, también detiene el servicio de Windows con `Stop-Service -Force`. Espera hasta 5 segundos a que los procesos desaparezcan antes de continuar.

### Paso 4 — Reset de configuración

Busca archivos de configuración y traza en todas las ubicaciones posibles:

| Ubicación | Aplica a |
|---|---|
| `%ProgramData%\AnyDesk\` | Instalación estándar |
| `%AppData%\AnyDesk\` | Perfil de usuario |
| `%LocalAppData%\AnyDesk\` | Perfil local |
| Directorio del `.exe` | Standalone |

Archivos reseteados: `system.conf`, `service.conf`, `ad.trace` (archivo de traza, no de configuración).

> [!IMPORTANT]
> `user.conf` está excluido del reset — preserva los alias, favoritos y sesiones recientes configurados por el técnico.

### Paso 4.1 — Backup con timestamp

Cada archivo reseteado se renombra con el timestamp de la ejecución en lugar de eliminarse:

```
system.conf.2026-06-11_193540.backup
service.conf.2026-06-11_193540.backup
```

Esto preserva el historial completo: cada reset genera sus propios backups sin pisar los anteriores.

### Paso 5 — Relaunch

**5a. Conectividad** — verifica `relay.anydesk.com:443` antes de relanzar. Loggea OK o WARN pero no aborta.

**5b. Relaunch** — si AnyDesk está instalado formalmente: `Start-Service` + `Start-Process`. Si es standalone: `Start-Process` directo.

**5c. Polling de ID** — espera hasta 30 segundos monitoreando `system.conf` hasta que aparezca `ad.anynet.id`:
- `ID obtenido: 1 420 433 329 (espera: 2s)` — éxito real
- `WARN: Sin ID tras 30s` — AnyDesk arrancó pero no se registró

### Paso 6 — Restauración de alias y sesiones recientes

Una vez obtenido el nuevo ID, el script extrae la línea `ad.roster.items` del backup de `user.conf` e inyecta esa información en el nuevo `user.conf` generado por AnyDesk. Esto restaura automáticamente los nombres personalizados y el panel de sesiones recientes.

Si AnyDesk no genera un nuevo `user.conf` en 30 segundos, restaura el backup completo como fallback.

---

## Qué se preserva y qué se pierde

### Se preserva
- **Alias y nombres personalizados de equipos remotos** — `user.conf` no se toca
- **Panel de sesiones recientes** — `ad.roster.items` se restaura automáticamente

### Se pierde inevitablemente

**Lado cliente (PC reseteada):**
- **Contraseña de acceso desatendido** (perfil por defecto y perfiles personalizados como "IT Support"): guardada en `service.conf` cifrada y vinculada al ID anterior. Al cambiar el ID el hash queda inválido. Hay que reconfigurar la contraseña manualmente en Seguridad → Permisos después de cada reset.

**Lado soporte (PC del técnico):**
- **Contraseñas recordadas para conectarse a equipos remotos**: los tokens guardados al marcar "Recordar contraseña" están cifrados y vinculados al ID del equipo remoto. Al cambiar el ID del cliente los tokens quedan inválidos. Hay que ingresar la contraseña manualmente la primera vez después del reset y volver a marcar "Recordar".

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
| Hora NTP | Verificación de desfase horario |
| Método de detección | PROCESO, PROGRAMFILES, USERASSIST, PREFETCH o WINGET |
| PID | ID del proceso antes del kill |
| AnyDesk ID | ID antes del reset (extraído de `system.conf`) |
| Versión | Versión del ejecutable |
| Tipo | `INSTALADO` o `STANDALONE` |
| Ruta del exe | Path completo del ejecutable detectado |
| Archivos reseteados | Lista con ruta completa de cada archivo renombrado |
| Conectividad | Estado de `relay.anydesk.com:443` |
| Relaunch | Confirmación de éxito o error |
| ID obtenido | Nuevo ID post-reset con tiempo de espera |
| Restauración | Estado del restore de `ad.roster.items` |

### Ejemplo de log

```
================================================
 anydesk-reset  |  2026-06-11_193540
 Host   : PC-RECEPCION
 Usuario: DOMINIO\juan
================================================

--- Verificando hora del sistema... ---
[2026-06-11_193540][INFO] Hora local (UTC): 2026-06-11 19:35:40
[2026-06-11_193540][INFO] Hora NTP   (UTC): 2026-06-11 19:35:39
[2026-06-11_193540][INFO] Diferencia: 1.1s
[2026-06-11_193540][INFO] Hora OK (desfase dentro del margen aceptable)

--- Buscando AnyDesk... ---
[2026-06-11_193540][INFO] Proceso activo - PID: 9812 | Nombre: AnyDesk
[2026-06-11_193540][INFO] Ruta exe: C:\Program Files (x86)\AnyDesk\AnyDesk.exe
[2026-06-11_193540][INFO] Exe validado via PROCESO : C:\Program Files (x86)\AnyDesk\AnyDesk.exe
[2026-06-11_193540][INFO] Tipo: INSTALADO
[2026-06-11_193540][INFO] Version: 9.7.5
[2026-06-11_193540][INFO] AnyDesk ID (antes del reset): 481900045

--- Terminando procesos AnyDesk... ---
[2026-06-11_193540][INFO] Terminado PID 9812
[2026-06-11_193540][INFO] Servicio AnyDesk detenido
[2026-06-11_193540][INFO] Procesos terminados (espera: 0s)

--- Reseteando configuracion... ---
[2026-06-11_193540][INFO] Backup: C:\ProgramData\AnyDesk\system.conf.2026-06-11_193540.backup
[2026-06-11_193540][INFO] Backup: C:\ProgramData\AnyDesk\service.conf.2026-06-11_193540.backup
[2026-06-11_193540][INFO] 2 archivo(s) reseteado(s)

--- Relanzando AnyDesk... ---
[2026-06-11_193540][INFO] Conectividad OK (relay.anydesk.com:443)
[2026-06-11_193540][INFO] Servicio AnyDesk iniciado
[2026-06-11_193540][INFO] Relaunch OK (instalado): C:\Program Files (x86)\AnyDesk\AnyDesk.exe
[2026-06-11_193540][INFO] ID obtenido: 1420433329 (espera: 2s)

--- Restaurando alias y sesiones recientes... ---
[2026-06-11_193540][INFO] ad.roster.items encontrado en backup (312 chars)
[2026-06-11_193540][INFO] ad.roster.items reemplazado en nuevo user.conf
[2026-06-11_193540][INFO] Restauracion de alias y sesiones recientes completada.
================================================
```

> [!TIP]
> Si el AnyDesk ID no aparece en el log, verificar que `w32tm /resync` tuvo éxito (paso 1) y que `relay.anydesk.com:443` es alcanzable (paso 5).

---

## Troubleshooting

**AnyDesk arranca pero no obtiene ID (Sin ID tras 30s)**
Causa más común en instalaciones limpias de Windows: desfase horario. El script lo corrige automáticamente en el paso 1. Si persiste, verificar en el log si `w32tm /resync` tuvo éxito y si `relay.anydesk.com:443` es alcanzable.

**AnyDesk no se relanza después del reset**
Verificar que el ejecutable sigue en la ruta registrada en el log. En modo standalone, si el usuario movió el archivo entre ejecuciones, el relaunch fallará.

**"No se pudo encontrar ni instalar AnyDesk"**
winget no está disponible en el sistema o falló la instalación. Verificar conectividad a internet e instalar AnyDesk manualmente desde `https://anydesk.com/es/downloads/windows`.

**El AnyDesk ID no cambió después del reset**
Verificar en el log que al menos `system.conf` fue reseteado. Si AnyDesk regenera el mismo ID, puede existir otro `system.conf` en una ubicación no contemplada — revisar el log para identificar cuáles archivos fueron encontrados.

**Los alias y sesiones recientes no se restauraron**
El paso 6 requiere que `user.conf` haya existido antes del reset. Si era una instalación nueva sin sesiones previas, no hay nada que restaurar — es comportamiento esperado.

**Error de ExecutionPolicy en PowerShell**
Verificar que se está ejecutando el `.cmd` y no el `.ps1` directamente. El lanzador aplica `-ExecutionPolicy Bypass` automáticamente.

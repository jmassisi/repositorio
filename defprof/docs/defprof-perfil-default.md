# Perfil por defecto en Windows con DefProf

**Versión del documento:** 1.2
**Herramienta:** DefProf — [ForensiT](https://www.forensit.com/downloads.html)
**Sistema operativo:** Windows 10/11 — Windows Server 2016+ (64 bits)

---

## Descripción

DefProf convierte un usuario real en la plantilla que Windows usa para crear todos los usuarios futuros. Es un proceso cíclico: cuando el estándar cambia, se actualiza el molde y se vuelve a correr.

**Regla de oro:** siempre correr `defprof` desde una cuenta distinta a la que se usa como molde. Windows bloquea los archivos del perfil (`NTUSER.DAT`) mientras la sesión está activa.

---

## Requisitos previos

- Windows 10/11 o Windows Server 2016+ (64 bits)
- Privilegios de administrador local
- PowerShell 5.1 o superior (incluido en Windows 10+)
- `defprof.exe` versionado en el repo en `C:\repositorio\defprof\bin\defprof.exe`

> [!NOTE]
> DefProf se distribuye desde el repositorio (carpeta `bin\`). No requiere descarga manual ni instalación: el script lo verifica e integra en cada ejecución.

---

## Archivos

| Archivo | Descripción |
|---|---|
| `bin\defprof.exe` | Binario de DefProf, versionado y verificado (SHA-256 + firma Authenticode) en cada ejecución |
| `actualizar-default.ps1` | Lista usuarios locales, verifica integridad de `defprof.exe` y ejecuta DefProf sobre el molde elegido |
| `actualizar-default.cmd` | Lanzador. Eleva privilegios y ejecuta el `.ps1` |

> [!IMPORTANT]
> Ambos scripts deben estar junto a la carpeta `bin\`. El usuario debe ejecutar únicamente el `.cmd`.

---

## Prerequisito — Limpiar bloatware a nivel sistema

DefProf copia el perfil de usuario, pero las apps provisionadas por Windows se reinstalan para cada usuario nuevo independientemente del molde. Removerlas antes de capturar el molde:

```powershell
# Ver apps provisionadas
Get-AppxProvisionedPackage -Online | Select-Object DisplayName

# Remover una (reemplazar el PackageName con el valor exacto del comando anterior)
Remove-AppxProvisionedPackage -Online -PackageName "nombre_del_paquete"
```

> [!NOTE]
> Esto es una operación de sistema, no de perfil. Se hace una sola vez y afecta a todos los usuarios futuros.

---

## Paso 1 — Captura inicial del molde

> Se hace una sola vez. Requiere activar la cuenta `Administrator` integrada de Windows.

1. Activar la cuenta `Administrator`:
   ```cmd
   net user Administrator /active:yes
   ```
2. Asignarle una contraseña si no tiene.
3. Cerrar sesión en el usuario molde.
4. Iniciar sesión como `Administrator`.
5. Abrir CMD como Administrador y ejecutar:
   ```cmd
   C:\repositorio\defprof\bin\defprof.exe <usuario_molde>
   ```
6. Verificar que el proceso completó sin errores.
7. Desactivar `Administrator`:
   ```cmd
   net user Administrator /active:no
   ```

A partir de este momento, cualquier usuario nuevo que se cree en la PC nace como clon del molde.

---

## Paso 2 — Crear usuario desde el molde

1. Crear el nuevo usuario:
   ```cmd
   net user visita /add
   net localgroup administrators visita /add
   ```
2. Iniciar sesión en `visita` — heredará automáticamente el perfil del molde.
3. Realizar los ajustes deseados (apps, menú inicio, configuraciones).
4. **Antes de cerrar sesión:** cerrar sesiones de correo, Google u otras cuentas. Borrar historial del navegador.
5. Cerrar sesión en `visita`.

---

## Paso 3 — Actualizar el molde con los cambios

1. Iniciar sesión en el usuario molde (u otra cuenta admin distinta al usuario a capturar).
2. Ejecutar `actualizar-default.cmd`.
3. Seleccionar el usuario a capturar cuando el script lo solicite.
4. A partir de este momento, cualquier usuario nuevo hereda ese estado.

> [!NOTE]
> El script verifica en cada ejecución `C:\repositorio\defprof\bin\defprof.exe` contra su hash SHA-256 conocido y la firma Authenticode de ForensiT. Si no coincide, aborta sin ejecutar nada.

---

## Ciclo de actualización

```
Configurar molde → Cerrar sesión → Entrar a otra cuenta admin → ejecutar actualizar-default.cmd
```

Cada vez que se quiera actualizar el estándar:

1. Iniciar sesión en el usuario molde actual.
2. Aplicar los cambios deseados.
3. Limpiar credenciales e historial.
4. Cerrar sesión.
5. Entrar a cualquier otra cuenta admin.
6. Ejecutar `actualizar-default.cmd` y elegir el usuario molde.

---

## Resumen de cuentas

| Cuenta | Rol | Observaciones |
|---|---|---|
| `Administrator` | Operación inicial | Activar solo para capturar el molde inicial. Desactivar después. |
| Cuenta admin operativa | Operación diaria | Desde donde se ejecuta defprof. Distinta al molde activo. |
| Usuario molde | Plantilla del sistema | Sin credenciales activas. Se configura, se captura y se mantiene limpio. |
| Usuarios nuevos | Producción | Nacen como clones del último molde capturado. |

---

## Verificación de integridad

Antes de cada ejecución, `actualizar-default.ps1` comprueba `bin\defprof.exe`:

| Check | Mecanismo |
|---|---|
| Hash SHA-256 | Comparación contra el hash pinned en el script (`Get-FileHash`) |
| Firma Authenticode | `Get-AuthenticodeSignature` — debe ser `Valid` y firmante `ForensiT Limited` |

Si cualquiera de los dos falla, el script muestra el motivo y aborta. Nunca ejecuta un binario no verificado.

---

## ¿Por qué se distribuye `defprof.exe` dentro del repositorio?

El binario se versiona en `defprof/bin/` (y viaja en el despliegue a `C:\repositorio`) porque el sitio de [ForensiT](https://www.forensit.com/downloads.html) protege sus descargas con un challenge de Cloudflare que bloquea la descarga automatizada por script (devuelve una página HTML de verificación en lugar del archivo). La descarga manual desde el navegador funciona, pero no es reproducible ni automatizable.

Distribuirlo con el repo resuelve tres cosas:

1. **Reproducibilidad** — el despliegue funciona igual en cualquier equipo, sin depender de una descarga externa.
2. **Integridad verificable** — el binario se valida contra hash y firma en cada ejecución; si alguien lo reemplaza, el script aborta.
3. **Trazabilidad** — el binario queda versionado junto al script que lo usa: mismo commit, misma versión, mismo despliegue.

### Método de verificación

- **Hash:** el hash SHA-256 del binario (`Get-FileHash -Algorithm SHA256`) se compara contra un valor **pinned en el script**. El valor se fijó contrastando múltiples fuentes independientes (descarga directa del sitio oficial de [ForensiT](https://www.forensit.com/downloads.html) y paquete [DefProf](https://community.chocolatey.org/packages/defprof) del repositorio de Chocolatey) — ambas dieron el mismo hash para el mismo `defprof.exe`.
- **Firma:** la firma Authenticode del binario debe ser `Valid` y pertenecer al firmante **ForensiT Limited**. El certificado base lo emite Symantec/VeriSign y la cadena se verifica contra las raíces de confianza de Windows (`Get-AuthenticodeSignature`).

> [!NOTE]
> La descarga original desde el sitio de ForensiT (`https://www.forensit.com/Downloads/DefProf.msi`) se descomprime con `msiexec /a` y de ahí se extrae `DefProf.exe`. Tanto el `.exe` como el `.msi` de origen conviven verificados en el repositorio de trabajo durante el proceso de implantación.

---

## Log

Cada ejecución genera un archivo de log en:

```
C:\repositorio\logs\defprof\defprof_YYYY-MM-DD_HHmmss.log
```

### Información registrada

| Campo | Descripción |
|---|---|
| Fecha y hora | Timestamp de la ejecución |
| Hostname | Nombre del equipo |
| Usuario ejecutor | Cuenta desde la que se corrió el script |
| Resultado de verificación | Hash y firma de `defprof.exe` |
| Usuario molde | Nombre del perfil capturado con defprof |
| Resultado | Éxito o error reportado por defprof |

---

## Troubleshooting

**"No se encontró defprof.exe en el repositorio"**
La carpeta `bin\` no está en `C:\repositorio\defprof\`. Actualizar el repositorio desde el menú `[A]` y volver a intentar.

**"defprof.exe no superó la verificación"**
El binario en `bin\` no coincide con el hash o la firma esperados. No ejecutar. Reportar el reemplazo y restaurar el binario verificado desde el repo.

**defprof falla con error de acceso**
La sesión del usuario molde está activa. Cerrar sesión completamente antes de ejecutar defprof.

**Los usuarios nuevos no heredan los cambios**
Verificar que defprof completó sin errores revisando el log. Un error silencioso puede dejar el perfil predeterminado sin actualizar.

**Error de ExecutionPolicy en PowerShell**
El lanzador `.cmd` aplica `-ExecutionPolicy Bypass` solo para esa ejecución. Si el error persiste, verificar que se está ejecutando el `.cmd` y no el `.ps1` directamente.
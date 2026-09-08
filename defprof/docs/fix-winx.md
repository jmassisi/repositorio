# Reparación del menú Win + X post-defprof

**Versión del documento:** 1.0
**Herramienta:** Fix-WinX (reparación complementaria de [perfil por defecto con DefProf](defprof-perfil-default.md))
**Sistema operativo:** Windows 10/11

---

## 1. Problema que resuelve

La falla en el menú contextual de Inicio (**Win + X**): deja de responder, no despliega, o muestra las opciones desordenadas sin líneas divisorias.

## 2. Cómo se descubrió

Al usar **DefProf** para clonar una cuenta funcional hacia el perfil `Default`, las cuentas nuevas nacieron sin la carpeta plantilla `WinX`. Se detectó que el menú **no** lee sus accesos directos desde `AppData\Roaming`, sino exclusivamente desde:

`C:\Users\<Usuario>\AppData\Local\Microsoft\Windows\WinX`

Al ejecutarse DefProf, los accesos directos ocultos (`Group1`, `Group2` y `Group3`) no se transfieren a la plantilla por defecto, o quedaron vacíos.

## 3. A quién afecta

- A la cuenta recién creada a partir del clonado con DefProf.
- A cualquier cuenta que se cree a futuro en el equipo mediante DefProf.

## 4. Cómo se implementa

1. Ejecutar la opción **fix-winx** del menú del repositorio (`C:\repositorio\menu.cmd`), o directamente el lanzador `C:\repositorio\defprof\scripts\fix-winx.cmd`.
2. Indicar el **usuario con Win + X funcional** (origen). Si se deja vacío, el script lista los usuarios locales para elegir.
3. El script copia los accesos directos ocultos hacia la plantilla `Default`, la carpeta WinX del usuario actual, normaliza atributos y reinicia el Explorador.

> [!NOTE]
> Antes de copiar, el script respalda el estado actual del WinX en `C:\repositorio\logs\defprof\winx_bkp_<fecha>\`.

### Ejecución sin menú ni lanzador

```powershell
# PowerShell como Administrador
.\fix-winx.ps1 -SourceUser "nombre_usuario_origen"
```

## 5. Archivos

| Archivo | Descripción |
|---|---|
| `fix-winx.ps1` | Verifica el usuario origen, respalda, copia accesos directos ocultos, normaliza permisos y reinicia explorer |
| `fix-winx.cmd` | Lanzador. Eleva privilegios y ejecuta el `.ps1` |

## 6. Log

Cada ejecución genera un archivo en:

```
C:\repositorio\logs\defprof\fix-winx_YYYY-MM-DD_HHmmss.log
```

### Información registrada

| Campo | Descripción |
|---|---|
| Fecha y hora | Timestamp de la ejecución |
| Hostname | Nombre del equipo |
| Usuario ejecutor | Cuenta desde la que se corrió el script |
| Usuario origen | Cuenta desde la que se copió el WinX |
| Destino | Plantilla `Default` y/o usuario actual |
| Resultado copia | Éxito o error de `xcopy` (exit code) |
| Resultado atributos | Éxito o error de `attrib` (exit code) |
| Backup | Path del respaldo del WinX previo |
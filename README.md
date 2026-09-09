# Toolkit Técnico - iGeek

Repositorio centralizado de herramientas, scripts y configuraciones para soporte técnico Windows.

## Despliegue en equipo cliente

Abrir PowerShell y ejecutar:

```powershell
irm repositorio.igeek.ar | iex
```

Se descarga en `C:\repositorio`, limpia rastros al finalizar y abre la carpeta.

## Herramientas disponibles

- **AnyDesk Reset** — Resetea ID y configuración
- **DefProf** — Despliega y actualiza el perfil por defecto de Windows
- **GLPI Agent** — Instalación y forzado de inventario
- **Office Install** — Instalación desatendida de Office
- **Sysinternals** — Herramientas de Sysinternals (Autologon)
- **Winget** — Instalación de aplicaciones vía Winget desde una lista (selección múltiple)
- **Zabbix Agent** — Instalación y configuración de monitoreo *(en progreso)*

## Gestión

**Verificar actualizaciones** (`check.ps1`)  
Compara la fecha local de `C:\repositorio` contra el último commit en GitHub. Si hay cambios disponibles, ofrece actualizar en el momento con `[A]` o salir con `[Enter]`.

```powershell
# Ejecutar desde C:\repositorio
.\check.ps1
```

**Actualizar el repositorio** (`repositorio.ps1`)  
Descarga la última versión desde GitHub, preserva los logs de todos los elementos, limpia archivos de infraestructura y abre la carpeta al finalizar. Se ejecuta automáticamente al correr el comando de despliegue.

```powershell
irm repositorio.igeek.ar | iex
```

## Estructura

| Carpeta | Contenido | Documentación |
|---|---|---|
| `anydesk/` | Reset de ID y configuración de AnyDesk | [anydesk-reset.md](anydesk/docs/anydesk-reset.md) |
| `defprof/` | Perfil por defecto con DefProf | [defprof-perfil-default.md](defprof/docs/defprof-perfil-default.md) |
| `glpi/` | Agente y script de instalación | [glpi-agent-instalacion.md](glpi/docs/glpi-agent-instalacion.md) |
| `office/` | Instalación desatendida de Office | [instalar-office.md](office/docs/instalar-office.md) |
| `scripts/sistema` | Scripts de optimización y configuración del sistema | — |
| `scripts/drivers` | Backup y restauración de drivers | — |
| `sysinternals/` | Herramientas de Sysinternals (autologon) | — |
| `winget/` | Instalación de aplicaciones vía Winget desde lista | [winget-instalar.md](winget/docs/winget-instalar.md) |
| `workarounds/` | Workarounds puntuales (fix de alias winget, etc.) | [workarounds.md](workarounds/docs/workarounds.md) |
| `zabbix/` | Agente y configuración de monitoreo | — |
| `registro/` | Tweaks de registro (.reg) | — |

---

## Descargo de responsabilidad

**AS IS sin garantías.** Este repositorio se distribuye "tal cual" y **sin garantía de ningún tipo**, expresa o implícita, incluyendo pero no limitado a garantías de idoneidad para un fin particular y no infracción.

El uso de estas herramientas y scripts es **bajo la responsabilidad del operador**. Los scripts incluyen verificaciones de integridad (hash y firma) y toma de backups antes de modificaciones, pero **ninguna de estas salvaguardas garantiza** que el resultado sea el esperado en todos los entornos. Antes de usar una herramienta en producción, validarla en un entorno de prueba.

Los binarios de terceros versionados en este repositorio (ej. `defprof/bin/defprof.exe`) pertenecen a sus respectivos autores y se distribuyen con fines de soporte técnico. Verificar siempre su origen y licencia antes de su uso.

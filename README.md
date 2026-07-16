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

| Carpeta | Contenido |
|---|---|
| `anydesk/` | Reset de ID y configuración de AnyDesk |
| `defprof/` | Perfil por defecto con DefProf |
| `GLPI/` | Agente y script de instalación |
| `office/` | Instalación desatendida de Office |
| `scripts/sistema` | Scripts de optimización y configuración del sistema |
| `scripts/drivers` | Backup y restauración de drivers |
| `sysinternals/` | Herramientas de Sysinternals (autologon) |
| `Zabbix/` | Agente y configuración de monitoreo |
| `registro/` | Tweaks de registro (.reg) |
# test

# Toolkit Técnico - iGeek

Repositorio centralizado de herramientas, scripts y configuraciones para soporte técnico Windows.

## Despliegue en equipo cliente

Abrir PowerShell y ejecutar:

```powershell
irm repositorio.igeek.ar | iex
```

Se descarga en `C:\repositorio`, limpia rastros al finalizar y abre la carpeta.

## Estructura

| Carpeta | Contenido |
|---|---|
| `anydesk/scripts` | Reset de ID y configuración de AnyDesk |
| `anydesk/docs` | Documentación del reset de AnyDesk |
| `scripts/sistema` | Scripts de optimización y configuración del sistema |
| `scripts/drivers` | Backup y restauración de drivers |
| `registro` | Tweaks de registro (.reg) |
| `GLPI/scripts` | Agente y script de inventario forzado |
| `GLPI/docs` | Documentación del agente GLPI |
| `Zabbix` | Agente y configuración de monitoreo |

## Gestión

Cualquier actualización se refleja automáticamente en el próximo despliegue.

```powershell
git add . && git commit -m "descripcion" && git push
```
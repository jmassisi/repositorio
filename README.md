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
| `scripts/sistema` | Scripts de optimización y configuración del sistema |
| `scripts/drivers` | Backup y restauración de drivers |
| `scripts/anydesk` | Reset de ID y licencia de AnyDesk |
| `registro` | Tweaks de registro (.reg) |
| `GLPI` | Agente y script de inventario forzado |
| `Zabbix` | Agente y configuración de monitoreo |

## Gestión

Cualquier actualización se refleja automáticamente en el próximo despliegue.

```powershell
git add . && git commit -m "descripcion" && git push
```
# Instalación del Agente GLPI en Windows

**Versión del documento:** 1.1  
**GLPI Server:** https://soporte.igeek.ar  
**Versión GLPI:** 11.0.6  
**Versión agente:** 1.17  

---

## Requisitos previos

- Windows 10/11 o Windows Server 2016+ (64 bits)
- Privilegios de administrador local
- Acceso a internet (descarga desde github.com)
- Acceso de red al servidor GLPI (`https://soporte.igeek.ar`)

---

## Método 1 — Instalación silenciosa con script (recomendada)

1. Descargar el script `instalar-glpi-agent.bat` desde el repositorio interno.
2. Ejecutar con clic derecho → **Ejecutar como administrador**.

El script descarga automáticamente el instalador desde GitHub, realiza la instalación silenciosa y elimina el archivo descargado al finalizar.

> [!NOTE]
> La versión del agente descargada está fijada en el script (`GLPI_AGENT_VERSION`). Si necesitás actualizar la versión, editá esa variable antes de ejecutar.

---

## Método 2 — Instalación silenciosa manual

1. Descargar el instalador desde:  
   https://github.com/glpi-project/glpi-agent/releases/latest  
   Archivo: `GLPI-Agent-X.XX-x64.msi`

2. Ejecutar desde una consola con privilegios de administrador:

```cmd
msiexec /i "GLPI-Agent-X.XX-x64.msi" /quiet /norestart ^
  SERVER="https://soporte.igeek.ar" ^
  RUNNOW=1 ^
  EXECMODE=1 ^
  ADD_FIREWALL_EXCEPTION=1 ^
  AGENTMONITOR=1 ^
  TAG="Staging"
```

**Parámetros utilizados:**

| Parámetro | Valor | Descripción |
|---|---|---|
| `SERVER` | `https://soporte.igeek.ar` | URL del servidor GLPI |
| `RUNNOW` | `1` | Ejecuta el inventario inmediatamente al finalizar la instalación |
| `EXECMODE` | `1` | Corre el agente como servicio de Windows (inicio automático) |
| `ADD_FIREWALL_EXCEPTION` | `1` | Agrega excepción en el firewall de Windows |
| `AGENTMONITOR` | `1` | Instala el ícono de bandeja para monitorear el agente |
| `TAG` | `Staging` | Clasifica el equipo como pendiente de asignación definitiva |

> [!TIP]
> El valor `Staging` indica que el equipo está pendiente de clasificación. Una vez asignado a su entidad en GLPI, el TAG puede actualizarse o eliminarse.

> [!IMPORTANT]
> El comando debe ejecutarse desde el directorio donde se encuentra el archivo `.msi`, o especificar la ruta completa al archivo.

> [!NOTE]
> Desde la versión 1.8 en adelante, solo se distribuye instalador de 64 bits.

---

## Método 3 — Instalación manual (GUI)

1. Descargar el instalador desde:  
   https://github.com/glpi-project/glpi-agent/releases/latest

2. Hacer doble clic sobre el archivo `GLPI-Agent-X.XX-x64.msi`.

3. **Pantalla de bienvenida** — Clic en **Next**.

4. **Acuerdo de licencia** — Aceptar los términos y clic en **Next**.

5. **Selección de componentes** — Dejar la selección por defecto (incluye el servicio y el monitor). Clic en **Next**.

6. **Configuración del servidor:**
   - **Server URL:** `https://soporte.igeek.ar`
   - **Tag:** `Staging`
   - Clic en **Next**.

7. **Modo de ejecución** — Seleccionar **Service (Recommended)**. Clic en **Next**.

8. **Opciones adicionales:**
   - Marcar **Add firewall exception**
   - Marcar **Run now** para enviar inventario inmediatamente
   - Clic en **Next**.

9. **Confirmación** — Clic en **Install**. Puede requerir confirmación UAC.

10. **Finalización** — Clic en **Finish**.

---

## Verificación post-instalación

### En el equipo local

**1. Verificar que el servicio está corriendo:**

```cmd
sc query "GLPI-Agent"
```

El estado debe mostrar `RUNNING`. También puede verificarse desde `services.msc` buscando **GLPI Agent**.

**2. Acceder a la interfaz local del agente:**

Abrir en el navegador: `http://localhost:62354`

Desde esta interfaz puede forzarse manualmente un nuevo inventario.

**3. Verificar el log del agente:**

```
C:\Program Files\GLPI-Agent\var\glpi-agent.log
```

Buscar líneas que contengan `Inventory ok` o `inventory sent` para confirmar el envío exitoso.

---

### En el servidor GLPI

1. Ingresar a `https://soporte.igeek.ar` con credenciales de administrador.
2. Ir a **Activos → Computadoras**.
3. Buscar el equipo por nombre de host o dirección IP.
4. Verificar que:
   - El equipo aparece en el listado.
   - La fecha de **Última actualización de inventario** corresponde a la instalación reciente.
   - Los datos de hardware (RAM, CPU, disco) están completos.

> [!TIP]
> Si el equipo no aparece en los primeros 5 minutos, verificar conectividad hacia `https://soporte.igeek.ar` y revisar el log local del agente.

---

## Desinstalación

```cmd
msiexec /x "GLPI-Agent-X.XX-x64.msi" /quiet
```

O desde **Panel de Control → Programas → GLPI Agent → Desinstalar**.

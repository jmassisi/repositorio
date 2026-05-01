# Instalación del Agente GLPI en Windows

**Versión del documento:** 2.0  
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

## Archivos

| Archivo | Descripción |
|---|---|
| `instalar-glpi-agent.cmd` | Lanzador. Eleva privilegios y ejecuta el `.ps1` |
| `instalar-glpi-agent.ps1` | Script principal de instalación |

> [!IMPORTANT]
> Ambos archivos deben estar en el mismo directorio. Ejecutar únicamente el `.cmd`.

---

## Método 1 — Instalación con script (recomendada)

1. Copiar `instalar-glpi-agent.cmd` e `instalar-glpi-agent.ps1` al equipo destino.
2. Ejecutar con clic derecho sobre el `.cmd` → **Ejecutar como administrador**.

El script realiza automáticamente:

- Detección de versión instalada — si ya existe una versión previa, avisa y solicita confirmación antes de desinstalar.
- Descarga del instalador desde GitHub.
- Pregunta interactiva para instalar el ícono de bandeja (AGENTMONITOR).
- Instalación silenciosa del agente.
- Envío forzado de inventario al servidor GLPI.
- Generación de inventario local XML en `C:\repositorio\GLPI\logs\`.
- Creación de accesos directos a la interfaz local del agente en `C:\repositorio\GLPI\`.

> [!NOTE]
> La versión del agente está fijada en el script (`$GLPI_AGENT_VERSION`). Para actualizar, modificar esa variable antes de ejecutar.

> [!NOTE]
> Desde la versión 1.8 en adelante, solo se distribuye instalador de 64 bits.

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
  AGENTMONITOR=1
```

**Parámetros utilizados:**

| Parámetro | Valor | Descripción |
|---|---|---|
| `SERVER` | `https://soporte.igeek.ar` | URL del servidor GLPI |
| `RUNNOW` | `1` | Ejecuta el inventario inmediatamente al finalizar la instalación |
| `EXECMODE` | `1` | Corre el agente como servicio de Windows (inicio automático) |
| `ADD_FIREWALL_EXCEPTION` | `1` | Agrega excepción en el firewall de Windows |
| `AGENTMONITOR` | `0` o `1` | Instala el ícono de bandeja para monitorear el agente |

> [!IMPORTANT]
> El comando debe ejecutarse desde el directorio donde se encuentra el archivo `.msi`, o especificar la ruta completa.

---

## Método 3 — Instalación manual (GUI)

1. Descargar el instalador desde:  
   https://github.com/glpi-project/glpi-agent/releases/latest

2. Hacer doble clic sobre el archivo `GLPI-Agent-X.XX-x64.msi`.

3. **Pantalla de bienvenida** — Clic en **Next**.

4. **Acuerdo de licencia** — Aceptar los términos y clic en **Next**.

5. **Selección de componentes** — Dejar la selección por defecto. Clic en **Next**.

6. **Configuración del servidor:**
   - **Server URL:** `https://soporte.igeek.ar`
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

Desde esta interfaz puede forzarse manualmente un nuevo inventario. El acceso directo también está disponible en `C:\repositorio\GLPI\`.

**3. Inventario local XML:**

```
C:\repositorio\GLPI\logs\NOMBREEQUIPO.xml
```

Generado automáticamente por el script al finalizar la instalación.

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
> Si el equipo no aparece en los primeros 5 minutos, verificar conectividad hacia `https://soporte.igeek.ar` y revisar la interfaz local del agente en `http://localhost:62354`.

---

## Desinstalación

Desde consola con privilegios de administrador:

```cmd
msiexec /x "GLPI-Agent-X.XX-x64.msi" /quiet
```

O desde **Panel de Control → Programas → GLPI Agent → Desinstalar**.

# Instalacion de Microsoft Office en Windows

**Version del documento:** 1.2
**Scripts incluidos:** office.cmd / office.ps1
**Sistema operativo:** Windows 10/11 - Windows Server 2016+ (64 bits)
**Requiere:** PowerShell 5.1+, privilegios de administrador, acceso a internet (modo online)

---

## Descripcion

Solucion para instalar Microsoft 365 Apps o Office LTSC 2024 en equipos Windows de forma desatendida y controlada, utilizando el Office Deployment Tool (ODT) oficial de Microsoft. Permite elegir que aplicaciones se instalan mediante archivos XML de configuracion personalizados.

El script detecta instalaciones previas de Office y ofrece desinstalarlas limpiamente antes de continuar. Detecta y actualiza automaticamente el ODT, presenta un menu dinamico con los perfiles disponibles (incluyendo descripcion de cada perfil) y registra cada ejecucion en un log independiente.

---

## Requisitos previos

- Windows 10/11 o Windows Server 2016+ (64 bits)
- Privilegios de administrador local
- PowerShell 5.1 o superior (incluido en Windows 10+)
- Acceso a internet para modo online y para verificar actualizaciones del ODT

---

## Archivos

| Archivo | Descripcion |
|---|---|
| office.cmd | Lanzador. Eleva privilegios y ejecuta el .ps1 en una sola ventana de PowerShell |
| office.ps1 | Script principal. ODT, deteccion, desinstalacion, menu, instalacion y log |
| xml\ | Carpeta con los perfiles de instalacion en formato .xml |
| logs\ | Carpeta con los registros de cada ejecucion |

---

## Estructura de carpetas

```
office\
├── office.cmd
├── office.ps1
├── xml\
│   ├── configuracion01.xml
│   └── (otros perfiles...)
└── logs\
    └── install_YYYY-MM-DD_HHmmss.log
```

---

## Perfiles de instalacion disponibles

Los perfiles son archivos XML ubicados en la carpeta xml\. El script los detecta automaticamente al ejecutarse; agregar un nuevo XML es suficiente para que aparezca en el menu. Cada perfil muestra su descripcion en el menu de seleccion.

### Microsoft 365 Apps for Enterprise (M365)

Licencia por suscripcion. Requiere cuenta Microsoft 365 activa. Siempre actualizada con las ultimas funciones.

| Archivo | Aplicaciones incluidas | Estado |
|---|---|---|
| configuracion01.xml | Word, Excel, PowerPoint | Disponible |
| configuracion02.xml | Word, Excel, PowerPoint, Outlook | Disponible |
| configuracion03.xml | Word, Excel | Disponible |

### Office LTSC Standard 2024

Licencia perpetua. No requiere conexion continua. Funciones congeladas al momento de la compra; solo recibe actualizaciones de seguridad.

| Archivo | Aplicaciones incluidas | Estado |
|---|---|---|
| configuracion04.xml | Word, Excel, PowerPoint | Disponible |
| configuracion05.xml | Word, Excel, PowerPoint, Outlook | Disponible |
| configuracion06.xml | Word, Excel | Disponible |

---

## Generacion de XMLs personalizados

Los XMLs se generan desde la herramienta oficial de Microsoft: Office Customization Tool (OCT).

### Paso 1 - Acceder a la herramienta

Ir a https://config.office.com e iniciar sesion con una cuenta Microsoft (puede ser cualquier cuenta, no requiere licencia).

### Paso 2 - Crear nueva configuracion

Hacer clic en Crear y seleccionar el tipo de suite:

- Microsoft 365 Apps for Enterprise: para instalaciones con suscripcion M365
- Office LTSC Standard 2024: para licencias perpetuas

### Paso 3 - Seleccionar aplicaciones

En la seccion Aplicaciones, activar o desactivar el interruptor de cada app:

| ID en XML | Aplicacion | Notas |
|---|---|---|
| Access | Microsoft Access | Base de datos |
| Groove | OneDrive for Business | Sincronizacion |
| Lync | Skype for Business | Comunicacion (legacy) |
| OneDrive | OneDrive | Almacenamiento en nube |
| OneNote | OneNote | Bloc de notas |
| Outlook | Outlook clasico | Cliente de correo |
| OutlookForWindows | Nuevo Outlook | Cliente de correo moderno |
| PowerPoint | PowerPoint | Presentaciones |
| Publisher | Publisher | Maquetacion (en retiro) |
| Teams | Microsoft Teams | Comunicacion y reuniones |
| Word | Word | Procesador de texto |
| Excel | Excel | Planillas de calculo |

La logica del XML es de exclusion: las aplicaciones que NO aparecen en ExcludeApp se instalan.

### Paso 4 - Configurar opciones adicionales

- Arquitectura: 64 bits (recomendado para todos los equipos modernos)
- Canal de actualizacion: Current (M365)
- Idioma: Espanol (Espana) es-es
- Activar RemoveMSI para eliminar versiones MSI anteriores
- Activar aceptacion automatica de EULA en Display

### Paso 5 - Exportar

Hacer clic en Exportar y guardar el .xml. Copiarlo a la carpeta xml\ del script con el nombre correspondiente.

### Ejemplo de XML minimo (Word + Excel + PowerPoint, M365)

```xml
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="es-es" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="Outlook" />
      <ExcludeApp ID="OutlookForWindows" />
      <ExcludeApp ID="Publisher" />
      <ExcludeApp ID="Teams" />
    </Product>
  </Add>
  <RemoveMSI />
  <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
```

---

## Uso

1. Copiar la carpeta office\ completa al equipo destino.
2. Colocar el XML de instalacion deseado en la subcarpeta xml\.
3. Hacer doble clic sobre office.cmd.
4. Aceptar la elevacion de privilegios (UAC).
5. Seguir el menu interactivo.

---

## Comportamiento del script

### Paso 1 - Verificacion del ODT

Al iniciar, el script consulta la pagina oficial de Microsoft y compara el build disponible con el del ODT local. Si hay una version mas nueva, la descarga automaticamente. Si no hay ODT local, lo descarga directamente. Una vez descargado, extrae setup.exe y elimina los XMLs de muestra de Microsoft.

### Paso 2 - Deteccion de Office instalado

El script verifica si hay una instalacion de Office en el equipo via registro de Click-to-Run. Si detecta una instalacion, muestra la version, canal y productos instalados, y ofrece tres opciones:

| Opcion | Accion |
|---|---|
| 1 | Desinstalar Office (GetHelpCmd) y continuar |
| 2 | Instalar encima sin desinstalar |
| 3 | Salir |

Si no detecta ninguna instalacion, informa al tecnico y continua automaticamente.

### Desinstalacion con GetHelpCmd

Al elegir la opcion 1, el script:

1. Descarga GetHelpCmd (herramienta oficial de Microsoft) fresh desde aka.ms/SaRA_EnterpriseVersionFiles
2. Cierra todos los procesos de Office activos
3. Ejecuta la desinstalacion completa en modo desatendido
4. Monitorea el proceso en segundo plano mostrando el tiempo transcurrido
5. Elimina los archivos temporales de GetHelpCmd al finalizar

La descarga fresh en cada ejecucion evita el problema de caducidad del ejecutable (expira a los 90 dias de su compilacion).

### Paso 3 - Seleccion de configuracion

El script lee la carpeta xml\ y lista todos los .xml disponibles de forma numerada, mostrando debajo de cada uno la descripcion del perfil. El tecnico selecciona el perfil ingresando el numero correspondiente.

### Paso 4 - Menu de operaciones

| Opcion | Accion |
|---|---|
| 1 | Instalar Office directamente desde internet (CDN de Microsoft) |
| 2 | Descargar los archivos de Office para uso offline posterior |
| 3 | Instalar desde archivos offline ya descargados (requiere carpeta Office\) |
| 4 | Salir |

La opcion 2 descarga los archivos en la subcarpeta Office\. La opcion 3 instala desde esa carpeta sin necesidad de conexion.

---

## Log

Cada ejecucion genera un archivo de log independiente en:

```
office\logs\install_YYYY-MM-DD_HHmmss.log
```

| Campo | Descripcion |
|---|---|
| Fecha y hora | Timestamp de la ejecucion |
| Hostname | Nombre del equipo |
| Usuario | Dominio y usuario que ejecuto el script |
| Version ODT | FileVersion del setup.exe utilizado |
| Office detectado | Version, canal y productos de la instalacion previa |
| XML seleccionado | Nombre del perfil de instalacion elegido |
| Operacion | Modo ejecutado (instalar / descargar / offline) |
| Resultado | Confirmacion de finalizacion o error |

---

## Troubleshooting

**El script se cierra inmediatamente al ejecutar el .cmd**
Verificar que PowerShell 5.1 o superior esta disponible. En equipos con Windows 10 sin actualizar puede ser necesario actualizar PowerShell manualmente.

**"No se pudo obtener el ODT automaticamente"**
Sin conexion a internet o Microsoft bloqueo la descarga. Descargar manualmente desde https://aka.ms/odt, copiar el .exe a la misma carpeta del script y volver a ejecutar.

**"No se encontraron archivos XML en .\xml"**
La carpeta xml\ se crea sola pero debe contener al menos un .xml. Copiar el perfil deseado antes de ejecutar.

**"No se encontro la carpeta .\Office\ para instalacion offline"**
La opcion 3 requiere haber ejecutado previamente la opcion 2 desde el mismo directorio.

**La instalacion finaliza sin errores pero Office no aparece**
Revisar el log del ODT en %TEMP%\ODT\ para detalles del error. El ODT genera su propio log independiente del script.

**El ODT descargado aparece como danado o de 0 KB**
Puede haber interferido el antivirus durante la descarga. Deshabilitar temporalmente la proteccion en tiempo real, eliminar el .exe descargado y volver a ejecutar el script.

**La desinstalacion demora mas de 20 minutos**
Es normal. GetHelpCmd lanza el proceso en segundo plano y el script lo monitorea automaticamente. No cerrar la ventana ni interrumpir el proceso.

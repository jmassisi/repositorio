# ISO de Windows 11 26H2 multiedición y desatendida

*Con UUP dump, ei.cfg, autounattend.xml y modo auditoría*

**Versión 3.0.0 | 26/10/2026**

## 1. Objetivo y resultado

Generar una ISO de Windows 11 26H2 (build 26300.9807, x64, English United States) con tres ediciones: **Pro, Enterprise e IoT Enterprise**. La ISO fuerza la pantalla de selección de edición (`ei.cfg`), salta los requisitos de hardware, evita el cifrado automático de BitLocker y deja el equipo en **modo auditoría** como Administrator para configurarlo antes de entregarlo. Al finalizar, un segundo archivo de respuestas (`sysprep_oobe.xml`) lleva al equipo a un primer inicio donde se crea la cuenta local del usuario, sin cuenta de Microsoft.

**Cómo leer este instructivo:** todos los pasos están numerados de corrido (Paso 1 a Paso 31). Lo marcado **[A VERIFICAR]** no está confirmado y se detalla en la sección 7. Los archivos `autounattend.xml` y `sysprep_oobe.xml` se entregan aparte.

## 2. Resumen del flujo

| Fase | Qué se hace | Pasos |
|---|---|---|
| A | Elegir build, idioma, edición y método de descarga en UUP dump | 1 a 4 |
| B | Configurar el paquete y ejecutar la descarga y conversión | 5 a 9 |
| C | Verificar las ediciones y agregar `ei.cfg` y los XML a la imagen | 10 a 15 |
| D | Instalar el ADK y crear la ISO con `oscdimg` | 16 a 20 |
| E | Instalar Windows (con Ventoy) y configurar en modo auditoría | 21 a 25 |
| F | Pasar al usuario final con sysprep, el primer inicio (OOBE) y el nombre del equipo | 26 a 31 |

## 3. Requisitos

| Requisito | Detalle |
|---|---|
| Sistema para convertir | Windows 10 versión 2004 o superior, o Windows 11. UUP dump no convierte en otras plataformas para esta opción. |
| PowerShell | PowerShell 7 ejecutado **como administrador** (DISM y oscdimg lo requieren). |
| Espacio en disco | Descarga de unos 9,8 GB más conversión y la ISO final (8,94 GB). Se recomienda varias decenas de GB libres (estimación). |
| Windows ADK | Solo el componente **Deployment Tools**, para obtener `oscdimg` (Paso 16). |
| Ventoy | Para arrancar la ISO desde un pendrive (Paso 21). |
| Archivos propios | `ei.cfg` (Paso 12), `autounattend.xml`, `sysprep_oobe.xml`, y las modificaciones de `ConvertConfig.ini` y `CustomAppsList.txt`. |
| Aviso de UUP dump | El sitio indica que las imágenes generadas son solo para evaluación y que Microsoft no da soporte sobre ellas. |

## 4. Procedimiento

### Fase A. UUP dump

**Paso 1.** Abre **uupdump.net** y elige **Windows 11, version 26H2 (26300.9807) amd64**, canal Retail. Si hay un build más nuevo, el procedimiento es el mismo.

**Paso 2.** **Choose language:** selecciona **English (United States)** y pulsa Next.

**Paso 3.** **Choose edition:** marca solo **Windows Pro** y pulsa Next. Las demás ediciones se generan en el paso siguiente.

**Paso 4.** **Summary:** en *Download method* elige **Download, add additional editions and convert to ISO**. Marca **Include updates** e **Integrate .NET Framework 3.5** (opcional). Deja sin marcar *Run component cleanup* y *Use solid (ESD) compression*. En *Select additional editions* marca **Windows Enterprise** y **Windows IoT Enterprise**. Pulsa **Create download package** y guarda el ZIP.

### Fase B. Configurar y ejecutar el paquete

**Paso 5.** Extrae el ZIP en una carpeta cuya ruta no tenga espacios (en este instructivo, `D:\ISO`).

**Paso 6.** Abre `ConvertConfig.ini` y cambia estos tres valores. El resto se deja como viene.

| Valor | Cambiar a | Motivo |
|---|---|---|
| `SkipISO` | `1` | El script no empaqueta la ISO, para poder agregar archivos antes. |
| `vSkipISO` | `1` | Lo mismo para la etapa de ediciones adicionales. |
| `CustomList` | `1` | Activa la lista de apps de `CustomAppsList.txt`. |

> Valores que ya vienen bien y no se tocan: `AddUpdates=1`, `NetFx3=1`, `Cleanup=0`, `ResetBase=0`, `wim2esd=0`, `vDeleteSource=0`, `vAutoEditions=Enterprise,IoTEnterprise`.

**Paso 7.** Abre `CustomAppsList.txt` y deja **activas** (sin `#` y sin espacio al inicio de la línea) estas 19 apps. Las demás quedan comentadas con `#`. La Herramienta Recortes (`Microsoft.ScreenSketch`) queda fuera.

```text
Microsoft.WindowsStore_8wekyb3d8bbwe
Microsoft.StorePurchaseApp_8wekyb3d8bbwe
Microsoft.SecHealthUI_8wekyb3d8bbwe
Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
Microsoft.Windows.Photos_8wekyb3d8bbwe
Microsoft.WindowsNotepad_8wekyb3d8bbwe
Microsoft.Paint_8wekyb3d8bbwe
Microsoft.WindowsTerminal_8wekyb3d8bbwe
Microsoft.WindowsCalculator_8wekyb3d8bbwe
Microsoft.WebMediaExtensions_8wekyb3d8bbwe
Microsoft.RawImageExtension_8wekyb3d8bbwe
Microsoft.HEIFImageExtension_8wekyb3d8bbwe
Microsoft.HEVCVideoExtension_8wekyb3d8bbwe
Microsoft.VP9VideoExtensions_8wekyb3d8bbwe
Microsoft.WebpImageExtension_8wekyb3d8bbwe
Microsoft.DolbyAudioExtensions_8wekyb3d8bbwe
Microsoft.AVCEncoderVideoExtension_8wekyb3d8bbwe
Microsoft.MPEG2VideoExtension_8wekyb3d8bbwe
Microsoft.AV1VideoExtension_8wekyb3d8bbwe
```

> Las primeras 9 son las aplicaciones base (Store, Seguridad de Windows, App Installer, Fotos, Bloc de notas, Paint, Terminal, Calculadora) y las 10 siguientes son los códecs de medios.

**Paso 8.** Verifica que los cambios quedaron guardados:

```powershell
Select-String -Path .\ConvertConfig.ini -Pattern 'SkipISO|CustomList'
```

> Debe mostrar `SkipISO =1`, `CustomList =1` y `vSkipISO =1`.

**Paso 9.** Ejecuta `uup_download_windows.cmd` (doble clic) y acepta el aviso de administrador. Si aparece el aviso de seguridad de `get_aria2.ps1`, elige **R** (*Run once*), siempre que el paquete lo hayas bajado tú de uupdump.net. Deja la ventana abierta hasta el final: descarga (unos 9,8 GB) y conversión.

> Al terminar no se crea `ISOFOLDER` ni un `.iso`: el script deja una carpeta con nombre largo, del tipo `26300.9807.xxxxxx.26H2_GE_RELEASE_SVC_PROD3_CLIENTMULTI_X64FRE_EN-US`, que contiene la imagen lista para empaquetar.

### Fase C. Verificar y agregar archivos

**Paso 10.** Abre PowerShell 7 **como administrador** y define la carpeta de trabajo. La variable `$src` se pierde al cerrar la ventana: si la cierras, repite este paso.

```powershell
$iso = Get-ChildItem D:\ISO -Directory -Filter '26300*' | Select-Object -First 1
$src = $iso.FullName
$src
```

**Paso 11.** Verifica que la imagen tenga las tres ediciones:

```powershell
dism /Get-WimInfo /WimFile:"$src\sources\install.wim"
```

> Deben aparecer Windows 11 Pro (índice 1), Enterprise (2) e IoT Enterprise (3). Si falta alguna, no sigas.

**Paso 12.** Crea `ei.cfg` en la carpeta `sources`. Con `[EditionID]` vacío, el instalador muestra el selector con las ediciones de la imagen. No se escriben nombres de ediciones: con una edición escrita, el instalador la instalaría directamente.

```powershell
@"
[EditionID]

[Channel]
Retail

[VL]
0
"@ | Set-Content -Path "$src\sources\ei.cfg" -Encoding ascii
```

> El cierre `"@` debe ir al inicio de la línea, sin espacios.

**Paso 13.** Copia `autounattend.xml` en la **raíz** de la carpeta (junto a `setup.exe`), con ese nombre exacto. Ajusta la ruta de origen a donde lo guardaste.

```powershell
Copy-Item "C:\ruta\autounattend.xml" "$src\autounattend.xml"
```

**Paso 14.** *(Opcional)* Copia `sysprep_oobe.xml` a `sources\$OEM$\$1`, para que Setup lo deje en `C:\` al instalar.

```powershell
New-Item -ItemType Directory -Force -Path "$src\sources\`$OEM`$\`$1" | Out-Null
Copy-Item "C:\ruta\sysprep_oobe.xml" "$src\sources\`$OEM`$\`$1\sysprep_oobe.xml"
Test-Path "$src\sources\`$OEM`$\`$1\sysprep_oobe.xml"
```

> Debe mostrar `True`. Si prefieres no usar `$OEM$`, llévalo aparte y cópialo a `C:\` en el Paso 27.

**Paso 15.** Verifica los tres archivos:

```powershell
Get-Content "$src\sources\ei.cfg"
Select-String -Path "$src\autounattend.xml" `
  -Pattern 'PreventDeviceEncryption|Reseal|BypassTPMCheck' |
  Select LineNumber, Line
Get-ChildItem $src | Select Name
```

> Deben aparecer las tres búsquedas del XML (si falta `PreventDeviceEncryption`, copiaste una versión anterior) y `autounattend.xml` en la raíz.

### Fase D. Crear la ISO

**Paso 16.** **Instala el Windows ADK** (solo si el Paso 17 da `False` en `oscdimg`). Descarga el ADK desde `learn.microsoft.com/windows-hardware/get-started/adk-install` (no hace falta el complemento de Windows PE). Ejecuta `adksetup.exe`, deja la ruta por defecto (`C:\Program Files (x86)\Windows Kits\10\`) y, en la lista de componentes, deja marcado **solo Deployment Tools**. Instala y, al terminar, cierra PowerShell y abre una nueva como administrador (repite el Paso 10).

> El ADK no agrega `oscdimg` al PATH, por eso el Paso 17 usa la ruta completa.

**Paso 17.** Comprueba `oscdimg` y los archivos de arranque:

```powershell
$osc = (Get-Command oscdimg -ErrorAction SilentlyContinue).Source
$kit = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit"
if (-not $osc) { $osc = "$kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe" }
$osc
Test-Path $osc
Test-Path "$src\boot\etfsboot.com"
Test-Path "$src\efi\microsoft\boot\efisys.bin"
```

> Debe mostrar la ruta de `oscdimg.exe` y tres `True`.

**Paso 18.** Comprueba el espacio libre en `D:` (la ISO pesa unos 9 GB):

```powershell
[math]::Round((Get-PSDrive D).Free/1GB,1)
```

> Debe ser mayor que 12.

**Paso 19.** Crea la ISO. El comando se escribe en un `.cmd` para evitar problemas de comillas con `-bootdata`, que conserva el arranque dual BIOS y UEFI.

```powershell
$out = "D:\Win11_26H2_26300.9807.iso"
$boot = "2#p0,e,b`"$src\boot\etfsboot.com`"#pEF,e,b`"$src\efi\microsoft\boot\efisys.bin`""
$cmd = "`"$osc`" -m -o -u2 -udfver102 -lWIN11_26H2 -bootdata:$boot `"$src`" `"$out`""
Set-Content D:\ISO\build_iso.cmd $cmd -Encoding ascii
cmd /c D:\ISO\build_iso.cmd
```

> Tarda unos minutos y muestra un porcentaje. No lo interrumpas.

**Paso 20.** Comprueba que la ISO existe y su tamaño:

```powershell
Get-Item $out | Select Name, @{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

> En la prueba realizada, la ISO quedó en 8,94 GB.

### Fase E. Instalar y configurar en modo auditoría

**Paso 21.** Prepara el pendrive con **Ventoy** y copia la ISO (`Win11_26H2_26300.9807.iso`) al pendrive como un archivo más, sin modificarla. Arranca el equipo desde el pendrive y elige la ISO en el menú de Ventoy. El `autounattend.xml` va dentro de la ISO, así que no hay que copiarlo al pendrive. En una máquina virtual, conecta la ISO directamente como DVD (generación 2 / UEFI, 4 GB de RAM o más, disco de 64 GB o más; sin TPM y con Secure Boot desactivado si quieres probar el salto de requisitos **[A VERIFICAR]**).

> Rufus no forma parte de este procedimiento: se decidió usar Ventoy. Los ajustes de Ventoy que hicieron falta (modo de arranque, Secure Boot) no se registraron. **[A VERIFICAR]**

**Paso 22.** En el instalador: elige idioma y teclado; en la pantalla de clave elige **No tengo una clave**; aparece el **selector con Pro, Enterprise e IoT Enterprise**; elige la edición, acepta la licencia y elige *Custom: Install Windows only* en el disco. La licencia y el disco no se automatizan a propósito: así no se pierde el selector.

**Paso 23.** Al terminar, el equipo arranca solo en **modo auditoría** como Administrator, sin pedir cuenta, y aparece la ventana *Herramienta de preparación del sistema (Sysprep)*. Pulsa **Cancelar**. **No pulses Aceptar**: esa ventana no usa `sysprep_oobe.xml` y reiniciaría el equipo sin ocultar la cuenta de Microsoft, el Wi-Fi ni la privacidad.

> La ventana **reaparece en cada reinicio** en modo auditoría (observado): vuelve a pulsar Cancelar cada vez.

**Paso 24.** Configura el equipo, pero solo lo que sobrevive al paso al usuario (ver la tabla de la sección 5): actualizaciones de Windows, programas instalados para todos los usuarios, controladores y ajustes de equipo. **No pongas aquí el nombre del equipo** (no se conserva; se pone en el Paso 30), **no actualices apps de la Microsoft Store** y no personalices el escritorio: se pierde (sección 5).

**Paso 25.** Comprueba el estado de BitLocker (PowerShell como administrador):

```powershell
manage-bde -status C:
```

> En la prueba realizada apareció *Estado de conversión: Descifrado completo* y *Protección desactivada*.

### Fase F. Pasar al usuario final

**Paso 26.** *(Máquina virtual)* crea un punto de control antes de continuar, para poder repetir el OOBE sin reinstalar. En un equipo físico omite este paso.

**Paso 27.** Comprueba que el XML llegó a `C:\` y limpia los archivos de respuesta de la instalación, para que el equipo no vuelva a auditoría:

```powershell
Test-Path C:\sysprep_oobe.xml
Remove-Item C:\Windows\Panther\unattend.xml -ErrorAction SilentlyContinue
Remove-Item C:\Windows\Panther\unattend\unattend.xml -ErrorAction SilentlyContinue
```

> `Test-Path` debe mostrar `True`. Si muestra `False`, copia `sysprep_oobe.xml` a `C:\` a mano. Que el borrado sea necesario es **[A VERIFICAR]** (P10).

**Paso 28.** Cancela la ventana gráfica de Sysprep si está abierta y ejecuta Sysprep **desde la consola**, con el archivo de respuestas:

```powershell
C:\Windows\System32\Sysprep\sysprep.exe /oobe /shutdown /unattend:C:\sysprep_oobe.xml
```

> Sin `/generalize` se conservan la activación y los controladores. El equipo se apaga al terminar.

**Paso 29.** Enciende el equipo. El primer inicio (OOBE) muestra, en la prueba realizada: **idioma o región** (opciones US y Español México; para Argentina se elige Español México, porque la variante argentina es una máscara de la mexicana), **acuerdo de licencia** (se acepta), **usuario local** y **contraseña** (opcional). Si algo falla, **Ctrl+Shift+F3** en cualquier pantalla del OOBE vuelve al modo auditoría sin reinstalar.

> Con la contraseña vacía, la cuenta no sirve para conexiones por red y cualquiera que encienda el equipo entra directo. Si el usuario final la creará después, se deja vacía; si es tu equipo, conviene ponerla.

**Paso 30.** **Pon el nombre del equipo.** El nombre puesto en auditoría no se conserva al salir del OOBE (observado), así que hay que escribirlo de nuevo con el usuario nuevo. Desde Configuración, en Sistema, en el apartado *Acerca de* (o *Información*), o por PowerShell como administrador:

```powershell
Rename-Computer -NewName NOMBRE_DEL_EQUIPO -Restart
```

> El comando reinicia el equipo: guarda antes lo que tengas abierto. En este procedimiento el nombre se puso de forma manual; el comando es una alternativa que no se probó aquí.

**Paso 31.** Ya con el usuario nuevo, comprueba BitLocker otra vez y actualiza las apps de la Store (hay que repetirlo para este usuario):

```powershell
manage-bde -status C:
```

> Resultado informado: BitLocker **no se activó**. Interpretación: el cifrado automático no arrancó (no se registró en qué equipos se comprobó).

## 5. Qué se conserva al pasar al usuario

Con `sysprep /oobe` sin `/generalize`, lo que es del equipo se conserva y lo que es del usuario hay que repetirlo. Es el comportamiento habitual de Windows, no una lista oficial de Microsoft. Las excepciones observadas están marcadas.

| Se conserva (es del equipo) | Hay que repetirlo |
|---|---|
| Actualizaciones de Windows | **Nombre del equipo** (observado: no se conserva) |
| Programas instalados para todos los usuarios | **Apps de la Microsoft Store** (observado: hay que actualizarlas otra vez) |
| Controladores | Fondo de pantalla y tema |
| Plan de energía y ajustes de HKLM | Barra de tareas y menú Inicio |
| Activación de Windows | Aplicaciones predeterminadas |
| Accesos directos del escritorio público | Opciones del Explorador de archivos |
| Zona horaria (fijada por el XML; no se verificó tras el OOBE) **[A VERIFICAR]** | Navegador: favoritos y extensiones |
| | Programas instalados solo para el usuario |
| | Archivos de `C:\Users\Administrator` |

Pendiente para laboratorio aparte: **CopyProfile** con **sysprep /generalize** permitiría pasar ajustes de usuario al perfil base. No se ha probado en el build 26300 ni se sabe cómo afecta a la activación; no forma parte de este procedimiento.

## 6. Qué hace cada XML y qué tan oficial es

### autounattend.xml (va en la raíz de la ISO)

| Bloque | Qué hace | Origen |
|---|---|---|
| windowsPE: LabConfig (5 valores de registro) | Salta TPM, arranque seguro, RAM, CPU y disco | **No oficial.** [A VERIFICAR] (P1) |
| specialize: TimeZone | Zona horaria Argentina Standard Time | Oficial |
| specialize: PreventDeviceEncryption | Evita el cifrado automático de dispositivo | Oficial (documentado para Windows 8.1). En la prueba, BitLocker no se activó |
| specialize: `reg add` PreventDeviceEncryption | Mismo objetivo, por registro | **No oficial** (fuentes de la comunidad) |
| oobeSystem: Reseal, Mode Audit | Arranca en modo auditoría como Administrator | Oficial |

No lleva clave de producto, elección de imagen, particiones ni idioma de Setup: así el instalador sigue preguntando idioma y teclado, la edición (por `ei.cfg`) y el disco.

### sysprep_oobe.xml (se usa en el Paso 28)

| Ajuste | Qué hace | Origen |
|---|---|---|
| `UserLocale es-AR` | Formato regional de Argentina (el teclado queda sin definir) | Oficial |
| `HideOnlineAccountScreens` | Oculta el inicio de sesión de Microsoft; deja la cuenta local | Oficial. Microsoft ha cerrado otros atajos de cuenta local. [A VERIFICAR] (P2) |
| `HideWirelessSetupInOOBE` | Oculta la pantalla de Wi-Fi | Oficial. [A VERIFICAR] (P2) |
| `ProtectYourPC = 3` | Oculta la pantalla de privacidad con valores desactivados | Oficial (valores documentados para versiones anteriores). [A VERIFICAR] (P2) |
| `HideEULAPage` (comentado) | Ocultaría la licencia del OOBE | Oficial, pero Microsoft lo limita a pruebas previas al envío. Desactivado (P12) |

## 7. Estado de verificación

### Observado

| Elemento | Resultado |
|---|---|
| Ediciones en `install.wim` | Pro, Enterprise e IoT Enterprise (comprobado con DISM) |
| `SkipISO` y `vSkipISO` en 1 | El script deja la carpeta de nombre largo y no crea ISO |
| ISO con `oscdimg` | Creada, 8,94 GB |
| `$OEM$\$1` | `sysprep_oobe.xml` llegó a `C:\` |
| Selector de ediciones del instalador | **Muestra Pro, Enterprise e IoT Enterprise** (`ei.cfg` confirmado) |
| Equipos donde se instaló | Intel i5 de 6.ª generación, Intel i7 de 8.ª generación y AMD Ryzen AI 9 HX 370 |
| Primer arranque | Modo auditoría como Administrator, sin crear cuenta; ventana Sysprep al entrar |
| Ventana Sysprep en auditoría | **Reaparece en cada reinicio** |
| BitLocker en modo auditoría | Descifrado completo, protección desactivada |
| sysprep con el XML | `/oobe /shutdown /unattend` apagó el equipo |
| OOBE | Preguntó idioma o región, licencia, usuario local y contraseña; después el equipo llegó al escritorio del usuario nuevo (no volvió a auditoría) |
| BitLocker después del OOBE | **No se activó** |
| Nombre del equipo | **No se conserva** al salir de auditoría; se pone de nuevo a mano (Paso 30) |
| Apps de la Store | Las actualizadas en auditoría hay que actualizarlas otra vez con el usuario nuevo |
| Ediciones probadas de punta a punta | **Solo IoT Enterprise** |
| Herramienta para el pendrive | Se usa **Ventoy**; Rufus queda fuera |

### Pendiente de verificar

| N° | Elemento | Qué falta |
|---|---|---|
| P1 | Salto de requisitos (`LabConfig`) | Instalar en el i5 de 6.ª y en el i3 de 4.ª (fuera de la lista oficial) y anotar si el instalador mostró algún aviso |
| P2 | Wi-Fi, cuenta de Microsoft y privacidad en el OOBE | No se informaron en la prueba; confirmar que no aparecen |
| P3 | Apps instaladas | Con el usuario nuevo: `Get-AppxPackage -AllUsers \| Select Name \| Sort Name`. Deben estar las 9 base y los 10 códecs, y ninguna de las excluidas |
| P5 | Pantalla de teclado en el OOBE | Confirmar si aparece aparte de la de idioma o región, y si se pueden elegir los tres teclados (Español México, Español España y US Internacional) |
| P8 | Pro y Enterprise | Repetir el flujo completo; solo se probó IoT Enterprise |
| P9 | Equipo Intel i3 de 4.ª generación | Hacer el flujo completo |
| P10 | Borrado de `unattend.xml` (Paso 27) | Confirmar si hace falta en este build |
| P11 | Preguntas de seguridad | Anotar si el OOBE las pide al poner contraseña |
| P12 | `HideEULAPage` | Decisión: dejar la licencia manual (como está) o activarla pese a la limitación de Microsoft |
| P13 | Ajustes de Ventoy | Registrar si hizo falta algún ajuste (modo de arranque, Secure Boot) |
| — | `CopyProfile` con `/generalize` | Laboratorio aparte |

## 8. Problemas frecuentes

| Situación | Causa o solución |
|---|---|
| DISM da error 740 | La ventana de PowerShell no es de administrador. |
| DISM da error 3 o 2 | Ruta incorrecta: la carpeta no se llama `ISOFOLDER`, o el archivo es `install.esd` en vez de `install.wim`. |
| `oscdimg` no aparece | El ADK no lo agrega al PATH; usa la ruta completa (Paso 17) o instala Deployment Tools (Paso 16). |
| No aparece el selector de ediciones | `install.wim` con una sola edición, `ei.cfg` con extensión `.txt` o fuera de `sources`, o `autounattend.xml`/`pid.txt` con clave o imagen definidas. |
| El equipo vuelve a auditoría tras sysprep | Quedó un `unattend.xml` con Reseal en Audit (Paso 27) o se usó la ventana gráfica. |
| La ISO no arranca | Faltaron los parámetros `-bootdata` de `oscdimg`. |
| Aviso de seguridad en `get_aria2.ps1` | Es normal en archivos descargados; elegir R (*Run once*) si el paquete es de uupdump.net. |
| El nombre del equipo desaparece | Es lo esperado: no se conserva al salir de auditoría (Paso 30). |

## Historial de versiones

| Versión | Fecha | Cambios |
|---|---|---|
| 1.0.0 | 17/10/2026 | Primera versión: inyectar `ei.cfg` con UUP dump y `oscdimg`, alternativa con USB y problemas frecuentes. |
| 1.0.1 | 17/10/2026 | Se aplican las reglas de versionado (encabezado, pie, historial y nombre de archivo) y se corrigen los acentos. |
| 2.0.0 | 25/10/2026 | Cambia el procedimiento: UUP dump con ediciones adicionales (Enterprise, IoT Enterprise), `CustomAppsList`, `autounattend.xml`, modo auditoría y sysprep con `sysprep_oobe.xml`; pasos numerados de corrido; estado de verificación. |
| 3.0.0 | 26/10/2026 | Cambia el procedimiento: se usa Ventoy en lugar de Rufus y el nombre del equipo se pone después del OOBE (Paso 30), porque no se conserva. Se confirman el selector de ediciones y que BitLocker no se activa; se registra que la ventana de Sysprep reaparece en cada reinicio. El documento pasa a formato Markdown. |

---

*Instructivo ISO Windows 11 26H2 | v3.0.0*

# AGENTS.md — repositorio (Toolkit Técnico iGeek)

Contexto y convenciones específicas de **este** repo. Se combina con el `AGENTS.md` global de `~/.config/opencode/` (que define cómo se trabaja: main sagrado, modo plan + OK, Bitwarden, backups, etc.).

## Qué es este repo

Toolkit para soporte técnico Windows. Los agentes/operadores lo usan para crear y mantener un elemento (una utilidad) siguiendo la estructura y convenciones de abajo.

> El repo es la capa **pública** (GitHub) del toolkit: se clona en equipos cliente y se despliega en `C:\repositorio`. **No debe contener URLs, servidores ni datos propios de iGeek** (eso vive en la capa privada de Drive; ver `~/notas/arquitectura.md`).

## Estructura de cada elemento

Cada utilidad vive en su propia carpeta con la misma forma:

```
<elemento>/
├── docs/            ← documentación específica del elemento (.md)
├── logs/            ← logs en runtime (solo .gitkeep versionado)
└── scripts/         ← <script-principal>.ps1 + <script-principal>.cmd
```

Elementos existentes: `anydesk`, `defprof`, `glpi`, `office`, `sysinternals`, `winget`, `zabbix`, `registro` (tweaks .reg), `scripts/sistema`, `scripts/drivers`.

## Convenciones

- **Nombres**: todo en minúsculas, sin espacios, guión medio como separador.
- **Documentación**: solo `.md`. Los `.pdf`/`.html`/`.docx` están **deprecados** (decisión 2026-09-08) y viven solo en Drive. Cada elemento nuevo lleva su `docs/<elemento>.md`.
- **Scripts**: cada `.ps1` con su `.cmd` lanzador que eleva privilegios y bypasea ExecutionPolicy sin cambiarla globalmente.
- **Logs**: siempre en `C:\repositorio\<elemento>\logs\`, con timestamp `<nombre>_YYYY-MM-DD_HHmmss.log`.
- **Shell objetivo**: los scripts se ejecutan vía **Windows PowerShell 5.1** (los `.cmd` lanzadores invocan `powershell`). **Decisión 2026-09-09: NO migrar a pwsh.** No asumir compatibilidad con PowerShell 7/6 (`ConvertFrom-Json` rompe en silencio con 5.1 si no se normaliza el resultado a array). El usuario corre los scripts desde la PC cliente con este flujo.
- **Límite del repo**: agnóstico — sin credenciales, sin datos de clientes, sin infraestructura iGeek.

## Convenciones de scripts (obligatorias para todo elemento)

- **Idempotencia / verificación previa**: el script debe **verificar si el objetivo ya está cumplido** (binario bajado, app instalada, tweak aplicado) **antes** de ejecutar. Si ya está, avisarlo y ofrecer continuar/re-hacer con confirmación explícita (`Read-Host "Re-hacer? (S/N)"`), no ejecutar a ciegas.
- **Resultado final visible**: al terminar, el script debe dejar **registro claro de qué hizo y dónde quedó** (path del binario/instalación), no solo "listo". Si hay un siguiente paso de verificación para el operador, mostrarlo. Ej.: "Autologon instalado en: C:\...\Autologon64.exe | Abrir ahora? (S/N)".
- **Pausa final**: terminar con `Read-Host`/`pause` para que el resultado quede en pantalla antes de volver al menú (el menú hace `Clear-Host` al volver).
- **Origen**: marcado por el usuario 2026-09-09 sobre `sysinternals/scripts/autologon-install.ps1` (descargaba sin verificar y no dejaba registro del resultado). Aplicar a todos los elementos existentes y futuros.

## Git / flujo de trabajo

- `main` es sagrado: **no se trabaja en main**.
- Toda tarea en rama descriptiva: `feat/descripcion`, `fix/descripcion`, `chore/descripcion`, `docs/descripcion`.
- `git commit` y `git push` solo después del OK explícito del usuario; **merge a `main` solo con OK explícito** (el push a rama pide confirmación vía permisos).
- Los commits de la sesión que se probaron en la PC del usuario (manual, sin git) se pueden mergear con su OK.
- **Siempre hacer push de la rama** antes de pedir que se use en otro lado.
- El usuario no tiene git en la PC cliente: si un archivo nuevo de la rama debe llegar ahí, entregarlo por GitHub raw o scp (host por hostname, nunca por IP).

## Despliegue en cliente

- `irm repositorio.igeek.ar | iex` → descarga zip de GitHub → despliega en `C:\repositorio` (raíz, sin `.git`).
- `repositorio.ps1` limpia en el cliente: `.gitignore`, `PENDIENTES.md`. Mantener eso en mente al agregar archivos raíz.
- La verificación de "¿está al día?" es `check.ps1` comparando contra el último commit de GitHub.

## Documentación de gestión

Vive **fuera** del repo (no se despliega ni se sube):
- `~/notas/arquitectura.md`, `~/notas/chats.md`, `~/notas/reglas-proyecto.md`, `~/notas/repositorio-PENDIENTES.md`.

## Estado conocido — legado

- Workaround de alias winget **mergeado a `main`** (2026-09-09): vive ahora en `workarounds/` (ver `workarounds/docs/workarounds.md`). La decisión de su ubicación fue moverlo de `winget/scripts/` a una carpeta propia `workarounds/` para que el menú lo liste como categoría visible y no quede oculto.
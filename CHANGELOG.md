# Registro de Cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
versionado SemVer. La versión del entorno vive en el archivo `VERSION`.

## [Sin publicar]

### Agregado
* Módulo común `env.common.psm1` para los lanzadores (`launch.ps1`, `launch-vscode.ps1`): advertencia de ruta conflictiva, resolución del HOME portable desde `.env` e inyección de la sesión/toolchain en una sola fuente, con suite propia en CI.
* `configure-git.sh`: las credenciales de respaldo para otros servidores ahora se eligen entre caché temporal en memoria (expira a la hora; recomendado en compartidas) o `store` persistente en texto plano.

## [1.1.0] - 2026-08-23

### Agregado
* Plantilla física única `wezterm.lua.template` consumida por setup y lanzadores (fin de la triplicación y de la migración por regex masiva).
* Verificación activa de SHA256 sobre descargas cacheadas (VS Code / gh / WezTerm).
* `update-packages.sh`: actualización unificada de pacman + baseline desde fuente única.
* `smoke.sh` (+ wrapper `smoke.ps1`): automatización de las pruebas de aceptación A/B/C/E-local/F-check.
* `install-offline.ps1`: instalador asistido del paquete offline (tar.exe rápido, validación, `-Ejecutar`).
* Depuración lista en `nuevo-proyecto`: `.vscode/` con F5+GDB por plataforma, `.clang-format` y `.editorconfig`; Makefile con símbolos `-g`.
* `backup` / `restaurar`: respaldo y recuperación del HOME portable y manifiestos de librerías.
* Recordatorio de higiene en la ayuda cuando existe sesión activa de GitHub (equipos compartidos) y tip al configurar Git.
* `doctor --fix`: autorreparación ligera que regenera skel del HOME portable, marcadores de estado y `settings.json` base cuando falten, sin reinstalar componentes ni sobrescribir archivos del usuario.
* Flujo GitHub Classroom: comando `clonar <url>` (copia el TP a `~/proyectos` con upstream listo) y publicación opcional commit+push al final de `entregar`.
* Corrector local: comando `verificar` ejecuta los casos `tests/caso_NN.in/.out` (o `make test`) con tolerancia a espacios finales; `entregar` lo corre antes de empacar y bloquea la entrega fallida salvo confirmación explícita. `nuevo-proyecto` incluye un caso de ejemplo.
* Comando `soporte`: informe único anonimizado (doctor + versiones + estado + cola de install.log) para adjuntar en consultas al docente.
* Caché local de respuestas de la API de GitHub en `setup.ps1` (`descargas/api_cache`, vencimiento 24 h): evita el agotamiento del límite de consultas por IP en aulas con NAT compartido y permite seguir instalando con la última copia si la API cae.
* Espejo regional de pacman: durante la inicialización se mide la latencia contra candidatos (con prioridad sudamericana) y el más rápido pasa a ser el primer servidor de las listas de repositorios.
* `uv` como motor predeterminado de entornos virtuales (fallback automático a `python -m venv`); `smoke.sh` informa qué motor usó.
* CI semanal y manual sobre `windows-latest` con la cadena completa: `setup.ps1 -Yes`, smoke, empaquetado `-Compact` y roundtrip de instalación del paquete en otra carpeta.

### Cambiado
* Fase 9 de plan.md reescrita: automatizada por smoke; residual manual explícito (D/G/H/E-GUI).
* Distribución formal habilitada: licencia MIT del proyecto y CHANGELOG.
* Reintentos de descarga de componentes y selección de espejo pacman consolidados en funciones únicas, con suite de pruebas de lógica ejecutable en CI (`tests/test_windows_logic.ps1`).
* `setup.ps1` informa su compatibilidad al ejecutarse bajo PowerShell 7 (pwsh) con la recomendación de usar Windows PowerShell 5.1.

## [1.0.0] - 2026-08-22

Primera versión etiquetada tras la consolidación de las dos variantes de la plataforma.

### Windows
* Instalador desatendido (`setup.ps1`) con canal de versiones reproducible (`versions.json`, flag `-Latest`), modo no interactivo (`-Yes`), actualizaciones atómicas de VS Code/WezTerm, preflight de espacio/rutas, reintentos de descarga y pacman paralelo.
* Terminal WezTerm + MSYS2 UCRT64, VS Code portable con parcheo quirúrgico de settings.json, GitHub CLI y plantilla canónica compartida en los tres generadores de configuración.
* Empaquetado offline con poda `-Compact`, extensiones `.vsix` offline (`-ConExtensiones`) y política explícita del prefijo `local/`.
* Herramientas en consola: gestión de librerías C con manifiesto (`install-lib.sh`/`uninstall-lib.sh`), scaffolding académico (`nuevo-proyecto`, `entregar`), diagnóstico (`doctor`, `diagnose-env.sh`, `bootstrap`), configuración guiada de Git/GitHub CLI.
* Seguridad: limpieza para hosts compartidos corregida, exclusiones granulares de Defender con detección de antivirus de terceros, paquete sin datos personales.

### Linux
* Variante nativa por activación de sesión (`source linux/activate.sh`) con HOME portable y cero modificaciones al host ni permisos de administrador.
* Bootstrap solo diagnóstico, paridad de scripts (`configure-git`, `customize-terminal`, install/uninstall-lib, doctor, nuevo-proyecto, entregar, update-env) y suite propia de pruebas en CI.

### Infraestructura
* CI con PSScriptAnalyzer, shellcheck, bash -n y pruebas de la variante Linux.
* Reglas de agente unificadas en AGENTS.md; VERSION visible; CHANGELOG (este archivo).

### Pendiente conocido
* Validación completa en host Windows de la tanda reciente de cambios de PowerShell.

# Plan de Trabajo: Entorno C + Python Portable

Este documento detalla la hoja de ruta para la construcción, verificación y mantenimiento a largo plazo del entorno portable.

---

## Fase 1: Arquitectura y Diseño Base (Completado)
*   [x] **Selección de Plataforma:** MSYS2 con entorno UCRT64 (compilación nativa Windows sobre UCRT).
*   [x] **Gestión de Dependencias:** Pacman para paquetes del sistema, pip y uv para Python.
*   [x] **Mecanismo de Automatización:** Scripts de PowerShell (`setup.ps1`) para orquestar descargas y actualizaciones de forma desatendida.
*   [x] **Portabilidad Absoluta:** Aislamiento del directorio `$HOME` para evitar escritura en la máquina host.

---

## Fase 2: Scripts de Automatización e Inicialización (Completado)
*   [x] Creación de [setup.ps1](setup.ps1) con descarga dinámica via GitHub API y validación SHA256.
*   [x] Diseño de los cargadores de consola [launch.bat](launch.bat) y [launch.ps1](launch.ps1).
*   [x] Configuración de exclusiones en `.gitignore` para no subir binarios al repositorio.

---

## Fase 3: Terminal de Consola GPU WezTerm Portable (Completado)
*   [x] Descarga e instalación automatizada del archivo ZIP de WezTerm en `setup.ps1`.
*   [x] Configuración estética premium local (`wezterm.lua`) con tema Tokyo Night, tipografía JetBrains Mono y opacidad.
*   [x] Redirección y mapeo dinámico de rutas en Lua, adaptando contrabarras para prevenir fallas de escape.
*   [x] Integración de cargadores de terminal (`launch.bat` y `launch.ps1`) para iniciar WezTerm con fallback automático a consola estándar si no se encuentra instalado.

---

## Fase 4: Gestión de Editor e Integración VS Code Portable (Completado)
*   [x] Descarga automatizada del archivo ZIP oficial de VS Code en `setup.ps1`.
*   [x] Habilitación del modo portable mediante la creación del directorio `vscode/data/`.
*   [x] Configuración inicial aislada (`telemetry` inactivo, actualizaciones en modo manual, inhabilitación total de Copilot e integraciones de IA/LLM) y seteo predeterminado de terminal de integración `bash.exe` de MSYS2.
*   [x] Instalación de extensiones necesarias (`C/C++ Extension Pack` y `Python Extension`) a través del CLI de VS Code de forma automática.
*   [x] Creación de cargadores específicos [launch-vscode.bat](launch-vscode.bat) y [launch-vscode.ps1](launch-vscode.ps1) para propagar el `PATH` y variables de sesión.

---

## Fase 5: Gestor de Librerías de C desde GitHub (Completado)
*   [x] Diseño y desarrollo de [install-lib.sh](bin/install-lib.sh) para compilar e instalar librerías externas de forma desatendida dentro del prefijo portable `/ucrt64`.
*   [x] Soporte para múltiples modos de construcción:
    1. Recetas personalizadas `.portable-recipe.sh` en el repositorio.
    2. Proyectos CMake + Ninja automáticos.
    3. Makefile genéricos con fallback de copia manual de cabeceras, archivos estáticos y DLLs.
    4. Librerías puramente Header-only con copia estructurada de archivos `.h`/`.hpp`.

---

## Fase 6: Configuración de Control de Versiones e Integración GitHub CLI (Completado)
*   [x] Integración de GitHub CLI (`gh`) de manera portable descargado directamente desde sus releases oficiales en GitHub y guardado en `bin/gh.exe`.
*   [x] Diseño del script [configure-git.sh](bin/configure-git.sh) para automatizar:
    1. Firma de autoría de commits (`user.name` y `user.email`).
    2. Almacenamiento aislado de credenciales HTTPS de Git dentro del directorio portable (`home/.git-credentials`) mediante el helper `store`.
    3. Autenticación asistida para interactuar con la consola mediante GitHub CLI (`gh`).

---

## Fase 7: Empaquetamiento y Distribución Offline (Completado)
*   [x] Diseño del script [package-env.ps1](package-env.ps1) que automatiza el empaquetamiento del entorno inicializado.
*   [x] Limpieza del almacenamiento de pacman (`pacman -Scc`) integrado en el script para reducir el tamaño final en disco de la entrega.
*   [x] Aislamiento en la copia del paquete, excluyendo la base de datos de control de versiones `.git` y descargas/copias temporales del host.
*   [x] Compresión final nativa a formato ZIP distribuible (`portable-env-offline.zip`).

---

## Fase 8: Script de Limpieza en Hosts Compartidos (Completado)
*   [x] Diseño y desarrollo de [clean-shared-host.ps1](clean-shared-host.ps1) para desvincular identidades y claves personales en computadoras públicas o de terceros.
*   [x] Eliminación completa y segura del historial de comandos, llaves SSH privadas, credenciales de Git y extensiones personalizadas en VS Code.
*   [x] Reconfiguración automatizada del entorno portable a su estado predeterminado inicial posterior a la limpieza, garantizando que el siguiente usuario pueda lanzar el terminal sin dependencias corruptas o caídas por directorios faltantes.

---

## Fase 9: Pruebas de Aceptación (Automatizadas + Residual Manual)
El script [smoke.sh](bin/smoke.sh) (disponible también en `linux/bin/`) automatiza las verificaciones que no requieren interfaz gráfica ni privilegios. Ejecutalo dentro del terminal portable: compila/ejecuta C con cppcheck (**A**), valida Python/pip/uv con instalación aislada en venv del HOME portable (**B**), construye un proyecto CMake+Ninja (**C**), instala/desinstala una librería de prueba con manifiesto (**E-local**) y chequea la identidad de Git (**F-check**).

Residual manual (requiere host Windows con entorno inicializado):
*   [ ] **Prueba D:** IntelliSense de C/Python reconocido en VS Code Portable (terminal integrado UCRT64).
*   [ ] **Prueba G:** redespliegue offline completo: `package-env.ps1` → extraer en otro directorio → `launch.bat` sin internet.
*   [ ] **Prueba H:** limpieza interactiva en host compartido (`clean-shared-host.ps1`) y verificación de que no queden datos personales.
*   [ ] **Prueba E-GUI:** compilación contra una librería real instalada (`install-lib.sh davidsiaw/inih r29`) desde un proyecto del alumno.

---

## Fase 10: Optimización y Mantenimiento (En desarrollo)
*   [x] **Importación de configuración del host (opcional):** Opción para conservar (`-ImportHostConfig`) o dejar de lado la configuración del host base (SSH, Git y VS Code settings) al crear el entorno portable, sin alterar los archivos del host.
*   [x] **Asistente de Personalización de Consola:** Script `customize-terminal.ps1` y su cargador `.bat` para configurar estéticas (temas, fuentes, opacidad de WezTerm) y el banner de bienvenida de Bash, con reintentos robustos ante fallas. Se añade un banner general institucional e inmutable ("UNRN Andina - Programación 1") que precede a la personalización del estudiante.
*   [x] **Registro de logs de instalación:** Capturar toda la salida de `setup.ps1` en `install.log` para diagnóstico técnico (troubleshooting), incluyendo metadatos del sistema, usuario ejecutor y hora exacta de inicio.
*   [x] **Autocomprobación y autoactualización de scripts y entorno:** El script `setup.ps1` actualiza el repositorio (usando Git pull o descargando los scripts más nuevos de GitHub) antes de proceder con la actualización de los paquetes internos de MSYS2, VS Code y WezTerm.
*   [x] **Verificación estricta de firma SHA y detección de estado de instalación:** Se mejora la verificación de firmas SHA256 para el instalador de MSYS2 (haciendo que el script falle inmediatamente ante discrepancias o firmas inválidas en lugar de continuar). Se introduce una lógica avanzada guiada por el estado del entorno (mediante indicadores de completitud `.install_complete`, `.msys_complete`, `.vscode_complete` y `.wezterm_complete`), permitiendo que ejecuciones múltiples del script setup finalicen instalaciones previas incompletas (reusando descargas válidas) o actualicen selectivamente el entorno sin reinstalaciones destructivas (verificando versiones y redirecciones web).
*   [x] **Script de Actualización de Paquetes (Pacman):** Creación del script [update-packages.sh](bin/update-packages.sh) en `bin/` para actualizar la base de datos de pacman, actualizar los paquetes del sistema e instalar las herramientas obligatorias del entorno portable de forma unificada.
*   [x] **Script de Diagnóstico de Entorno:** Creación del script [diagnose-env.sh](bin/diagnose-env.sh) en `bin/` para diagnosticar el estado del entorno portable, las herramientas instaladas (con sus versiones correspondientes), el listado completo de paquetes de pacman y el contenido de `bin/` en un informe detallado.
*   [x] **Automatización de Descompresión:** Script [install-offline.ps1](install-offline.ps1) para asistir la instalación del ZIP distribuido: extracción acelerada (tar.exe con fallback), validación estructural, advertencia de rutas conflictivas y arranque opcional del terminal (`-Ejecutar`).
*   [x] **Actualización Unificada de Paquetes:** Script [update-packages.sh](bin/update-packages.sh) que sincroniza pacman y garantiza el baseline completo leyendo `packages-baseline.txt` (fuente única), usando la caché portable.
*   [x] **Verificador de Aceptación Automático:** [smoke.sh](bin/smoke.sh) automatiza las Pruebas A/B/C/E-local/F-check de la Fase 9 dentro del terminal portable.
*   **Estado y siguientes pasos:** el detalle vivo de mejoras implementadas y pendientes se centraliza en [mejoras-y-problemas.md](mejoras-y-problemas.md).



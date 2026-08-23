# Documentación de Scripts del Entorno Portable

Este documento provee una referencia técnica exhaustiva, script por script, detallando su funcionamiento interno, dependencias, variables asociadas y comportamiento en el entorno.

---

## 1. Scripts Principales en la Raíz

### `setup.ps1`
* **Propósito:** Automatiza la instalación inicial, reparación, actualización y empaquetado inicial de las herramientas del entorno.
* **Uso:** `powershell -File setup.ps1 [-ImportHostConfig] [-SkipUpdate] [-Yes] [-Latest]`
* **Parámetros:**
  * `-ImportHostConfig`: Si se pasa este modificador, copia la clave SSH privada, la configuración global de Git (`.gitconfig`) y el archivo `settings.json` de la instalación de VS Code del host local hacia el directorio `home/` portable.
  * `-SkipUpdate`: Saltea la fase de autodescarga e instalación de scripts actualizados de GitHub. Útil cuando se ejecuta localmente durante tareas de depuración o de actualización fuera de línea.
  * `-Yes`: Modo desatendido: acepta automáticamente todas las preguntas (actualizaciones de componentes, advertencia de ruta conflictiva). Pensado para despliegues masivos en laboratorios.
  * `-Latest`: Ignora los pines de `versions.json` e instala las últimas versiones disponibles de cada componente. Por defecto el manifiesto manda (reproducibilidad por cuatrimestre); los fallbacks también viven en el manifiesto.
* **Canal de scripts:** En instalaciones standalone, la variable `CHANNEL=<rama-o-tag>` dentro de `.env` define desde qué canal se descargan los scripts; en repos Git rige la rama local (`git pull`).
* **Funcionamiento Interno:**
  1. Valida la codificación UTF-8 con BOM y si la ruta de instalación posee espacios o caracteres no ASCII.
  2. Descarga el snapshot ZIP más reciente del repositorio de GitHub (`INGCOM-UNRN-P1/entorno`) y extrae los scripts en la raíz y carpetas de utilidad.
  3. Comprueba, descarga e inicializa el subsistema MSYS2 (`msys64/`).
  4. Ejecuta `pacman` para instalar de forma desatendida las herramientas de C (gcc, make, cmake, ninja, cppcheck, gdb, clang, doxygen) y Python 3.
  5. Descarga la versión de archivo ZIP de VS Code estable, la descomprime y crea la carpeta `vscode/data/` para habilitar el modo portable de manera nativa.
  6. Configura el archivo `settings.json` de VS Code para enlazar UCRT64 Bash como perfil por defecto.
  7. Descarga la versión de GitHub CLI (`gh`) y WezTerm y los descomprime localmente.
  8. Genera los marcadores de verificación de instalación (`.msys_complete`, `.vscode_complete`, `.wezterm_complete`).
* **Salidas:** Generación de archivos de estado y el archivo de log central `install.log`.

---

### `launch.ps1` y `launch.bat`
* **Propósito:** Lanzador unificado de la terminal portable WezTerm con todo el toolchain inyectado.
* **Funcionamiento Interno:**
  1. El archivo `.bat` es un delegador que ejecuta `powershell -File launch.ps1 %*`.
  2. El script `.ps1` calcula de forma dinámica el directorio raíz portable (`PORTABLE_ROOT`) y carga la configuración personalizada de directorio local de usuario desde `.env` (por defecto `home/`).
  3. Prepara el entorno inicializando los archivos de perfil `.bashrc` y `.bash_profile` en el HOME portable si no existen.
  4. Inyecta y exporta las variables de entorno locales de sesión (`PORTABLE_ROOT`, `HOME`, `MSYSTEM = UCRT64`, `CHERE_INVOKING = 1`, `LANG = es_AR.UTF-8`).
  5. Prepende al `PATH` de sesión las carpetas de compilación y scripts locales (`bin;msys64\ucrt64\bin;msys64\usr\bin`).
  6. Define variables específicas de compiladores de C/C++ (`CC=gcc`, `CXX=g++`, `PKG_CONFIG_PATH`, `CMAKE_PREFIX_PATH`).
  7. Sanea o genera el archivo `wezterm.lua` para asegurar que WezTerm levante MSYS2 Bash de forma nativa apuntando a las rutas dinámicas.
  8. Lanza `wezterm-gui.exe` / `wezterm.exe`. Si WezTerm no está disponible, cae de vuelta de forma segura lanzando `bash.exe` en la consola clásica de Windows para evitar bloqueos del alumno.

---

### `launch-vscode.ps1` y `launch-vscode.bat`
* **Propósito:** Lanzador de VS Code con el toolchain e integraciones de terminal configuradas.
* **Funcionamiento Interno:**
  1. El archivo `.bat` delega al cargador `.ps1` para evitar problemas sintácticos en el host.
  2. El script `.ps1` carga el directorio HOME y las variables de sesión del compilador de C y Python de forma idéntica a `launch.ps1`.
  3. Comprueba si `vscode/Code.exe` existe. En caso de no existir, muestra una ventana de error de Windows nativa.
  4. Ejecuta el proceso de VS Code pasándole los argumentos de la línea de comandos (ej: abrir una carpeta específica o archivo) sin la bandera `-NoNewWindow` para asegurar que el editor se abra de forma visible.

---

### `customize-terminal.ps1` y `customize-terminal.bat`
* **Propósito:** Script interactivo de PowerShell para personalizar WezTerm.
* **Funcionamiento Interno:**
  1. Pregunta de forma interactiva sobre la configuración estética de WezTerm.
  2. Carga los valores activos del archivo `wezterm.lua` si existe (tema, tamaño de letra, opacidad de fondo).
  3. Permite elegir esquemas de color premium predefinidos (Tokyo Night, Dracula, Gruvbox, Nord, One Half Dark).
  4. Permite elegir la tipografía, tamaño de fuente (8-24) y opacidad (transparencia de la ventana).
  5. Permite habilitar o deshabilitar la barra superior de múltiples pestañas (tabs).
  6. Escribe y regenera el archivo `wezterm.lua` mediante reintentos automáticos para evitar conflictos de bloqueo de archivos.

---

### `clean-shared-host.ps1`
* **Propósito:** Sanea credenciales, historiales y archivos temporales para seguridad en computadoras compartidas.
* **Funcionamiento Interno:**
  1. Cierra procesos abiertos del entorno (`Code.exe`, `wezterm.exe`, `bash.exe`).
  2. Borra las claves de registro del historial de ejecución de comandos de Windows (historial de Ejecutar, de PowerShell y CMD).
  3. Limpia las claves de host cargadas en el agente SSH de la computadora compartida.
  4. Borra credenciales de Git cacheadas temporalmente fuera de la carpeta portable en el sistema host.
  5. Restablece la configuración del terminal integrado del VS Code del host (si se hubieran alterado archivos globales).

---

### `package-env.ps1`
* **Propósito:** Empaqueta el entorno portable en un archivo ZIP listo para distribución offline.
* **Parámetros:**
  * `-Compact`: Poda documentación y locales no esenciales de MSYS2 en la copia a empaquetar (reduce tamaño sensiblemente).
  * `-ConExtensiones`: Descarga los `.vsix` de las extensiones instaladas (pineadas a su versión) hacia `offline-extensions/` dentro del paquete y genera `instalar-extensiones-offline.ps1`, habilitando aulas sin internet.
  * `-IncluirLibs`: Conserva el prefijo `local/` de librerías propias; por defecto se excluye para que el paquete sea neutro entre estudiantes.
* **Funcionamiento Interno:**
  1. Excluye carpetas voluminosas no necesarias para la ejecución (logs, temporales, caché de pacman en `downloads/`).
  2. Comprime de forma recursiva los directorios `msys64`, `vscode`, `wezterm`, `bin`, `docs` y los cargadores raíces.
  3. Almacena el resultado con fecha y hora en el directorio raíz.

---

---

### `desinstalar.ps1`
* **Propósito:** Eliminar por completo los componentes generados del entorno (MSYS2, VS Code, WezTerm, HOME portable, `local/`, cachés y marcadores), conservando los scripts del repositorio y la carpeta `.git`.
* **Funcionamiento:** Muestra el detalle de lo que va a borrar, pide confirmación irreversible y procede. No requiere permisos de administrador.

## 2. Scripts en el Directorio `bin/` (Agregados al PATH)

### `ayuda`
* **Propósito:** Comando de referencia rápida de herramientas Bash.
* **Funcionamiento:** Imprime un resumen de los comandos, compiladores y utilidades del PATH con formato y color en la consola de MSYS2.

### `customize-bash.sh`
* **Propósito:** Personalizar el mensaje de bienvenida y colores en la consola.
* **Funcionamiento:** Permite al alumno seleccionar temas del banner de bienvenida (Minimalista, Motivacional, Comandos rápidos, Libre o Limpio) y modificar el color de visualización del texto escribiendo las marcas correspondientes en `home/.bashrc`. Exporta y lee la variable del bloque mediante `ENVIRON` en `awk` para evitar pérdidas de secuencias de escape ANSI.

### `build-launcher.sh`
* **Propósito:** Compilar los lanzadores ejecutables de Windows a partir del código fuente.
* **Funcionamiento:** Descarga `launcher.c` y su `Makefile` si no existen y ejecuta `make` (o `mingw32-make` como fallback) o directamente GCC de UCRT64 para compilar los ejecutables `launch-vscode.exe` y `launch-wezterm.exe` en la raíz, removiendo antiguos ejecutables obsoletos. Los lanzadores re-quoten cada argumento según las reglas de línea de comandos de Windows (rutas con espacios, comillas o barras invertidas viajan como un único argumento) y esperan al proceso hijo con un tope de 10 minutos como guarda contra cuelgues.

### `install-lib.sh`
* **Propósito:** Compilar e instalar dependencias externas de C desde GitHub de forma portable.
* **Funcionamiento:** Clona el repositorio indicado en una carpeta temporal y detecta el motor de construcción o la especificación (especificación estructurada `library.spec`, receta personalizada `.portable-recipe.sh`, CMakeLists.txt o Makefile estándar). Compila de forma aislada y copia las cabeceras e instalables resultantes en el prefijo portable del entorno (`/ucrt64`).

### `configure-git.sh`
* **Propósito:** Configurar identidad de Git e iniciar sesión en GitHub CLI.
* **Funcionamiento:** Registra `user.name` y `user.email` de forma global aislada en la carpeta `home/`. Configura el helper de credenciales Git de forma portable para que comparta el inicio de sesión de `gh` con VS Code y con la consola.

### `diagnose-env.sh`
* **Propósito:** Genera reporte técnico del estado del entorno.
* **Funcionamiento:** Vuelca las versiones de gcc, make, ninja, python, git, pacman y la lista física de ejecutables locales a `diagnose.log`.

### `download-baseline.sh`
* **Propósito:** Precargar caché de pacman para instalaciones offline.
* **Funcionamiento:** Ejecuta `pacman -Sw` para descargar localmente a `descargas/pacman_cache` todos los paquetes definidos en `packages-baseline.txt` (fuente única compartida con setup.ps1).

### `nuevo-proyecto <nombre>`
* **Propósito:** Crear la estructura inicial de un proyecto de cátedra.
* **Funcionamiento:** Genera la carpeta con `main.c` (hola mundo parametrizado), `Makefile` de cátedra (`make` / `mingw32-make`, con `-g` para depurar) y `.gitignore`, validando el nombre y colisiones. Además deja la depuración lista: `.vscode/tasks.json` (compilación con Ctrl+Shift+B) y `.vscode/launch.json` (F5 compila y lanza con GDB, resolviendo el binario y el debugger según plataforma), más `.clang-format` (Shift+Alt+F) y `.editorconfig`.

### `backup [destino.zip]`
* **Propósito:** Resguardar los datos del alumno ante pérdida o corrupción del pendrive.
* **Funcionamiento:** Empaqueta el HOME portable completo (excluyendo `.cache`, `__pycache__`, `*.pyc`) junto con `.env`, `VERSION` y los manifiestos de `local/portable-libs` en `entorno-backup-<fecha>.zip`. Por defecto el ZIP se crea FUERA de la carpeta del entorno; el script recuerda guardarlo en un segundo medio.

### `restaurar [archivo.zip]`
* **Propósito:** Recuperar un respaldo de `backup`.
* **Funcionamiento:** Toma el ZIP indicado (o el más reciente disponible), pide confirmación, extrae `home/…` sobre el HOME portable actual, restaura `.env` si faltaba e informa qué librerías hay que reinstalar con `install-lib.sh` según los manifiestos recuperados.

### `verificar [directorio]`
* **Propósito:** Corrector local: autoevaluación con las pruebas de cátedra antes de la entrega.
* **Funcionamiento:** Compila el proyecto y compara la salida del binario contra los casos `tests/caso_NN.in` / `.out` (tolerando diferencias de espacios finales); si el Makefile define un objetivo `test:` tiene prioridad. Reporta cada caso con su salida esperada vs. obtenida y devuelve código de salida distinto de cero si algo falla. `nuevo-proyecto` deja un caso funcionando como ejemplo de la convención.

### `clonar <url | owner/repo> [destino]`
* **Propósito:** Flujo GitHub Classroom: clonar el trabajo práctico listo para programar.
* **Funcionamiento:** Clona la URL indicada (acepta atajo `owner/repo` de GitHub) en `$HOME/proyectos/<repo>` dentro del HOME portable, fija el upstream para que `git push` funcione sin argumentos y advierte si falta sesión de GitHub CLI para repos privados. Rechaza clonar sobre una carpeta existente.

### `entregar [directorio]`
* **Propósito:** Empaquetar el trabajo práctico para entrega.
* **Funcionamiento:** Compila el proyecto vía Makefile (validación previa a la entrega), ejecuta el corrector local si existen pruebas (`verificar`) y genera `ENTREGA_<proyecto>_<fecha>.zip` con solo fuentes, excluyendo binarios, `.o`, builds y `.git`, usando Python para máxima portabilidad. Si el TP vive en un repositorio Git con remoto, ofrece publicar los cambios con commit + push (confirmación explícita del alumno).

### `doctor [--fix]`
* **Propósito:** Verificación rápida de salud post-instalación y autorreparación ligera.
* **Funcionamiento:** Compila, enlaza y ejecuta un programa mínimo; valida make/cmake/ninja, Python, identidad de Git, sesión de gh y presencia de los directorios del entorno en el PATH. Código de salida 0 solo si no hay fallos.
* **Modo `--fix`:** regenera únicamente lo que falta, sin reinstalar componentes: el skel del HOME portable (`.bashrc`/`.bash_profile` con la variante canónica de cada plataforma), los marcadores de estado (`.msys_complete`, `.vscode_complete`, `.gh_complete`, `.wezterm_complete`, `.install_complete`, solo si el componente correspondiente existe en disco) y el `settings.json` base de VS Code. Nunca sobrescribe archivos del usuario; funciona incluso sin sesión activa resolviendo la raíz desde su propia ubicación.

### `soporte`
* **Propósito:** Estandarizar la consulta al docente con un único archivo adjunto.
* **Funcionamiento:** Genera `soporte-<fecha>.txt` en la raíz del entorno con el diagnóstico de `doctor` (sin colores), versiones de herramientas, estado de marcadores y carpetas, espacio libre y las últimas 60 líneas de `install.log`. Anonimiza automáticamente rutas del entorno, nombre de usuario, equipo e identidad de Git (reemplazados por `<entorno>`, `<usuario>`, `<equipo>`, `<nombre-git>`).

### `uninstall-lib.sh`
* **Propósito:** Desinstalar librerías registradas por `install-lib.sh`.
* **Funcionamiento:** Lee los manifiestos en `<prefijo>/portable-libs/*.files`, elimina los archivos registrados, poda directorios vacíos y reporta las librerías instaladas vía CMake/make install que solo tienen notas parciales.

### `update-packages.sh`
* **Propósito:** Actualización unificada de paquetes del entorno (MSYS2).
* **Funcionamiento:** Sincroniza la base de pacman, actualiza el sistema y garantiza el baseline completo leyendo `packages-baseline.txt`, usando `descargas/pacman_cache` como caché portátil.

### `smoke.sh`
* **Propósito:** Automatizar las pruebas de aceptación sin GUI del plan.md (A, B, C, E-local, F-check).
* **Funcionamiento:** Compila/ejecuta C y corre cppcheck; verifica python/pip/uv con instalación aislada en venv dentro del HOME portable; configura y compila un proyecto CMake+Ninja; instala/desinstala una librería fixture vía manifiesto; chequea identidad de Git. Código de salida 0 solo si no hay fallos. Existe wrapper `smoke.ps1` en la raíz para lanzarlo desde PowerShell.

### `install-offline.ps1`
* **Propósito:** Instalar el paquete `portable-env-offline.zip` en una máquina destino.
* **Funcionamiento:** Extrae con `tar.exe` (fallback Expand-Archive) al destino indicado, valida que exista `launch.bat`, advierte rutas conflictivas y opcionalmente abre el terminal (`-Ejecutar`). No requiere internet ni permisos de administrador.

---

## 3. Variante Linux (`linux/`)

Entorno por activación de sesión, sin modificaciones al host ni permisos de administrador.

### `linux/activate.sh`
* **Propósito:** Activar el entorno en la sesión actual de Bash (`source linux/activate.sh`).
* **Funcionamiento:** Resuelve el nombre del HOME portable desde `.env`, crea el skel base (`.bashrc`/`.bash_profile`), redirige `$HOME`, antepone `linux/bin` y `local/bin` al PATH (con guardia anti-duplicación) y exporta variables del toolchain hacia `local/`. Define la función `deactivate` que restaura la sesión original.

### `linux/bootstrap.sh`
* **Propósito:** Diagnóstico de dependencias del sistema.
* **Funcionamiento:** Solo lectura: detecta gestor de paquetes (apt/dnf/yum/pacman/zypper/apk), informa herramientas presentes/faltantes y sugiere comandos; nunca instala ni usa sudo. Rechaza explícitamente el modo de instalación automática eliminado.

### Scripts en `linux/bin/`
*   `configure-git.sh`: configuración guiada de Git (identidad validada, preferencias, credential helpers de gh y fallback store) aislada en el HOME portable.
*   `customize-terminal.sh`: asistente de banner de bienvenida y prompt de PS1 entre marcas en `.bashrc`.
*   `install-lib.sh`: port Linux del instalador de librerías (library.spec, recetas, CMake+Ninja o Makefiles, header-only) hacia `$PORTABLE_PREFIX` (`local/`), con manifiesto para desinstalación.
*   `uninstall-lib.sh`: desinstalador basado en manifiestos (idéntico al de Windows).
*   `ayuda`: guía rápida adaptada a la variante Linux.

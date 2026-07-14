# Documentación de Scripts del Entorno Portable

Este documento provee una referencia técnica exhaustiva, script por script, detallando su funcionamiento interno, dependencias, variables asociadas y comportamiento en el entorno.

---

## 1. Scripts Principales en la Raíz

### `setup.ps1`
* **Propósito:** Automatiza la instalación inicial, reparación, actualización y empaquetado inicial de las herramientas del entorno.
* **Uso:** `powershell -File setup.ps1 [-ImportHostConfig] [-SkipUpdate]`
* **Parámetros:**
  * `-ImportHostConfig`: Si se pasa este modificador, copia la clave SSH privada, la configuración global de Git (`.gitconfig`) y el archivo `settings.json` de la instalación de VS Code del host local hacia el directorio `home/` portable.
  * `-SkipUpdate`: Saltea la fase de autodescarga e instalación de scripts actualizados de GitHub. Útil cuando se ejecuta localmente durante tareas de depuración o de actualización fuera de línea.
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
* **Funcionamiento Interno:**
  1. Excluye carpetas voluminosas no necesarias para la ejecución (logs, temporales, caché de pacman en `downloads/`).
  2. Comprime de forma recursiva los directorios `msys64`, `vscode`, `wezterm`, `bin`, `docs` y los cargadores raíces.
  3. Almacena el resultado con fecha y hora en el directorio raíz.

---

## 2. Scripts en el Directorio `bin/` (Agregados al PATH)

### `ayuda`
* **Propósito:** Comando de referencia rápida de herramientas Bash.
* **Funcionamiento:** Imprime un resumen de los comandos, compiladores y utilidades del PATH con formato y color en la consola de MSYS2.

### `customize-bash.sh`
* **Propósito:** Personalizar el mensaje de bienvenida y colores en la consola.
* **Funcionamiento:** Permite al alumno seleccionar temas del banner de bienvenida (Minimalista, Motivacional, Comandos rápidos, Libre o Limpio) y modificar el color de visualización del texto escribiendo las marcas correspondientes en `home/.bashrc`. Exporta y lee la variable del bloque mediante `ENVIRON` en `awk` para evitar pérdidas de secuencias de escape ANSI.

### `build-launcher.sh`
* **Propósito:** Compila los lanzadores ejecutables de Windows a partir del código fuente.
* **Funcionamiento:** Descarga `launcher.c` y su `Makefile` si no existen y ejecuta `make` (o `mingw32-make` como fallback) o directamente GCC de UCRT64 para compilar los ejecutables `launch-vscode.exe` y `launch-wezterm.exe` en la raíz, removiendo antiguos ejecutables obsoletos.

### `install-lib.sh`
* **Propósito:** Compilar e instalar dependencias externas de C desde GitHub de forma portable.
* **Funcionamiento:** Clona el repositorio indicado en una carpeta temporal, detecta el motor de construcción (CMake o Makefile), compila en modo release usando el toolchain portable y copia las cabeceras e instalables dentro del directorio portable `/ucrt64`.

### `configure-git.sh`
* **Propósito:** Configurar identidad de Git e iniciar sesión en GitHub CLI.
* **Funcionamiento:** Registra `user.name` y `user.email` de forma global aislada en la carpeta `home/`. Configura el helper de credenciales Git de forma portable para que comparta el inicio de sesión de `gh` con VS Code y con la consola.

### `diagnose-env.sh`
* **Propósito:** Genera reporte técnico del estado del entorno.
* **Funcionamiento:** Vuelca las versiones de gcc, make, ninja, python, git, pacman y la lista física de ejecutables locales a `diagnose.log`.

### `download-baseline.sh`
* **Propósito:** Precargar caché de pacman para instalaciones offline.
* **Funcionamiento:** Ejecuta `pacman -Sw` para descargar localmente a `descargas/pacman_cache` todos los paquetes de compilación estándar de C y Python.

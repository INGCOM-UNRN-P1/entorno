# Entorno de Desarrollo Portable en C y Python para Windows

Entorno de desarrollo completamente autocontenido para Windows. Integra una terminal acelerada por GPU basada en WezTerm con userland Unix completo de MSYS2, el compilador GCC nativo, una distribución de Python 3 y un entorno preconfigurado de VS Code Portable.

## Componentes Principales

*   **Terminal de Consola:** WezTerm Portable (GPU-accelerated, configurado con el tema Tokyo Night y la tipografía JetBrains Mono).
*   **Userland Unix:** Bash, coreutils, grep, sed, awk, tar, git, ssh y GitHub CLI (`gh`).
*   **Compilador de C/C++:** GCC / G++ (MinGW-w64 GCC) optimizado para UCRT (Universal C Runtime).
*   **Herramientas de Construcción:** `make` (mingw32-make), `cmake`, `ninja`.
*   **Depurador:** GDB.
*   **Análisis Estático:** Cppcheck (detección de errores de código, fugas de memoria y comportamientos indefinidos).
*   **Generador de Documentación:** Doxygen (generación automática de documentación a partir de comentarios de código fuente).
*   **Lenguaje de Scripting:** Python 3 (nativo UCRT64) con `pip` y `uv` (instalador y resolvedor de paquetes de alto rendimiento).
*   **Editor de Código:** VS Code Portable (incluye extensiones de C/C++, CMake y Python, con terminal integrada configurada por defecto en UCRT64 Bash).
*   **Gestor de Paquetes:** `pacman` (nativo de MSYS2).
*   **Librerías de C Preinstaladas:** `zlib`, `openssl`, `sqlite3`, `curl`.

---

## Manuales y Documentación

En la carpeta [`docs/`](docs/) disponés de guías completas detalladas:

*   [Manual del Entorno Portable](docs/entorno.md): Arquitectura, inicialización y arranque de servicios.
*   [Casos de Uso del Entorno](docs/casos-de-uso.md): Situaciones educativas y logísticas (desarrollo offline, laboratorios públicos, consistencia de cátedra) que resuelve el proyecto.
*   [Documentación de Scripts](docs/scripts.md): Detalle técnico exhaustivo del funcionamiento interno, parámetros y comportamiento de cada script del entorno.
*   [Manual de Compilación con GCC](docs/compilacion-gcc.md): Flujo de compilación (preprocesado, compilación, ensamble, enlazado) y optimización en C.

---

## Estructura del Repositorio

El repositorio está organizado para separar las herramientas ejecutables del host de las configuraciones y scripts de inicialización:

*   [`setup.ps1`](setup.ps1): Script de PowerShell para instalar, regenerar y actualizar el entorno, VS Code y WezTerm. Al ejecutarse, actualiza automáticamente todos los scripts del entorno a la última versión (vía Git pull o descargándolos de GitHub) y luego actualiza los componentes instalados. Valida la ruta de instalación y genera el registro `install.log` para troubleshooting.
*   [`package-env.ps1`](package-env.ps1): Script de PowerShell para empaquetar el entorno completo inicializado en un archivo ZIP para distribución offline.
*   [`clean-shared-host.ps1`](clean-shared-host.ps1): Script de PowerShell para eliminar credenciales, historial de consola y configuraciones personales al trabajar en una máquina pública o compartida. Restablece VS Code a la configuración por defecto (incluyendo terminal en UCRT64 Bash).
*   [`desinstalar.ps1`](desinstalar.ps1): Elimina por completo los componentes generados del entorno (MSYS2, VS Code, WezTerm, HOME portable), conservando los scripts del repositorio.
*   [`customize-terminal.ps1`](customize-terminal.ps1): Script de PowerShell interactivo para personalizar la apariencia de la consola WezTerm (esquema de colores, tamaño de letra, opacidad del fondo y habilitar/desactivar pestañas).
*   [`customize-terminal.bat`](customize-terminal.bat): Cargador rápido CMD para lanzar el asistente de personalización de consola.
*   [`fix-antivirus.ps1`](fix-antivirus.ps1): Script de PowerShell para agregar el directorio del entorno portable a las exclusiones de Windows Defender, previniendo falsos positivos del antivirus y errores de memoria ("VirtualProtect failed with code 0x5af") durante la compilación (requiere privilegios de Administrador).
*   [`bin/install-lib.sh`](bin/install-lib.sh): Script de Bash para compilar e instalar automáticamente librerías de C desde repositorios de GitHub en tu prefijo portable `/ucrt64` (agregado al PATH).
*   [`bin/uninstall-lib.sh`](bin/uninstall-lib.sh): Desinstala librerías registradas por install-lib usando manifiestos (agregado al PATH).
*   [`bin/nuevo-proyecto`](bin/nuevo-proyecto): Crea la estructura inicial de un proyecto de cátedra lista para compilar, **con depuración F5 lista** (`.vscode/` con GDB), formato automático (`.clang-format`) y convenciones de editor (`.editorconfig`) (agregado al PATH). Soporta tres modalidades con `--tipo`: `plano` (programa simple con Makefile de cátedra: targets `debug`, `asan`, `test` y `ripley`), `tp` (despliega la plantilla modular de Trabajo Práctico) y `lib` (despliega la plantilla de biblioteca estática).
*   [`bin/ripley`](bin/ripley): Lanzador del motor de análisis de código C de la cátedra: linting AST, reglas P1, compilación con AddressSanitizer y traducción pedagógica de errores de GCC. Ejecuta el zipapp portable `bin/ripley.pyz` (descargado automáticamente por `setup.ps1` / `update-env.sh` desde los Releases de GitHub) o delega en una instalación nativa (`uv tool install git+https://github.com/INGCOM-UNRN-P1/ripley`). Comandos típicos: `ripley doctor` (diagnóstico), `ripley check .` (auditoría del proyecto).
*   [`bin/backup`](bin/backup): Respalda el HOME portable y los manifiestos de librerías en un ZIP fechado, excluyendo cachés regenerables. Guardalo fuera del pendrive.
*   [`bin/restaurar`](bin/restaurar): Restaura un respaldo de `backup` sobre el HOME portable actual e informa cómo reinstalar las librerías registradas.
*   [`bin/entregar`](bin/entregar): Compila el TP, corre las pruebas de cátedra y lo empaqueta en un ZIP de entrega excluyendo binarios y builds; en proyectos con manifiesto Ripley (`ripley.toml` / `.ripkg`) pre-valida además con `ripley check . --strict` antes de empacar (agregado al PATH).
*   [`bin/verificar`](bin/verificar): Corrector local: delega en `ripley check .` si el proyecto declara un manifiesto Ripley, o compara la salida del programa contra los casos `tests/caso_NN.in/.out` en modo clásico (agregado al PATH).
*   [`bin/doctor`](bin/doctor): Verificación rápida de salud del entorno: compila un programa mínimo y valida herramientas e identidad de Git (agregado al PATH).
*   [`bin/smoke.sh`](bin/smoke.sh): Automatiza las pruebas de aceptación sin GUI del plan (compilación C+cppcheck, Python aislado, CMake+Ninja, librerías con manifiesto). Wrapper `smoke.ps1` en la raíz.
*   [`bin/update-packages.sh`](bin/update-packages.sh): Actualiza pacman y garantiza el baseline leyendo `packages-baseline.txt` (agregado al PATH).
*   [`install-offline.ps1`](install-offline.ps1): Instala el paquete `portable-env-offline.zip` con extracción acelerada y validación estructural (sin internet ni permisos especiales).
*   [`bin/ayuda`](bin/ayuda): Script de Bash (ejecutable como comando `ayuda`) que muestra una guía de referencia rápida sobre los comandos y herramientas del entorno portable (agregado al PATH).
*   [`bin/build-launcher.sh`](bin/build-launcher.sh): Script de Bash para descargar y compilar los lanzadores ejecutables del repositorio (`.exe`) desde las fuentes de GitHub (agregado al PATH).
*   [`bin/customize-bash.sh`](bin/customize-bash.sh): Script de Bash interactivo para personalizar el entorno de Bash y su mensaje de bienvenida, ofreciendo varias plantillas y sugerencias (agregado al PATH).
*   [`bin/update-env.sh`](bin/update-env.sh): Script de Bash para actualizar los scripts del entorno desde el repositorio de GitHub y opcionalmente relanzar la actualización completa de herramientas nativas (agregado al PATH).
*   [`bin/configure-git.sh`](bin/configure-git.sh): Script de Bash para configurar rápidamente tu identidad de Git e iniciar sesión en GitHub CLI de forma aislada (agregado al PATH).
*   [`bin/download-baseline.sh`](bin/download-baseline.sh): Script de Bash para descargar los paquetes MSYS2 necesarios para la instalación inicial directamente a la caché local portable (agregado al PATH).
*   [`bin/diagnose-env.sh`](bin/diagnose-env.sh): Script de Bash para diagnosticar el estado del entorno portable, las herramientas instaladas (con sus versiones correspondientes), el listado completo de paquetes de pacman y el contenido de `bin/` en un informe detallado (agregado al PATH).
*   [`launch.bat`](launch.bat): Lanzador silencioso de WezTerm desde CMD.
*   [`launch.ps1`](launch.ps1): Lanzador de consola WezTerm desde PowerShell (configura la sesión en el entorno de MSYS2 UCRT64).
*   [`launch-vscode.bat`](launch-vscode.bat): Lanzador silencioso de VS Code desde CMD.
*   [`launch-vscode.ps1`](launch-vscode.ps1): Lanzador de VS Code desde PowerShell (inyecta la ruta del compilador GCC y las variables locales a la sesión).
*   [`wezterm.lua`](wezterm.lua): Configuración portable de WezTerm (apariencia, tipografía y arranque de shell Bash UCRT64).
*   [`launcher/`](launcher/): Directorio que contiene el código fuente (`launcher.c`) y un `Makefile` para compilar binarios compilados que lanzan la consola o VS Code de forma directa y silenciosa, suprimiendo la ventana negra de PowerShell intermedia.
*   [`linux/`](linux/): Variante nativa para Linux: activación de sesión (`source linux/activate.sh`), bootstrap de dependencias y scripts `bin/` portados (gestión de librerías, configuración de Git con GitHub CLI y personalización de la terminal).
*   [plan.md](plan.md): Plan de trabajo y hoja de ruta.
*   [AGENTS.md](AGENTS.md): Directrices normativas para agentes de desarrollo (commits semánticos, aislamiento del host, UCRT64). GEMINI.md se mantiene como stub de compatibilidad.
*   [versions.json](versions.json): Manifiesto de versiones por cuatrimestre (URLs pineadas de MSYS2/VS Code/gh/WezTerm y versiones de extensiones). `null` = última disponible; el flag `-Latest` lo ignora.
*   [packages-baseline.txt](packages-baseline.txt): Fuente única de paquetes pacman del entorno, compartida por setup.ps1 y download-baseline.sh.
*   VERSION: Versión actual del entorno, visible en `ayuda`, el diagnóstico y el log de instalación.
*   [mejoras-y-problemas.md](mejoras-y-problemas.md): Análisis vivo de mejoras implementadas y pendientes.
*   `home/`: Directorio local que actúa como `$HOME` del usuario. Evita contaminar la carpeta del sistema host. (Creado al inicializar).
*   `msys64/`: Carpeta contenedora de MSYS2 y binarios (excluida en `.gitignore`).
*   `vscode/`: Carpeta contenedora del editor y configuraciones locales (excluida en `.gitignore`).
*   `wezterm/`: Carpeta contenedora de la terminal WezTerm (excluida en `.gitignore`).

---

## Requisitos de Sistema

*   **Sistema Operativo:** Windows 10 (versión 1903 o superior) o Windows 11.
*   **Arquitectura:** x64.
*   **Permisos:** Permiso de ejecución de scripts de PowerShell (Execution Policy).

---

## Instalación e Inicialización (Online)

Tenés dos opciones para realizar la instalación inicial:

### Opción A: Ejecución Directa desde Internet (Recomendada)
Podés iniciar la instalación descargando y ejecutando el script de inicio directamente desde internet. Abrí PowerShell en la carpeta donde quieras instalar el entorno y ejecutá:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.ps1 | iex
```
Este script descargará el instalador principal (`setup.ps1`) con el formato correcto y te indicará cómo ejecutarlo para completar la configuración del entorno portable.

> [!NOTE]
> Una vez descargado `setup.ps1`, podrás ejecutarlo pasando los parámetros de personalización que desees directamente en tu consola local (por ejemplo: `.\setup.ps1 -HomeDirName developer -ImportHostConfig`). En ningún caso se modificarán o borrarán los archivos originales en el equipo host.

### Opción B: Descarga Manual o Clonado
1. Descargá o cloná este repositorio en el directorio donde desees conservar el entorno.
2. Abrí una terminal de PowerShell en esta carpeta y ejecutá:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup.ps1
   ```
   *Si deseás personalizar el nombre de la carpeta de configuraciones portátiles, podés pasar el parámetro `-HomeDirName`:*
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup.ps1 -HomeDirName "developer"
   ```
   *Si deseás conservar la configuración del entorno que usás como base en la máquina host (SSH, Git y settings.json de VS Code) en tu nuevo entorno portable, sumá el switch `-ImportHostConfig`:*
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup.ps1 -ImportHostConfig
   ```
   *(También podés combinar ambos parámetros: `.\setup.ps1 -HomeDirName "developer" -ImportHostConfig`)*
   *Parámetros adicionales:* `-Yes` ejecuta todo sin preguntas interactivas (ideal para laboratorios); `-Latest` ignora los pines de `versions.json` e instala las últimas versiones disponibles. Para congelar la versión de *scripts* durante el cuatrimestre, definí `CHANNEL=<tag-o-rama>` en tu `.env`.

---

## Uso Diario

Para abrir la consola interactiva o el editor con el PATH y las herramientas configuradas:

*   **Lanzar Terminal (WezTerm):** Ejecutá `launch.bat` (CMD) o `.\launch.ps1` (PowerShell).
    *   *Si por alguna razón no se encuentra WezTerm localmente, los lanzadores caerán de vuelta de forma segura iniciando la terminal Bash integrada en la consola clásica.*
*   **Lanzar VS Code:** Ejecutá `launch-vscode.bat` (CMD) o `.\launch-vscode.ps1` (PowerShell).

### Comandos de cátedra

Dentro del terminal portable también tenés utilidades pensadas para el flujo de trabajos prácticos:
```bash
nuevo-proyecto tp01     # crea tp01/ con main.c, Makefile y .gitignore
nuevo-proyecto --tipo tp tp02   # despliega la plantilla modular (libs/ + ejercicios/ + ./tp.sh)
cd tp01 && make         # compilá (o make debug / make asan)
make ripley             # auditá el proyecto con el motor de análisis
verificar               # corre las pruebas de cátedra (o ripley check . si hay manifiesto)
doctor                  # verificá que todo esté sano
entregar                # generá el ZIP de entrega validado
```

### Compilación de Lanzadores Ejecutables (`.exe`)
Para evitar depender de archivos de comandos por lotes (`.bat`) y eliminar las molestas ventanas negras parpadeantes del prompt de comandos de Windows, el entorno permite generar lanzadores ejecutables nativos de Windows (`launch.exe` y `launch-vscode.exe`). Estos ejecutables abren la terminal y el editor de manera directa y totalmente invisible en segundo plano.

Para compilar o regenerar los lanzadores nativos, iniciá tu terminal portable y ejecutá:
```bash
build-launcher.sh
```
El script compilará automáticamente los lanzadores en la raíz del entorno utilizando el compilador nativo GCC de UCRT64. A partir de ese momento, podés iniciar tus herramientas directamente usando los archivos `.exe`.

Al iniciar VS Code o WezTerm a través de cualquiera de los cargadores, heredarán el compilador GCC, Make, CMake, Ninja y Python en su variable `PATH` de sesión, habilitando la compilación directa desde la terminal integrada sin configuración adicional.

> [!TIP]
> **Traducción de VS Code al Español:**
> Por defecto, VS Code se instala en inglés. Si preferís tener la interfaz en español, podés instalar de forma muy sencilla la extensión oficial de idioma:
> 1. Abrí VS Code portable usando `launch-vscode.bat`.
> 2. Presioná `Ctrl + Shift + X` (o hacé clic en el ícono de extensiones en la barra de actividades de la izquierda).
> 3. Buscá `Spanish Language Pack for VS Code` (desarrollada por Microsoft) o instalala directamente desde: [Spanish Language Pack for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=MS-CEINTL.vscode-language-pack-es).
> 4. Hacé clic en **Install** (Instalar).
> 5. Al finalizar la instalación, se mostrará una notificación abajo a la derecha consultando si querés cambiar el idioma y reiniciar. Hacé clic en **Change Language and Restart**.

---

## Uso en Linux

El repositorio incluye una variante nativa para Linux basada en activación de sesión. **Por diseño, esta variante no modifica nada del sistema host ni requiere permisos de administrador**: la activación solo altera la sesión de terminal actual, y todo lo generado (archivos de usuario, librerías instaladas) queda dentro de la carpeta del repositorio.

Requisitos: `git`, `gcc`, `g++`, `make`, `cmake`, `ninja`, `python3`, `pip`, `curl`. El entorno no los instala; podés verificar si están presentes con:

```bash
linux/bootstrap.sh    # solo diagnóstico: sugiere comandos, nunca ejecuta instalaciones ni usa sudo
```

Para activar el entorno en tu sesión actual de Bash:

```bash
source linux/activate.sh       # activa HOME portable + toolchain en el PATH
ayuda                          # guía rápida de comandos
deactivate                     # restaura tu sesión original
```

Scripts disponibles una vez activado el entorno (en `linux/bin/`, agregados al `PATH`):

*   `configure-git.sh`: configura Git paso a paso (identidad, preferencias y credenciales) e inicia sesión con GitHub CLI (`gh`). Todo queda aislado en el HOME portable.
*   `customize-terminal.sh`: asistente para personalizar el banner de bienvenida y el prompt de Bash.
*   `install-lib.sh <usuario/repositorio> [rama_o_tag]`: compila e instala librerías de C desde GitHub en el prefijo local del entorno (`local/`), resuelto automáticamente por el compilador gracias a las variables exportadas por la activación. También acepta rutas locales a proyectos.
*   `nuevo-proyecto`, `verificar`, `entregar`, `ripley`: mismos comandos de cátedra que la variante Windows (ver [Comandos de cátedra](#comandos-de-cátedra)), incluyendo el soporte multitipo y la delegación en el motor Ripley.

---

## Personalización Estética de la Consola

Podés personalizar el mensaje de bienvenida de Bash y la apariencia visual de la terminal WezTerm (esquema de color, tamaño de fuente, opacidad del fondo y barra de pestañas) de la siguiente manera:

### 1. Personalización de la Terminal (WezTerm)
Ejecutá el asistente interactivo de WezTerm desde el sistema host:
*   **Desde CMD:** Hacé doble clic en `customize-terminal.bat` o ejecutalo desde la consola.
*   **Desde PowerShell:** Ejecutá `.\customize-terminal.ps1`.

El asistente te guiará para:
*   **Modificar la Apariencia:** Seleccionar esquemas de color premium (Tokyo Night, Dracula, Gruvbox, Nord, One Half Dark), ajustar el tamaño de la letra y configurar la opacidad del fondo (transparencia).
*   **Barra de Pestañas (Tabs):** Elegir si deseás habilitar o deshabilitar la barra superior de pestañas para trabajar con múltiples terminales en una sola ventana.

### 2. Personalización del Entorno de Bash (Mensaje de Bienvenida)
Iniciá tu terminal portable y ejecutá el siguiente script de Bash:
```bash
customize-bash.sh
```

El script te guiará para:
*   **Configurar el Banner de Bienvenida:** Elegir entre sugerencias/plantillas predefinidas (saludo minimalista con tu nombre de usuario, frases célebres de programación aleatorias, resumen de comandos útiles y rápidos) o escribir tu propia frase personalizada línea por línea (con la opción de desactivarlo por completo).
*   **Elegir el Color:** Seleccionar el color del banner (Celeste, Verde, Amarillo, Violeta, Blanco).

> [!TIP]
> El asistente de WezTerm incluye un sistema de reintentos automáticos para evitar fallos si el archivo de configuración estuviera temporalmente bloqueado por estar en uso por la terminal.

---

## Uso en Computadoras Compartidas (Limpieza de Seguridad)

Si usás este entorno en un pendrive y programás en computadoras compartidas (laboratorios, computadoras de estudio o de terceros), debés asegurar tu privacidad antes de retirar el dispositivo:

1. Cerrá VS Code y los terminales WezTerm activos.
2. Abrí una ventana de PowerShell en la carpeta raíz y ejecutá el script de limpieza:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; .\clean-shared-host.ps1
   ```
3. El script te detallará los archivos que serán eliminados. Confirmá con `s`.

*Este comando borrará tu historial de comandos, llaves SSH privadas, datos de usuario, extensiones personalizadas instaladas en VS Code y los tokens y contraseñas guardados en `.git-credentials` sin requerir que borres los compiladores ni el editor de código, dejándolos listos para que los use otro usuario de forma segura.*

---

## Distribución e Instalación Offline

Para empaquetar el entorno completo ya inicializado y distribuirlo a computadoras sin acceso a internet:

1. Inicializá el entorno de forma normal en una máquina con conexión ejecutando `setup.ps1`.
2. Una vez completado, ejecutá el script de empaquetado en PowerShell:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; .\package-env.ps1
   ```
   *Este script optimizará el espacio (vaciando la caché de pacman), copiará la estructura libre de metadatos de Git y creará el archivo comprimido `portable-env-offline.zip` en la raíz.*
   *Parámetros opcionales: `-Compact` poda documentación/locales de MSYS2; `-ConExtensiones` incluye los `.vsix` instalados con un instalador offline para aulas sin internet; `-IncluirLibs` conserva las librerías de `local/` (por defecto no viajan).*
3. Copiá el archivo `portable-env-offline.zip` a un pendrive o medio de almacenamiento.
4. En la computadora de destino **sin internet**, simplemente extraé el archivo ZIP en cualquier ruta (sin espacios ni acentos) y ejecutá directamente los lanzadores (`launch.bat` o `launch-vscode.bat`). El entorno funcionará de forma inmediata 100% offline.

---

## Configuración Inicial de Git y GitHub

Dado que el entorno es portátil y no utiliza los directorios locales del host, debés configurar tu firma de Git para esta sesión portable:

1. Ejecutá `launch.bat`.
2. Dentro del terminal, corré el comando de configuración (agregado al PATH):
   ```bash
   configure-git.sh
   ```
3. Completá tu nombre y correo. Las credenciales de acceso a repositorios HTTPS se guardarán localmente dentro de `home/.git-credentials` mediante el helper `store`. No afectarán la configuración de la máquina host.

---

## Gestión de Librerías de C desde GitHub

El entorno incluye el script `install-lib.sh` (ubicado en `bin/` y disponible en el `PATH`) para instalar librerías directamente en el entorno portátil de compilación en el prefijo `/ucrt64` desde cualquier repositorio de GitHub.

### Ejecución básica
Iniciá el terminal (`launch.bat`) y ejecutá:
```bash
install-lib.sh <usuario/repositorio_github> [rama_o_tag]
```

### Ejemplos de uso:
```bash
# Instalar Nuklear (Librería GUI Header-only)
install-lib.sh immediate-mode-ui/nuklear

# Instalar inih (Librería parser de archivos INI usando CMake)
install-lib.sh davidsiaw/inih r29

# Instalar una librería estructurada (basada en plantilla-libreria que usa library.spec)
install-lib.sh mi-usuario/mi-libreria-matematica
```

---

## Regeneración y Actualizaciones Rápidas

*   **Para actualizar todo el entorno (paquetes, VS Code y WezTerm):** Volvé a ejecutar `setup.ps1`. El script respetará tu carpeta `vscode/data` (donde se guardan tus extensiones y configuraciones) actualizando únicamente la base del editor. Los pines de `versions.json` garantizan que todos obtengan las mismas versiones dentro del cuatrimestre; usá `-Latest` para saltearlos.
*   **Para regenerar el entorno de cero:** Borrá las carpetas `msys64`, `vscode` y `wezterm` (o ejecutá `desinstalar.ps1`), resguardando `vscode/data` si querés conservar la configuración del editor, y volvé a ejecutar `setup.ps1`.

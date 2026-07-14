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

## Estructura del Repositorio

El repositorio está organizado para separar las herramientas ejecutables del host de las configuraciones y scripts de inicialización:

*   [`setup.ps1`](file:///home/mrtin/dev/p1/entorno/setup.ps1): Script de PowerShell para instalar, regenerar y actualizar el entorno, VS Code y WezTerm. Al ejecutarse, actualiza automáticamente todos los scripts del entorno a la última versión (vía Git pull o descargándolos de GitHub) y luego actualiza los componentes instalados. Valida la ruta de instalación y genera el registro `install.log` para troubleshooting.
*   [`package-env.ps1`](file:///home/mrtin/dev/p1/entorno/package-env.ps1): Script de PowerShell para empaquetar el entorno completo inicializado en un archivo ZIP para distribución offline.
*   [`clean-shared-host.ps1`](file:///home/mrtin/dev/p1/entorno/clean-shared-host.ps1): Script de PowerShell para eliminar credenciales, historial de consola y configuraciones personales al trabajar en una máquina pública o compartida. Restablece VS Code a la configuración por defecto (incluyendo terminal en UCRT64 Bash).
*   [`customize-terminal.ps1`](file:///home/mrtin/dev/p1/entorno/customize-terminal.ps1): Script de PowerShell interactivo para personalizar la apariencia de la consola WezTerm (esquema de colores, tamaño de letra, opacidad del fondo y habilitar/desactivar pestañas).
*   [`customize-terminal.bat`](file:///home/mrtin/dev/p1/entorno/customize-terminal.bat): Cargador rápido CMD para lanzar el asistente de personalización de consola.
*   [`add-defender-exclusion.ps1`](file:///home/mrtin/dev/p1/entorno/add-defender-exclusion.ps1): Script de PowerShell para agregar el directorio del entorno portable a las exclusiones de Windows Defender (requiere privilegios de Administrador).
*   [`fix-antivirus.ps1`](file:///home/mrtin/dev/p1/entorno/fix-antivirus.ps1): Script de PowerShell avanzado para agregar excepciones en Windows Defender, previniendo falsos positivos del antivirus y errores de memoria ("VirtualProtect failed with code 0x5af") durante la compilación.
*   [`bin/install-lib.sh`](file:///home/mrtin/dev/p1/entorno/bin/install-lib.sh): Script de Bash para compilar e instalar automáticamente librerías de C desde repositorios de GitHub en tu prefijo portable `/ucrt64` (agregado al PATH).
*   [`bin/build-launcher.sh`](file:///home/mrtin/dev/p1/entorno/bin/build-launcher.sh): Script de Bash para descargar y compilar los lanzadores ejecutables del repositorio (`.exe`) desde las fuentes de GitHub (agregado al PATH).
*   [`bin/customize-bash.sh`](file:///home/mrtin/dev/p1/entorno/bin/customize-bash.sh): Script de Bash interactivo para personalizar el entorno de Bash y su mensaje de bienvenida, ofreciendo varias plantillas y sugerencias (agregado al PATH).
*   [`bin/configure-git.sh`](file:///home/mrtin/dev/p1/entorno/bin/configure-git.sh): Script de Bash para configurar rápidamente tu identidad de Git e iniciar sesión en GitHub CLI de forma aislada (agregado al PATH).
*   [`bin/download-baseline.sh`](file:///home/mrtin/dev/p1/entorno/bin/download-baseline.sh): Script de Bash para descargar los paquetes MSYS2 necesarios para la instalación inicial directamente a la caché local portable (agregado al PATH).
*   [`bin/diagnose-env.sh`](file:///home/mrtin/dev/p1/entorno/bin/diagnose-env.sh): Script de Bash para diagnosticar el estado del entorno portable, las herramientas instaladas (con sus versiones correspondientes), el listado completo de paquetes de pacman y el contenido de `bin/` en un informe detallado (agregado al PATH).
*   [`launch.bat`](file:///home/mrtin/dev/p1/entorno/launch.bat): Lanzador silencioso de WezTerm desde CMD.
*   [`launch.ps1`](file:///home/mrtin/dev/p1/entorno/launch.ps1): Lanzador de consola WezTerm desde PowerShell (configura la sesión en el entorno de MSYS2 UCRT64).
*   [`launch-vscode.bat`](file:///home/mrtin/dev/p1/entorno/launch-vscode.bat): Lanzador silencioso de VS Code desde CMD.
*   [`launch-vscode.ps1`](file:///home/mrtin/dev/p1/entorno/launch-vscode.ps1): Lanzador de VS Code desde PowerShell (inyecta la ruta del compilador GCC y las variables locales a la sesión).
*   [`wezterm.lua`](file:///home/mrtin/dev/p1/entorno/wezterm.lua): Configuración portable de WezTerm (apariencia, tipografía y arranque de shell Bash UCRT64).
*   [`launcher/`](file:///home/mrtin/dev/p1/entorno/launcher/): Directorio que contiene el código fuente (`launcher.c`) y un `Makefile` para compilar binarios compilados que lanzan la consola o VS Code de forma directa y silenciosa, suprimiendo la ventana negra de PowerShell intermedia.
*   [plan.md](file:///home/mrtin/dev/p1/entorno/plan.md): Plan de trabajo y hoja de ruta.
*   [GEMINI.md](file:///home/mrtin/dev/p1/entorno/GEMINI.md): Directrices de desarrollo y reglas de formato de commits semánticos obligatorios para agentes de IA que colaboren en el proyecto.
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
Podés descargar y ejecutar el script directamente en PowerShell sin necesidad de descargar o clonar el repositorio previamente. Abrí PowerShell en la carpeta donde quieras instalar el entorno y ejecutá:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; (irm https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/setup.ps1).TrimStart([char]0xFEFF) | iex
```
*Si deseás personalizar el nombre de la carpeta de configuraciones portátiles (por defecto `home`), podés pasar el parámetro `-HomeDirName`:*
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Command -ScriptBlock ([scriptblock]::Create(((irm https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/setup.ps1).TrimStart([char]0xFEFF)))) -ArgumentList @("-HomeDirName", "developer")
```
*Si deseás importar la configuración del host base (SSH, Git y settings.json de VS Code) para conservarla como base en tu entorno portable, podés pasar el switch `-ImportHostConfig`:*
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Command -ScriptBlock ([scriptblock]::Create(((irm https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/setup.ps1).TrimStart([char]0xFEFF)))) -ArgumentList @("-HomeDirName", "home", $true)
```
> [!NOTE]
> Al omitir `$true` (o no pasar el switch), el script dejará de lado las configuraciones del host y generará un entorno portable completamente limpio. En ningún caso se modificarán o borrarán los archivos originales en el equipo host.

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

---

## Uso Diario

Para abrir la consola interactiva o el editor con el PATH y las herramientas configuradas:

*   **Lanzar Terminal (WezTerm):** Ejecutá `launch.bat` (CMD) o `.\launch.ps1` (PowerShell).
    *   *Si por alguna razón no se encuentra WezTerm localmente, los lanzadores caerán de vuelta de forma segura iniciando la terminal Bash integrada en la consola clásica.*
*   **Lanzar VS Code:** Ejecutá `launch-vscode.bat` (CMD) o `.\launch-vscode.ps1` (PowerShell).

Al iniciar VS Code o WezTerm a través de los cargadores, heredarán el compilador GCC, Make, CMake, Ninja y Python en su variable `PATH` de sesión, habilitando la compilación directa desde la terminal integrada sin configuración adicional.

---

## Personalización Estética de la Consola

Podés personalizar el mensaje de bienvenida de Bash y la apariencia visual de la terminal WezTerm (esquema de color, tamaño de fuente y opacidad del fondo) ejecutando el asistente interactivo:

*   **Desde CMD:** Hacé doble clic en `customize-terminal.bat` o ejecutalo desde consola.
*   **Desde PowerShell:** Ejecutá `.\customize-terminal.ps1`.

El asistente te guiará para:
1.  **Configurar el Banner de Bienvenida:** Elegir entre un mensaje informativo limpio predeterminado, un mensaje de texto personalizado o limpiar la consola al iniciar. También te permite seleccionar el color del banner (Celeste, Verde, Amarillo, Violeta, Blanco).
2.  **Modificar la Apariencia de WezTerm:** Seleccionar esquemas de color premium (Tokyo Night, Dracula, Gruvbox, Nord, One Half Dark), ajustar el tamaño de fuente y configurar la opacidad de fondo para lograr efectos de transparencia.

> [!TIP]
> El script incluye un sistema de reintentos automáticos para evitar fallos si el archivo de configuración estuviera temporalmente bloqueado por estar en uso por otra aplicación.

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
```

---

## Regeneración y Actualizaciones Rápidas

*   **Para actualizar todo el entorno (paquetes, VS Code y WezTerm):** Volvé a ejecutar `setup.ps1`. El script respetará tu carpeta `vscode/data` (donde se guardan tus extensiones y configuraciones) actualizando únicamente la base del editor.
*   **Para regenerar el entorno de cero:** Borrá las carpetas `msys64`, `vscode` y `wezterm` (resguardando `vscode/data` si querés conservar la configuración del editor) y ejecutá nuevamente `setup.ps1`.

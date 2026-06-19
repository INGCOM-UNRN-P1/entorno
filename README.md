# Entorno de Desarrollo Portable en C y Python para Windows

Entorno de desarrollo completamente autocontenido para Windows. Integra una terminal con userland Unix completo basado en MSYS2, el compilador Clang nativo, una distribución de Python 3 y un entorno preconfigurado de VS Code Portable.

## Componentes Principales

*   **Userland Unix:** Bash, coreutils, grep, sed, awk, tar, git, ssh.
*   **Compilador de C:** Clang (MinGW-w64 Clang64) optimizado para UCRT (Universal C Runtime).
*   **Herramientas de Construcción:** `make` (mingw32-make), `cmake`, `ninja`.
*   **Depurador:** GDB.
*   **Lenguaje de Scripting:** Python 3 (nativo Clang64) con `pip`.
*   **Editor de Código:** VS Code Portable (incluye extensiones de C/C++, CMake y Python).
*   **Gestor de Paquetes:** `pacman` (nativo de MSYS2).
*   **Librerías de C Preinstaladas:** `zlib`, `openssl`, `sqlite3`, `curl`.

---

## Estructura del Repositorio

El repositorio está organizado para separar las herramientas ejecutables del host de las configuraciones y scripts de inicialización:

*   [setup.ps1](file:///home/mrtin/dev/p1/entorno/setup.ps1): Script de PowerShell para instalar, regenerar y actualizar el entorno y VS Code.
*   [launch.bat](file:///home/mrtin/dev/p1/entorno/launch.bat): Lanzador de consola desde la línea de comandos clásica (`cmd`).
*   [launch.ps1](file:///home/mrtin/dev/p1/entorno/launch.ps1): Lanzador de consola desde PowerShell.
*   [launch-vscode.bat](file:///home/mrtin/dev/p1/entorno/launch-vscode.bat): Lanzador de VS Code desde CMD heredando las variables y compiladores locales.
*   [launch-vscode.ps1](file:///home/mrtin/dev/p1/entorno/launch-vscode.ps1): Lanzador de VS Code desde PowerShell heredando las variables locales.
*   [plan.md](file:///home/mrtin/dev/p1/entorno/plan.md): Plan de trabajo y hoja de ruta.
*   `home/`: Directorio local que actúa como `$HOME` del usuario. Evita contaminar la carpeta del sistema host. (Creado al inicializar).
*   `msys64/`: Carpeta contenedora de MSYS2 y binarios (excluida en `.gitignore`).
*   `vscode/`: Carpeta contenedora del editor y configuraciones locales (excluida en `.gitignore`).

---

## Requisitos de Sistema

*   **Sistema Operativo:** Windows 10 (versión 1903 o superior) o Windows 11.
*   **Arquitectura:** x64.
*   **Permisos:** Permiso de ejecución de scripts de PowerShell (Execution Policy).

---

## Instalación e Inicialización

1. Descargá o cloná este repositorio en el directorio donde desees conservar el entorno.
2. Abrí una terminal de PowerShell en esta carpeta y ejecutá el script de configuración:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup.ps1
   ```
   *El script descargará e instalará MSYS2, el compilador Clang, Python, y la última versión de VS Code Portable, preinstalando además las extensiones de C/C++ y Python necesarias.*

---

## Uso Diario

Para abrir la consola interactiva o el editor con el PATH y las herramientas configuradas:

*   **Lanzar Terminal:** Ejecutá `launch.bat` (CMD) o `.\launch.ps1` (PowerShell).
*   **Lanzar VS Code:** Ejecutá `launch-vscode.bat` (CMD) o `.\launch-vscode.ps1` (PowerShell).

Al iniciar VS Code a través de los lanzadores, este heredará el compilador Clang, Make, CMake y Python en su variable `PATH` de sesión, habilitando la compilación directa desde la terminal integrada sin configuración adicional.

---

## Regeneración y Actualizaciones Rápidas

*   **Para actualizar todo el entorno (paquetes y VS Code):** Volvé a ejecutar `setup.ps1`. El script respetará tu carpeta `vscode/data` (donde se guardan tus extensiones y configuraciones) actualizando únicamente la base del editor.
*   **Para regenerar el entorno de cero:** Borrá las carpetas `msys64` y `vscode` (resguardando `vscode/data` si querés conservar la configuración del editor) y ejecutá nuevamente `setup.ps1`.

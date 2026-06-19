# Entorno de Desarrollo Portable en C y Python para Windows

Entorno de desarrollo completamente autocontenido para Windows. Integra una terminal con userland Unix completo basado en MSYS2, el compilador Clang nativo y una distribución de Python 3.

## Componentes Principales

*   **Userland Unix:** Bash, coreutils, grep, sed, awk, tar, git, ssh.
*   **Compilador de C:** Clang (MinGW-w64 Clang64) optimizado para UCRT (Universal C Runtime).
*   **Herramientas de Construcción:** `make` (mingw32-make), `cmake`, `ninja`.
*   **Depurador:** GDB.
*   **Lenguaje de Scripting:** Python 3 (nativo Clang64) con `pip`.
*   **Gestor de Paquetes:** `pacman` (nativo de MSYS2).
*   **Librerías de C Preinstaladas:** `zlib`, `openssl`, `sqlite3`, `curl`.

---

## Estructura del Repositorio

El repositorio está organizado para separar las herramientas ejecutables del host de las configuraciones y scripts de inicialización:

*   [setup.ps1](file:///home/mrtin/dev/p1/entorno/setup.ps1): Script de PowerShell para instalar, regenerar y actualizar el entorno.
*   [launch.bat](file:///home/mrtin/dev/p1/entorno/launch.bat): Lanzador de consola desde la línea de comandos clásica (`cmd`).
*   [launch.ps1](file:///home/mrtin/dev/p1/entorno/launch.ps1): Lanzador de consola desde PowerShell.
*   [plan.md](file:///home/mrtin/dev/p1/entorno/plan.md): Plan de trabajo y hoja de ruta.
*   `home/`: Directorio local que actúa como `$HOME` del usuario. Evita contaminar la carpeta de usuario del sistema host. Contiene `.bashrc` y configuraciones locales. (Creado al inicializar).
*   `msys64/`: Carpeta contenedora de MSYS2 y binarios. Excluida en el control de versiones `.gitignore`.

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
   *El script descargará la última versión base de MSYS2, verificará su hash SHA256, la extraerá e instalará Clang, Python y las herramientas necesarias de forma automática.*

---

## Uso Diario

Para abrir la consola interactiva con la ruta configurada y las herramientas disponibles en el PATH:

*   **Desde CMD:** Hacé doble clic o ejecutá `launch.bat`.
*   **Desde PowerShell:** Ejecutá `.\launch.ps1`.

El entorno te ubicará por defecto en el directorio raíz de este proyecto (`CHERE_INVOKING=1`) y montará todas las configuraciones locales en la carpeta `home/` del repositorio portable.

---

## Regeneración y Actualizaciones Rápidas

*   **Para actualizar paquetes existentes:** Volvé a ejecutar `setup.ps1`. Pacman se encargará de actualizar todos los compiladores y utilidades.
*   **Para regenerar el entorno completo de cero:** Borrá la carpeta `msys64` y ejecutá nuevamente `setup.ps1`. La carpeta `home/` persistirá tus configuraciones personales (como el historial de bash o las llaves SSH).

# Plan de Trabajo: Entorno C + Python Portable

Este documento detalla la hoja de ruta para la construcción, verificación y mantenimiento a largo plazo del entorno portable.

---

## Fase 1: Arquitectura y Diseño Base (Completado)
*   [x] **Selección de Plataforma:** MSYS2 con entorno CLANG64 (compilación nativa Windows sobre UCRT).
*   [x] **Gestión de Dependencias:** Pacman para paquetes del sistema, pip y uv para Python.
*   [x] **Mecanismo de Automatización:** Scripts de PowerShell (`setup.ps1`) para orquestar descargas y actualizaciones de forma desatendida.
*   [x] **Portabilidad Absoluta:** Aislamiento del directorio `$HOME` para evitar escritura en la máquina host.

---

## Fase 2: Scripts de Automatización e Inicialización (Completado)
*   [x] Creación de [setup.ps1](file:///home/mrtin/dev/p1/entorno/setup.ps1) con descarga dinámica via GitHub API y validación SHA256.
*   [x] Diseño de los cargadores de consola [launch.bat](file:///home/mrtin/dev/p1/entorno/launch.bat) y [launch.ps1](file:///home/mrtin/dev/p1/entorno/launch.ps1).
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
*   [x] Creación de cargadores específicos [launch-vscode.bat](file:///home/mrtin/dev/p1/entorno/launch-vscode.bat) y [launch-vscode.ps1](file:///home/mrtin/dev/p1/entorno/launch-vscode.ps1) para propagar el `PATH` y variables de sesión.

---

## Fase 5: Gestor de Librerías de C desde GitHub (Completado)
*   [x] Diseño y desarrollo de [install-lib.sh](file:///home/mrtin/dev/p1/entorno/install-lib.sh) para compilar e instalar librerías externas de forma desatendida dentro del prefijo portable `/clang64`.
*   [x] Soporte para múltiples modos de construcción:
    1. Recetas personalizadas `.portable-recipe.sh` en el repositorio.
    2. Proyectos CMake + Ninja automáticos.
    3. Makefile genéricos con fallback de copia manual de cabeceras, archivos estáticos y DLLs.
    4. Librerías puramente Header-only con copia estructurada de archivos `.h`/`.hpp`.

---

## Fase 6: Configuración de Control de Versiones e Integración GitHub CLI (Completado)
*   [x] Integración del paquete `mingw-w64-clang-x86_64-github-cli` en MSYS2.
*   [x] Diseño del script [configure-git.sh](file:///home/mrtin/dev/p1/entorno/configure-git.sh) para automatizar:
    1. Firma de autoría de commits (`user.name` y `user.email`).
    2. Almacenamiento aislado de credenciales HTTPS de Git dentro del directorio portable (`home/.git-credentials`) mediante el helper `store`.
    3. Autenticación asistida para interactuar con la consola mediante GitHub CLI (`gh`).

---

## Fase 7: Empaquetamiento y Distribución Offline (Completado)
*   [x] Diseño del script [package-env.ps1](file:///home/mrtin/dev/p1/entorno/package-env.ps1) que automatiza el empaquetamiento del entorno inicializado.
*   [x] Limpieza del almacenamiento de pacman (`pacman -Scc`) integrado en el script para reducir el tamaño final en disco de la entrega.
*   [x] Aislamiento en la copia del paquete, excluyendo la base de datos de control de versiones `.git` y descargas/copias temporales del host.
*   [x] Compresión final nativa a formato ZIP distribuible (`portable-env-offline.zip`).

---

## Fase 8: Script de Limpieza en Hosts Compartidos (Completado)
*   [x] Diseño y desarrollo de [clean-shared-host.ps1](file:///home/mrtin/dev/p1/entorno/clean-shared-host.ps1) para desvincular identidades y claves personales en computadoras públicas o de terceros.
*   [x] Eliminación completa y segura del historial de comandos, llaves SSH privadas, credenciales de Git y extensiones personalizadas en VS Code.
*   [x] Reconfiguración automatizada del entorno portable a su estado predeterminado inicial posterior a la limpieza, garantizando que el siguiente usuario pueda lanzar el terminal sin dependencias corruptas o caídas por directorios faltantes.

---

## Fase 9: Pruebas de Aceptación (Pendiente de Ejecución en Host)
Para validar que el entorno cumple con los estándares exigidos, se deben realizar las siguientes pruebas manuales tras la inicialización:

### Prueba A: Compilación Clang C
*   [ ] 1. Ejecutar `launch.bat` (que iniciará WezTerm).
*   [ ] 2. Crear un archivo `test.c` con el siguiente contenido:
   ```c
   #include <stdio.h>
   int main() {
       printf("Hola desde Clang Portable UCRT!\n");
       return 0;
   }
   ```
*   [ ] 3. Compilar: `clang test.c -o test.exe`
*   [ ] 4. Ejecutar: `./test.exe`
*   [ ] 5. Verificar la salida esperada en consola.
*   [ ] 6. Realizar análisis estático de código: `cppcheck test.c`
*   [ ] 7. Verificar que cppcheck analice el archivo e informe el resultado.

### Prueba B: Ejecución de Python, Pip y UV
*   [ ] 1. Ejecutar `launch.bat`.
*   [ ] 2. Verificar versiones de herramientas:
   ```bash
   python --version
   pip --version
   uv --version
   ```
*   [ ] 3. Instalar un paquete de prueba usando uv: `uv pip install requests`
*   [ ] 4. Verificar que se instale en el HOME local (`home/.local/...`) y no en la máquina host.

### Prueba C: Sistema de Construcción (CMake)
*   [ ] 1. Crear un `CMakeLists.txt` básico.
*   [ ] 2. Generar el build con Ninja: `cmake -G Ninja .`
*   [ ] 3. Compilar con `ninja` o `cmake --build .`.

### Prueba D: Validación de VS Code Portable
*   [ ] 1. Ejecutar `launch-vscode.bat`.
*   [ ] 2. Verificar que el terminal integrado inicie directamente en `Clang64 Bash`.
*   [ ] 3. Validar que la compilación de C y Python sea reconocida desde las herramientas de autocompletado en el editor.

### Prueba E: Instalación de Librerías de GitHub
*   [ ] 1. Ejecutar `launch.bat`.
*   [ ] 2. Correr el script: `./install-lib.sh davidsiaw/inih r29`
*   [ ] 3. Verificar que los archivos `ini.h` y `libinih.a` estén instalados en `msys64/clang64/include/` y `msys64/clang64/lib/` respectivamente.
*   [ ] 4. Crear un código simple en C que incluya `<ini.h>` y verificar que compile usando `clang test_ini.c -linih -o test_ini.exe`.

### Prueba F: Configuración Git y GitHub CLI
*   [ ] 1. Ejecutar `launch.bat`.
*   [ ] 2. Correr el script: `./configure-git.sh`
*   [ ] 3. Ingresar credenciales ficticias o reales de prueba.
*   [ ] 4. Verificar la creación de los archivos `home/.gitconfig` y `home/.git-credentials`.
*   [ ] 5. Ejecutar `gh --version` para validar que el CLI de GitHub responde de forma correcta.

### Prueba G: Empaquetamiento y Despliegue Offline
*   [ ] 1. Ejecutar `package-env.ps1` en PowerShell.
*   [ ] 2. Verificar que se genere el archivo `portable-env-offline.zip`.
*   [ ] 3. Extraer el contenido del archivo ZIP en otro directorio temporal distinto en la máquina.
*   [ ] 4. Ejecutar `launch.bat` en la nueva carpeta y validar que todas las herramientas (`clang`, `python`, `git`, `gh`) sigan estando en el PATH de sesión sin requerir conexiones a internet.

### Prueba H: Limpieza de Seguridad en Hosts Compartidos
*   [ ] 1. Ejecutar `clean-shared-host.ps1` en PowerShell.
*   [ ] 2. Verificar que el script muestre la advertencia detallada y los archivos a eliminar.
*   [ ] 3. Confirmar la ejecución.
*   [ ] 4. Validar que la carpeta `home/` sea recreada vacía y que `vscode/data/` sea restablecida a las configuraciones predeterminadas.
*   [ ] 5. Confirmar que no queden contraseñas o datos personales en el directorio portable.

---

## Fase 10: Optimización y Mantenimiento (En desarrollo)
*   [x] **Importación de configuración del host (opcional):** Opción para conservar (`-ImportHostConfig`) o dejar de lado la configuración del host base (SSH, Git y VS Code settings) al crear el entorno portable, sin alterar los archivos del host.
*   [x] **Asistente de Personalización de Consola:** Script `customize-terminal.ps1` y su cargador `.bat` para configurar estéticas (temas, fuentes, opacidad de WezTerm) y el banner de bienvenida de Bash, con reintentos robustos ante fallas. Se añade un banner general institucional e inmutable ("UNRN Andina - Programación 1") que precede a la personalización del estudiante.
*   [x] **Registro de logs de instalación:** Capturar toda la salida de `setup.ps1` en `install.log` para diagnóstico técnico (troubleshooting), incluyendo metadatos del sistema, usuario ejecutor y hora exacta de inicio.
*   [x] **Autocomprobación y autoactualización de scripts y entorno:** El script `setup.ps1` actualiza el repositorio (usando Git pull o descargando los scripts más nuevos de GitHub) antes de proceder con la actualización de los paquetes internos de MSYS2, VS Code y WezTerm.
*   [ ] **Automatización de Descompresión:** Evaluación del diseño de un script ligero de PowerShell `install-offline.ps1` para asistir en la extracción rápida del ZIP distribuido.

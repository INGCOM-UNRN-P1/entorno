# Plan de Trabajo: Entorno C + Python Portable

Este documento detalla la hoja de ruta para la construcción, verificación y mantenimiento a largo plazo del entorno portable.

---

## Fase 1: Arquitectura y Diseño Base (Completado)
*   **Selección de Plataforma:** MSYS2 con entorno CLANG64 (compilación nativa Windows sobre UCRT).
*   **Gestión de Dependencias:** Pacman para paquetes del sistema, pip para Python.
*   **Mecanismo de Automatización:** Scripts de PowerShell (`setup.ps1`) para orquestar descargas y actualizaciones de forma desatendida.
*   **Portabilidad Absoluta:** Aislamiento del directorio `$HOME` para evitar escritura en la máquina host.

---

## Fase 2: Scripts de Automatización e Inicialización (Completado)
*   Creación de [setup.ps1](file:///home/mrtin/dev/p1/entorno/setup.ps1) con descarga dinámica via GitHub API y validación SHA256.
*   Diseño de los cargadores de consola [launch.bat](file:///home/mrtin/dev/p1/entorno/launch.bat) y [launch.ps1](file:///home/mrtin/dev/p1/entorno/launch.ps1).
*   Configuración de exclusiones en `.gitignore` para no subir binarios al repositorio.

---

## Fase 3: Gestión de Editor e Integración VS Code Portable (Completado)
*   Descarga automatizada del archivo ZIP oficial de VS Code en `setup.ps1`.
*   Habilitación del modo portable mediante la creación del directorio `vscode/data/`.
*   Configuración inicial aislada (`telemetry` inactivo, actualizaciones en modo manual) y seteo predeterminado de terminal de integración `bash.exe` de MSYS2.
*   Instalación de extensiones necesarias (`C/C++ Extension Pack` y `Python Extension`) a través del CLI de VS Code de forma automática.
*   Creación de cargadores específicos [launch-vscode.bat](file:///home/mrtin/dev/p1/entorno/launch-vscode.bat) y [launch-vscode.ps1](file:///home/mrtin/dev/p1/entorno/launch-vscode.ps1) para propagar el `PATH` y variables de sesión.

---

## Fase 4: Pruebas de Aceptación (Pendiente de Ejecución en Host)
Para validar que el entorno cumple con los estándares exigidos, se deben realizar las siguientes pruebas manuales tras la inicialización:

### Prueba A: Compilación Clang C
1. Ejecutar `launch.bat`.
2. Crear un archivo `test.c` con el siguiente contenido:
   ```c
   #include <stdio.h>
   int main() {
       printf("Hola desde Clang Portable UCRT!\n");
       return 0;
   }
   ```
3. Compilar: `clang test.c -o test.exe`
4. Ejecutar: `./test.exe`
5. Verificar la salida esperada en consola.

### Prueba B: Ejecución de Python y Pip
1. Ejecutar `launch.bat`.
2. Verificar versiones de herramientas:
   ```bash
   python --version
   pip --version
   ```
3. Instalar un paquete de prueba: `pip install requests`
4. Verificar que se instale en el HOME local (`home/.local/...`) y no en la máquina host.

### Prueba C: Sistema de Construcción (CMake)
1. Crear un `CMakeLists.txt` básico.
2. Generar el build con Ninja: `cmake -G Ninja .`
3. Compilar con `ninja` o `cmake --build .`.

### Prueba D: Validación de VS Code Portable
1. Ejecutar `launch-vscode.bat`.
2. Verificar que el terminal integrado inicie directamente en `Clang64 Bash`.
3. Validar que la compilación de C y Python sea reconocida desde las herramientas de autocompletado en el editor.

---

## Fase 5: Optimización y Mantenimiento (En desarrollo)
*   **Reducción de tamaño:** Ejecución de limpieza de la caché de pacman (`pacman -Scc`) en el script de instalación para reducir el tamaño en disco de la carpeta final.

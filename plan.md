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
*   Diseño de los cargadores [launch.bat](file:///home/mrtin/dev/p1/entorno/launch.bat) y [launch.ps1](file:///home/mrtin/dev/p1/entorno/launch.ps1).
*   Configuración de exclusiones en `.gitignore` para no subir binarios al repositorio.

---

## Fase 3: Pruebas de Aceptación (Pendiente de Ejecución en Host)
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

---

## Fase 4: Optimización y Ajustes Adicionales (Opcional)
*   **Integración con VS Code Portable:** Configuración de `.vscode/settings.json` local para apuntar los paths de compilador y formateador (`clang-format`) a los binarios contenidos en `msys64/`.
*   **Reducción de tamaño:** Limpieza de la caché de pacman (`pacman -Scc`) en el script de instalación para reducir el tamaño en disco de la carpeta final.

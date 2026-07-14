# Casos de Uso del Entorno Portable

Este documento detalla los principales escenarios y problemáticas educativas y logísticas que el Entorno Portable de Desarrollo resuelve de forma directa.

---

## Caso de Uso 1: Estudiante sin Conectividad Constante (Desarrollo Offline)

### Problemática
Muchos estudiantes no cuentan con conexiones a Internet de banda ancha estables en sus hogares para descargar herramientas pesadas como Visual Studio Code, compiladores de C/C++, e intérpretes de Python, o necesitan instalar el entorno en múltiples equipos sin consumir datos repetidamente.

### Solución del Entorno
* **Empaquetado Completo:** Mediante el script `package-env.ps1`, el docente o un estudiante con conectividad puede empaquetar el entorno completo inicializado en un único archivo ZIP.
* **Distribución Física:** El entorno comprimido puede distribuirse a través de unidades USB (pendrives). El estudiante receptor solo debe descomprimir el archivo y el entorno estará 100% operativo de inmediato, sin necesidad de descargar una sola línea de código o paquete de Internet.
* **Caché Local de Paquetes:** El script `download-baseline.sh` precarga la caché local de MSYS2. Esto permite realizar instalaciones y reparaciones del subsistema Unix en computadoras completamente desconectadas a la red.

---

## Caso de Uso 2: Programación en Computadoras Compartidas (Laboratorios y Cybers)

### Problemática
Al programar en computadoras de laboratorios de la universidad o de terceros, los estudiantes a menudo se enfrentan a:
1. Restricciones de permisos (no poder instalar compiladores en el sistema host).
2. Pérdida de privacidad (dejar historiales de consola, llaves SSH privadas, tokens de GitHub o credenciales en el disco duro local).
3. Desconfiguración del entorno al cambiar de máquina en cada clase.

### Solución del Entorno
* **Ejecución sin Instalación:** El entorno funciona de forma autocontenida. WezTerm, VS Code y MSYS2 corren de forma portable sin requerir permisos de Administrador ni escribir en el registro o carpetas del sistema host (`C:\Program Files`, `~`, etc.).
* **Aislamiento en `home/`:** El historial de la terminal Bash, los archivos `.gitconfig`, las llaves SSH, los tokens y las configuraciones del editor se almacenan estrictamente dentro de la carpeta local `home/` en la unidad portable.
* **Saneamiento Automático:** El script `clean-shared-host.ps1` permite al estudiante borrar de forma segura cualquier rastro temporal, historiales del host y credenciales en caché de la computadora compartida antes de retirar su pendrive.

---

## Caso de Uso 3: Homogeneidad y Consistencia en la Cátedra ("En mi máquina funciona")

### Problemática
El docente y los estudiantes se enfrentan a diario con errores de compilación causados por sutiles diferencias de versiones entre sistemas operativos, variables de entorno globales en conflicto o compiladores preinstalados obsoletos. Esto consume valioso tiempo de clase en depurar problemas de configuración del host.

### Solución del Entorno
* **Toolchain Estandarizado:** Todos los estudiantes ejecutan la misma versión exacta del compilador GCC (MinGW-w64 UCRT64), Make, CMake, Ninja y Python.
* **Lanzadores con Inyección Dinámica:** Los cargadores (`launch.bat`, `launch-vscode.bat`) inyectan de forma dinámica en la variable `PATH` de sesión los compiladores locales y el directorio `bin/` portable. Al cerrarse la ventana, el host vuelve a su estado original sin contaminar variables de entorno globales.
* **Soporte de Rutas con Espacios/No ASCII:** Los scripts realizan validaciones en el arranque alertando de manera clara si la ruta de instalación posee espacios o caracteres especiales (acentos) que puedan romper herramientas tradicionales de C como `make`.

---

## Caso de Uso 4: Gestión Sencilla de Librerías en C para Principiantes

### Problemática
Instalar librerías externas de C (como `raylib`, `inih`, `Nuklear`, etc.) en sistemas Windows suele ser un proceso sumamente complejo que involucra compilar desde código fuente, enlazar manualmente rutas de cabeceras (`.h`) y archivos de biblioteca (`.a` / `.dll`), frustrando a alumnos iniciales de programación.

### Solución del Entorno
* **Automatización con `install-lib.sh`:** El estudiante inicia la consola portable y ejecuta un único comando sencillo: `install-lib.sh usuario/repositorio`.
* **Detección de Construcción:** El script clona el código de GitHub, detecta automáticamente si el proyecto usa `Makefile` o `CMake`, lo compila en el entorno local y copia las cabeceras e instalables directamente dentro del prefijo portable `/ucrt64`.
* **Listos para usar:** Una vez finalizado el script, el estudiante puede usar `#include <libreria.h>` en su código y compilar de inmediato sin configurar rutas manuales adicionales.

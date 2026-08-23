# Manual del Entorno de Desarrollo Portable

Este manual describe el funcionamiento, la arquitectura y las herramientas del entorno de desarrollo portable C/Python diseñado para Windows. El objetivo principal es brindarte un espacio de trabajo aislado y autocontenido que no dependa de variables globales de tu máquina host.

---

## 1. Arquitectura del Entorno

El entorno está diseñado bajo el principio de aislamiento absoluto. A continuación se presenta el diagrama de bloques que detalla cómo se organizan y comunican sus componentes:

```{image} images/arquitectura_entorno.svg
:alt: Arquitectura del Entorno Portable
:align: center
:width: 100%
```

### Componentes Físicos y Lógicos

*   **Lanzadores de Sesión (`launch.bat` / `launch.ps1`):** Son las puertas de entrada al entorno. Se encargan de calcular la ruta raíz dinámica (`PORTABLE_ROOT`), inyectar las variables de entorno locales de sesión, sanear el archivo de configuración de WezTerm y lanzar la consola o el editor de código.
*   **Directorio `bin/` (PATH Local):** Contiene herramientas y scripts de automatización propios del entorno portable. Esta carpeta se prepende al `PATH` de la sesión de manera que sus comandos tengan prioridad.
*   **Subsistema MSYS2 (`msys64/`):** Provee el userland de estilo Unix (Bash, pacman, git, ssh) en la carpeta `usr/bin` y el compilador GCC junto con las herramientas nativas de desarrollo en la carpeta `ucrt64/bin`.
*   **Editor de Código VS Code (`vscode/`):** Instalado en modo portable gracias al subdirectorio `vscode/data/`, que almacena las extensiones (como la extensión de C/C++ y Python) y la configuración de usuario sin alterar los directorios del host.
*   **HOME Aislado (`home/`):** Funciona como tu directorio personal local. Cualquier configuración de sesión, historial de comandos o claves SSH se guarda aquí.

---

## 2. Inicialización y Arranque

Para arrancar el entorno tenés dos cargadores principales en la raíz del directorio:

### Lanzar la Consola Portable (WezTerm)
*   **CMD:** Ejecutá `launch.bat`.
*   **PowerShell:** Ejecutá `.\launch.ps1`.

```{note}
Si por alguna razón WezTerm no se encuentra instalado o falla, los lanzadores caerán de forma automática a una sesión Bash interactiva en la consola nativa del sistema, asegurando que nunca te quedes sin terminal.
```

### Lanzar VS Code Portable
*   **CMD:** Ejecutá `launch-vscode.bat`.
*   **PowerShell:** Ejecutá `.\launch-vscode.ps1`.

VS Code heredará de forma directa todas las variables de entorno locales (compiladores, bibliotecas y herramientas de Git), por lo que vas a poder compilar y depurar directamente desde el editor sin configuraciones adicionales.

---

## 3. Herramientas Especiales de Automatización (`bin/`)

En la carpeta `bin/` tenés disponibles scripts de Bash agregados al `PATH` para simplificar la administración del entorno. Ejecutalos directamente desde tu terminal:

### Diagnóstico de Salud del Entorno
Si notás problemas con algún compilador o querés verificar el estado de las herramientas, tenés dos comandos complementarios:
```bash
doctor              # verificación rápida (compila un programa mínimo y valida el entorno)
doctor --fix        # reparación ligera: regenera skel, marcadores y settings base cuando falten
diagnose-env.sh     # informe técnico completo en diagnose.log
```

### Comandos de cátedra para trabajos prácticos
```bash
nuevo-proyecto tp01 # estructura inicial lista para compilar
clonar <url-tp>     # clona el assignment de GitHub Classroom en ~/proyectos
verificar           # corre las pruebas de cátedra del TP (tests/caso_NN)
entregar            # ZIP de entrega validado (compila y verifica antes de empacar)
```

### Descarga de Baseline de Paquetes (Caché Local)
Para descargar todos los paquetes de pacman necesarios para la instalación inicial y guardarlos localmente, ejecutá:
```bash
download-baseline.sh
```
Este script descarga los paquetes a la carpeta `descargas/pacman_cache/` de tu entorno. Es crucial para posibilitar instalaciones o actualizaciones rápidas offline en computadoras sin acceso a internet.

### Configuración Aislada de Git y GitHub
Para registrar tu identidad de autor para commits de Git e iniciar sesión de forma segura y portable en GitHub CLI (`gh`), ejecutá:
```bash
configure-git.sh
```
Tus credenciales de autenticación se guardarán de forma local en tu `home/` portable y no afectarán a las credenciales globales del host.

### Instalador Automatizado de Librerías de C
Si necesitás compilar e instalar bibliotecas externas directamente desde repositorios de GitHub en tu prefijo portable de `/ucrt64`, utilizá:
```bash
install-lib.sh <usuario/repositorio_github> [rama_o_tag]
```
El script descargará, compilará y copiará las cabeceras e instalables de manera desatendida.

### Descarga y Compilación del Lanzador del Entorno
Si necesitás descargar y compilar los accesos directos ejecutables de la raíz (`.exe`) a partir del código fuente del lanzador en C, ejecutá:
```bash
build-launcher.sh
```
El script descargará los archivos fuente si faltan y los compilará usando el compilador UCRT64 GCC.

### Personalización del Mensaje de Bienvenida de Bash
Para configurar el mensaje que se muestra al abrir la consola interactiva Bash, sus colores o elegir entre plantillas sugeridas y frases motivacionales, ejecutá:
```bash
customize-bash.sh
```

### Actualización del Entorno Portable
Para actualizar todos los scripts del entorno a la última versión disponible en GitHub, y opcionalmente relanzar la actualización de las herramientas nativas (VS Code, MSYS2, gcc, etc.), ejecutá:
```bash
update-env.sh
```

### Guía de Ayuda Rápida
Para consultar rápidamente el listado de todos los comandos y scripts útiles disponibles en el entorno portable, simplemente ejecutá:
```bash
ayuda
```

---

## 4. Variante Linux

El mismo concepto de entorno portable existe como variante nativa para Linux, bajo el principio de **cero modificaciones al sistema host y cero permisos de administrador**. No instala componentes: usa las herramientas del sistema y las verifica con un diagnóstico que sugiere comandos sin ejecutarlos.

### Activación por Sesión
```bash
source linux/activate.sh    # activa HOME portable + toolchain en el PATH
ayuda                       # guía rápida
deactivate                  # restaura tu sesión original
```
La activación redirige `$HOME` hacia la carpeta portable del repositorio, antepone los scripts del entorno al `PATH` y exporta las variables del toolchain (`CC`, `CPATH`, `LIBRARY_PATH`, `PKG_CONFIG_PATH`, `CMAKE_PREFIX_PATH`) apuntando al prefijo local `local/`.

### Bootstrap de Dependencias
```bash
linux/bootstrap.sh
```
Diagnóstico solo lectura de las herramientas obligatorias (`git`, `gcc`, `make`, `cmake`, `ninja`, `python3`, `pip`, `curl`) y recomendadas (`gdb`, `cppcheck`, `doxygen`, `gh`, `uv`), con sugerencia del comando de instalación para tu distribución.

### Scripts Específicos (`linux/bin/`)
*   `configure-git.sh`: identidad, preferencias y credenciales paso a paso con GitHub CLI.
*   `customize-terminal.sh`: banner de bienvenida y prompt de Bash entre marcas en `.bashrc`.
*   `install-lib.sh` / `uninstall-lib.sh`: gestión de librerías C desde GitHub en `local/` con manifiesto de desinstalación.

### Notas de Solución de Problemas
*   **Dubious ownership:** si Git reclama propiedad sobre repos en unidades compartidas, ejecutá dentro del entorno `git config --global safe.directory '<ruta-del-repo>'`.
*   **pip bloqueado (PEP 668):** en distribuciones modernas usá `pip --user` (con la sesión activada queda dentro del HOME portable) o entornos virtuales; `uv` crea entornos automáticamente.
*   **Entornos virtuales:** la política del entorno es `uv venv` como creador por defecto cuando existe `uv`, con fallback automático a `python -m venv`; `smoke.sh` reporta qué motor utilizó.
*   **Locale:** la variante no fuerza idioma; si tu host no tiene `es_AR.UTF-8` generado, los mensajes del sistema seguirán el locale disponible.

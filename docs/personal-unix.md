# Configuración en Computadoras Personales (macOS y Linux)

Este procedimiento instala las herramientas y scripts de gestión de Programación 1 directamente en tu perfil de usuario (`$HOME/.local/bin`), sin requerir privilegios de administrador (`sudo`).

---

## 1. Requisitos Previos por Sistema Operativo

### macOS
Tener instaladas las herramientas de línea de comandos de Apple:
```bash
xcode-select --install
```

### Linux (Debian, Ubuntu, Fedora, Arch)
Disponer de compilador C, Make, Git y Python 3:
* **Debian / Ubuntu:** `sudo apt install build-essential git python3 curl`
* **Fedora:** `sudo dnf install gcc make git python3 curl`
* **Arch Linux:** `sudo pacman -S base-devel git python curl`

---

## 2. Instalación de Herramientas y Scripts de Gestión

Desde la raíz del repositorio `entorno`, ejecutá:
```bash
./setup-personal.sh
```

El script realiza de manera desatendida:
1. Comprueba la presencia de las herramientas base del sistema (`clang`/`gcc`, `make`, `git`, `python3`).
2. Instala `uv` en tu perfil (`~/.local/bin`).
3. Instala `gh` (GitHub CLI) de forma local en tu perfil (`~/.local/bin/gh`), sin modificar paquetes globales.
4. Instala los scripts de gestión de cátedra:
   * `nuevo-proyecto <nombre>`: genera la plantilla de proyecto C con Makefile y casos de prueba.
   * `clonar <url>`: clona repositorios de GitHub Classroom en `~/proyectos`.
   * `verificar [dir]`: compila y evalúa las pruebas del trabajo práctico.
   * `entregar [dir]`: empaqueta tu solución en un archivo ZIP limpio y permite subir cambios con Git.
   * `doctor`: diagnostica la salud del entorno en tu equipo.
   * `ayuda`: muestra la referencia rápida de comandos.
5. Configura el `PATH` en `~/.bashrc`, `~/.zshrc` y `~/.bash_profile`.

Para activar los cambios en tu terminal actual:
```bash
source ~/.bashrc   # en Bash
source ~/.zshrc    # en Zsh (macOS)
```

---

## 3. Desinstalación

Para remover los scripts de gestión y restaurar tus archivos de perfil (`.bashrc`, `.zshrc`):
```bash
./desinstalar-personal.sh
```

Si además querés remover `gh` y `uv` instalados en tu perfil:
```bash
./desinstalar-personal.sh --all
```

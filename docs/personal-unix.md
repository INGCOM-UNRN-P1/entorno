# Configuración en Computadoras Personales (macOS y Linux)

## Instalación en una línea (recomendada)

Abrí una terminal y pegá:
```bash
curl -fsSL https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.sh | bash
```

El instalador no usa `sudo` ni instala paquetes del sistema (solo te sugiere el comando si falta
el compilador, `make`, `git` o `python3`). Deja todo dentro de `~/p1`:

| Ruta | Contenido |
|------|-----------|
| `~/p1/entorno` | Scripts del entorno (clon de git, o tarball si no hay git) y `local/bin` con `uv` y `gh`. |
| `~/p1/dev` | Tu espacio de trabajo; `clonar` y los proyectos van a `~/p1/dev/proyectos`. |
| `~/p1/entrar` | Atajo a la sesión aislada (solo en modo separado). |

Durante la instalación te pregunta cómo integrarlo:

1. **Espacio de trabajo separado** (opción por defecto): no toca tu `~/.bashrc`, `~/.zshrc`
   ni tu `~/.gitconfig`. Entrás con `~/p1/entrar`, que abre una terminal Bash con `HOME=~/p1/dev`:
   la identidad de git, la sesión de `gh` y las cachés de `uv` quedan aisladas ahí. Salís con `exit`.
2. **Integrado a tu sesión**: agrega un bloque delimitado por `# >>> p1-entorno >>>` a `~/.bashrc`
   (y a `~/.zshrc` / `~/.bash_profile` en macOS o si usás zsh). Los comandos de cátedra quedan
   disponibles en cualquier terminal nueva, con tu HOME habitual.

Para instalar sin preguntas (o cambiar de modo más adelante), volvé a ejecutarlo con `--modo`:
```bash
curl -fsSL https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.sh | bash -s -- --modo integrado
```
Reejecutar el instalador actualiza el entorno (`git pull`) y conserva `~/p1/dev` y `~/p1/entorno/local`.
Otras opciones: `--sin-herramientas` (no descarga `uv` ni `gh`), `--rama <nombre>`, `--help`.

### Desinstalación
```bash
~/p1/entorno/desinstalar.sh              # pregunta antes de borrar; conserva ~/p1/dev
~/p1/entorno/desinstalar.sh --borrar-dev # borra también tus proyectos (irreversible)
```
Quita el bloque de tus archivos de inicio, `~/p1/entorno` (con `uv` y `gh` locales) y `~/p1/entrar`.
También puede ejecutarse remoto: `curl -fsSL .../desinstalar.sh | bash`.

---

## Instalación alternativa desde un clon (`setup-personal.sh`)

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

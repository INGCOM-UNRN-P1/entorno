#!/usr/bin/env bash
# install.sh - Instalador del entorno de Programación 1 para macOS y Linux.
#
# Uso recomendado (una sola línea en la terminal):
#   curl -fsSL https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.sh | bash
#
# Con opciones (por ejemplo, sin preguntas):
#   curl -fsSL .../install.sh | bash -s -- --modo integrado
#
# Qué hace:
#   1. Diagnostica las herramientas del sistema (compilador C, make, git, python3).
#      Nunca instala paquetes del sistema ni usa sudo: solo sugiere los comandos.
#   2. Descarga el entorno en ~/p1/entorno (git clone, o tarball si no hay git).
#      Si ya estaba instalado, lo actualiza conservando ~/p1/entorno/local.
#   3. Instala uv y gh en ~/p1/entorno/local/bin si no están en el sistema.
#   4. Crea el espacio de trabajo ~/p1/dev.
#   5. Pregunta cómo integrarlo:
#        separado   -> no toca tu configuración; entrás con ~/p1/entrar (HOME aislado).
#        integrado  -> agrega los comandos a tu terminal (~/.bashrc, ~/.zshrc).
#
# Opciones:
#   --modo separado|integrado   Evita la pregunta interactiva.
#   --sin-herramientas          No descarga uv ni gh.
#   --rama <nombre>             Rama del repositorio a instalar (por defecto: main).
#   -h, --help                  Muestra esta ayuda.
#
# Variables de entorno equivalentes / avanzadas:
#   P1_MODO, P1_RAMA, P1_SIN_HERRAMIENTAS=1,
#   P1_REPO_URL     URL de git del repositorio (por defecto, GitHub de la cátedra).
#   P1_TARBALL_URL  URL del .tar.gz usado cuando no hay git.
#   P1_METODO       git | tarball | local (fuerza el método de descarga).
#   P1_SOURCE_DIR   Copia el entorno desde un directorio local (desarrollo y pruebas).
#   P1_TTY          Dispositivo desde el que se leen las respuestas (por defecto /dev/tty).
#
# Toda la lógica vive dentro de main(): si la descarga por 'curl | bash' se corta
# a mitad de camino, bash no llega a ejecutar un script incompleto.

set -eu

main() {
    local CYAN GREEN YELLOW RED BOLD RESET
    CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
    BOLD='\033[1m'; RESET='\033[0m'

    local REPO_WEB="https://github.com/INGCOM-UNRN-P1/entorno"
    local MODO="${P1_MODO:-}"
    local RAMA="${P1_RAMA:-main}"
    local SIN_HERRAMIENTAS="${P1_SIN_HERRAMIENTAS:-0}"
    local TTY_DEV="${P1_TTY:-/dev/tty}"

    info()  { printf "${CYAN}%b${RESET}\n" "$*"; }
    ok()    { printf "${GREEN}[OK]${RESET} %b\n" "$*"; }
    aviso() { printf "${YELLOW}[AVISO]${RESET} %b\n" "$*"; }
    error() { printf "${RED}[ERROR]${RESET} %b\n" "$*" >&2; }

    while [ $# -gt 0 ]; do
        case "$1" in
            --modo)             MODO="${2:-}"; shift ;;
            --modo=*)           MODO="${1#--modo=}" ;;
            --separado)         MODO="separado" ;;
            --integrado)        MODO="integrado" ;;
            --sin-herramientas) SIN_HERRAMIENTAS=1 ;;
            --rama)             RAMA="${2:-main}"; shift ;;
            -h|--help)
                if [ -f "${BASH_SOURCE[0]:-}" ]; then
                    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
                else
                    echo "Ayuda completa: $REPO_WEB/blob/main/install.sh"
                fi
                return 0 ;;
            *) error "Opción desconocida: $1 (usá --help)"; return 2 ;;
        esac
        shift
    done

    case "$MODO" in
        ""|separado|integrado) : ;;
        *) error "Modo inválido '$MODO'. Valores posibles: separado, integrado."; return 2 ;;
    esac

    # Dentro de la sesión separada HOME apunta a ~/p1/dev: instalar ahí anidaría el entorno
    if [ -n "${P1_SEPARADO:-}" ]; then
        error "Estás dentro del espacio de trabajo separado (HOME=$HOME)."
        echo "        Salí con 'exit' y volvé a ejecutar el instalador desde tu sesión habitual." >&2
        return 1
    fi

    local OS
    OS="$(uname -s)"
    case "$OS" in
        Linux|Darwin) : ;;
        *) error "Sistema no soportado: $OS. En Windows usá install.ps1."; return 1 ;;
    esac

    if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then
        error "La variable HOME no apunta a un directorio válido."
        return 1
    fi

    local P1_RAIZ="$HOME/p1"
    local ENTORNO="$P1_RAIZ/entorno"
    local DEV="$P1_RAIZ/dev"
    local ESTADO="$ENTORNO/.p1-instalacion"
    local MARCA_INICIO="# >>> p1-entorno >>>"
    local MARCA_FIN="# <<< p1-entorno <<<"

    printf "${CYAN}${BOLD}%s${RESET}\n" "======================================================================"
    printf "${CYAN}${BOLD}%s${RESET}\n" "  INSTALADOR DEL ENTORNO — PROGRAMACIÓN 1 (macOS / Linux)"
    printf "${CYAN}${BOLD}%s${RESET}\n" "======================================================================"
    echo "Sistema             : $OS ($(uname -m))"
    echo "Entorno             : $ENTORNO"
    echo "Espacio de trabajo  : $DEV"
    echo ""

    # ------------------------------------------------------------------
    # Validación de la ruta de instalación
    # ------------------------------------------------------------------
    case "$P1_RAIZ" in
        *" "*) aviso "La ruta '$P1_RAIZ' contiene espacios: algunos Makefile y herramientas de C fallan con ellos." ;;
    esac
    if printf '%s' "$P1_RAIZ" | LC_ALL=C grep -q '[^ -~]'; then
        aviso "La ruta '$P1_RAIZ' contiene caracteres no ASCII (acentos, ñ): pueden fallar compiladores y depuradores."
    fi
    case "$P1_RAIZ" in
        *OneDrive*|*Dropbox*|*"Google Drive"*|*"Mobile Documents"*|*iCloud*)
            aviso "La ruta '$P1_RAIZ' está dentro de una carpeta sincronizada: la sincronización puede bloquear o corromper archivos al compilar." ;;
    esac

    # ------------------------------------------------------------------
    # 1. Diagnóstico de herramientas del sistema (nunca se instalan)
    # ------------------------------------------------------------------
    info "[1/5] Comprobando herramientas del sistema..."
    local faltan="" t
    for t in git make python3 curl tar; do
        command -v "$t" >/dev/null 2>&1 || faltan="$faltan $t"
    done
    if ! command -v cc >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then
        faltan="$faltan compilador-C"
    fi
    if [ -z "$faltan" ]; then
        ok "Herramientas base presentes (compilador C, make, git, python3, curl, tar)."
    else
        aviso "Faltan herramientas del sistema:$faltan"
        if [ "$OS" = "Darwin" ]; then
            echo "        Instalalas con:  xcode-select --install"
        elif command -v apt-get >/dev/null 2>&1; then
            echo "        Instalalas con:  sudo apt install build-essential git python3 curl tar"
        elif command -v dnf >/dev/null 2>&1; then
            echo "        Instalalas con:  sudo dnf install gcc make git python3 curl tar"
        elif command -v pacman >/dev/null 2>&1; then
            echo "        Instalalas con:  sudo pacman -S base-devel git python curl tar"
        elif command -v zypper >/dev/null 2>&1; then
            echo "        Instalalas con:  sudo zypper install gcc make git python3 curl tar"
        else
            echo "        Instalalas con el gestor de paquetes de tu distribución."
        fi
        echo "        La instalación continúa; los comandos que las necesiten fallarán hasta instalarlas."
    fi

    # ------------------------------------------------------------------
    # Elección del modo (antes de descargar, para no dejar nada a medias)
    # ------------------------------------------------------------------
    local MODO_PREVIO=""
    if [ -f "$ESTADO" ]; then
        MODO_PREVIO="$(sed -n 's/^MODO=//p' "$ESTADO" | head -n 1)"
    fi

    if [ -z "$MODO" ]; then
        if ! { : < "$TTY_DEV"; } 2>/dev/null; then
            error "No hay una terminal para preguntar el modo de instalación."
            echo "        Indicalo explícitamente, por ejemplo:" >&2
            echo "          curl -fsSL .../install.sh | bash -s -- --modo separado" >&2
            return 1
        fi
        local defecto=1
        [ "$MODO_PREVIO" = "integrado" ] && defecto=2
        echo ""
        printf "${BOLD}%s${RESET}\n" "¿Cómo querés instalar el entorno?"
        echo "  1) Espacio de trabajo separado: no modifica tu configuración. Entrás con"
        echo "     '~/p1/entrar', que abre una terminal aislada con HOME en ~/p1/dev."
        echo "  2) Integrado a tu sesión: agrega los comandos de cátedra a tu terminal"
        echo "     habitual (~/.bashrc / ~/.zshrc) y trabajás en ~/p1/dev con tu HOME."
        [ -n "$MODO_PREVIO" ] && echo "  (instalación actual: $MODO_PREVIO)"
        local resp=""
        printf "Opción [%s]: " "$defecto"
        read -r resp < "$TTY_DEV" || resp=""
        [ -z "$resp" ] && resp="$defecto"
        case "$resp" in
            1|s|S|separado)  MODO="separado" ;;
            2|i|I|integrado) MODO="integrado" ;;
            *) error "Opción inválida: '$resp'."; return 1 ;;
        esac
    fi
    ok "Modo elegido: $MODO"

    # ------------------------------------------------------------------
    # 2. Descarga / actualización del entorno en ~/p1/entorno
    # ------------------------------------------------------------------
    echo ""
    info "[2/5] Obteniendo el entorno en $ENTORNO..."

    # Protección: no pisar una carpeta ajena que casualmente se llame igual
    if [ -d "$ENTORNO" ] && [ ! -f "$ESTADO" ] && [ ! -f "$ENTORNO/unix/p1-env.sh" ] &&
        [ -n "$(ls -A "$ENTORNO" 2>/dev/null)" ]; then
        error "'$ENTORNO' ya existe y no parece una instalación del entorno."
        echo "        Movela o renombrala y volvé a ejecutar el instalador." >&2
        return 1
    fi

    local METODO="${P1_METODO:-}"
    if [ -z "$METODO" ]; then
        if [ -n "${P1_SOURCE_DIR:-}" ]; then
            METODO="local"
        elif command -v git >/dev/null 2>&1; then
            METODO="git"
        else
            METODO="tarball"
        fi
    fi
    local REPO_URL="${P1_REPO_URL:-$REPO_WEB.git}"
    local TARBALL_URL="${P1_TARBALL_URL:-$REPO_WEB/archive/refs/heads/$RAMA.tar.gz}"

    mkdir -p "$P1_RAIZ"

    if [ "$METODO" = "git" ] && [ -d "$ENTORNO/.git" ]; then
        # Actualización en el lugar: los cambios locales del usuario nunca se descartan
        if git -C "$ENTORNO" pull --ff-only -q origin "$RAMA"; then
            ok "Entorno actualizado con git ($(git -C "$ENTORNO" rev-parse --short HEAD))."
        else
            aviso "No se pudo actualizar con 'git pull' (¿cambios locales?). Se conserva la versión instalada."
        fi
    else
        local STAGE
        STAGE="$(mktemp -d "$P1_RAIZ/.instalando.XXXXXX")"
        # shellcheck disable=SC2064
        trap "rm -rf '$STAGE'" EXIT
        local ARBOL="$STAGE/entorno"

        case "$METODO" in
            git)
                if ! git clone -q --depth 1 --branch "$RAMA" "$REPO_URL" "$ARBOL"; then
                    error "Falló 'git clone $REPO_URL'. Revisá tu conexión a Internet."
                    return 1
                fi ;;
            tarball)
                mkdir -p "$ARBOL"
                if ! curl -fsSL "$TARBALL_URL" | tar -xzf - -C "$ARBOL" --strip-components=1; then
                    error "Falló la descarga de $TARBALL_URL. Revisá tu conexión a Internet."
                    return 1
                fi ;;
            local)
                if [ ! -d "${P1_SOURCE_DIR:-}" ]; then
                    error "P1_SOURCE_DIR='${P1_SOURCE_DIR:-}' no es un directorio."
                    return 1
                fi
                mkdir -p "$ARBOL"
                (cd "$P1_SOURCE_DIR" && tar -cf - --exclude=./.git --exclude=./home \
                    --exclude=./local --exclude=./.p1-instalacion .) | tar -xf - -C "$ARBOL" ;;
            *) error "Método de descarga desconocido: $METODO"; return 1 ;;
        esac

        if [ ! -f "$ARBOL/unix/p1-env.sh" ] || [ ! -f "$ARBOL/unix/entrar" ]; then
            error "La descarga no contiene el entorno esperado (falta unix/p1-env.sh)."
            return 1
        fi

        # Reemplazo del árbol conservando las herramientas locales ya descargadas
        if [ -d "$ENTORNO" ]; then
            if [ -d "$ENTORNO/local" ]; then
                rm -rf "$ARBOL/local"
                mv "$ENTORNO/local" "$ARBOL/local"
            fi
            mv "$ENTORNO" "$STAGE/anterior"
        fi
        mv "$ARBOL" "$ENTORNO"
        rm -rf "$STAGE"
        trap - EXIT
        ok "Entorno instalado ($METODO) en $ENTORNO."
    fi
    chmod +x "$ENTORNO/unix/entrar" "$ENTORNO/unix/bin/"* "$ENTORNO/desinstalar.sh" 2>/dev/null || true

    # ------------------------------------------------------------------
    # 3. Herramientas de usuario: uv y gh en ~/p1/entorno/local/bin
    # ------------------------------------------------------------------
    echo ""
    info "[3/5] Herramientas de usuario (uv, gh)..."
    local LOCAL_BIN="$ENTORNO/local/bin"
    mkdir -p "$LOCAL_BIN"

    if [ "$SIN_HERRAMIENTAS" = "1" ]; then
        aviso "Descarga de uv y gh omitida (--sin-herramientas)."
    else
        if [ -x "$LOCAL_BIN/uv" ] || command -v uv >/dev/null 2>&1; then
            ok "uv disponible."
        elif curl -fsSL https://astral.sh/uv/install.sh |
            env UV_UNMANAGED_INSTALL="$LOCAL_BIN" UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1 &&
            [ -x "$LOCAL_BIN/uv" ]; then
            ok "uv instalado en $LOCAL_BIN."
        else
            aviso "No se pudo instalar uv. Podés hacerlo luego con: curl -LsSf https://astral.sh/uv/install.sh | sh"
        fi

        if [ -x "$LOCAL_BIN/gh" ] || command -v gh >/dev/null 2>&1; then
            ok "gh disponible."
        elif instalar_gh "$LOCAL_BIN" "$OS"; then
            ok "gh instalado en $LOCAL_BIN."
        else
            aviso "No se pudo instalar gh. Ver https://github.com/cli/cli#installation"
        fi
    fi

    # ------------------------------------------------------------------
    # 4. Espacio de trabajo
    # ------------------------------------------------------------------
    echo ""
    info "[4/5] Preparando el espacio de trabajo $DEV..."
    "$ENTORNO/unix/entrar" --preparar
    ok "Espacio de trabajo listo (proyectos en $DEV/proyectos)."

    # ------------------------------------------------------------------
    # 5. Integración según el modo elegido
    # ------------------------------------------------------------------
    echo ""
    info "[5/5] Configurando el modo '$MODO'..."
    local PERFILES="$HOME/.bashrc $HOME/.zshrc $HOME/.bash_profile $HOME/.profile"
    local p
    if [ "$MODO" = "integrado" ]; then
        rm -f "$P1_RAIZ/entrar"
        local destinos="$HOME/.bashrc"
        if [ "$OS" = "Darwin" ]; then
            destinos="$destinos $HOME/.zshrc $HOME/.bash_profile"
        else
            case "${SHELL:-}" in
                */zsh) destinos="$destinos $HOME/.zshrc" ;;
                *) [ -f "$HOME/.zshrc" ] && destinos="$destinos $HOME/.zshrc" ;;
            esac
        fi
        for p in $destinos; do
            quitar_bloque "$p" "$MARCA_INICIO" "$MARCA_FIN" || true
            agregar_bloque "$p" "$MARCA_INICIO" "$MARCA_FIN" "$ENTORNO"
            echo "  * Configurado: $p"
        done
    else
        for p in $PERFILES; do
            if quitar_bloque "$p" "$MARCA_INICIO" "$MARCA_FIN"; then
                echo "  * Quitada la integración previa de: $p"
            fi
        done
        cat > "$P1_RAIZ/entrar" <<EOF
#!/usr/bin/env bash
# Atajo al espacio de trabajo separado de Programación 1 (generado por install.sh)
exec "$ENTORNO/unix/entrar" "\$@"
EOF
        chmod +x "$P1_RAIZ/entrar"
        echo "  * Creado el atajo: $P1_RAIZ/entrar"
    fi

    {
        echo "MODO=$MODO"
        echo "METODO=$METODO"
        echo "VERSION=$(cat "$ENTORNO/VERSION" 2>/dev/null || echo desconocida)"
        echo "FECHA=$(date '+%Y-%m-%d %H:%M:%S')"
    } > "$ESTADO"

    echo ""
    printf "${GREEN}${BOLD}%s${RESET}\n" "======================================================================"
    printf "${GREEN}${BOLD}%s${RESET}\n" "  INSTALACIÓN COMPLETADA ($MODO)"
    printf "${GREEN}${BOLD}%s${RESET}\n" "======================================================================"
    if [ "$MODO" = "separado" ]; then
        echo "Para empezar a trabajar abrí el espacio separado con:"
        # shellcheck disable=SC2088 # se muestra literal, como lo tipea el usuario
        printf "  ${CYAN}%s${RESET}\n" "~/p1/entrar"
        echo "Adentro tenés 'ayuda', 'nuevo-proyecto', 'clonar', 'verificar', 'entregar' y 'doctor'."
        echo "Tu configuración personal (~/.bashrc, ~/.gitconfig, ...) no se modificó."
    else
        echo "Abrí una terminal nueva (o ejecutá 'source ~/.bashrc' / 'source ~/.zshrc') y probá:"
        printf "  ${CYAN}%s${RESET}\n" "cd ~/p1/dev && ayuda"
    fi
    echo ""
    echo "Para desinstalar:  ~/p1/entorno/desinstalar.sh"
}

# Agrega el bloque delimitado por marcas que carga p1-env.sh
agregar_bloque() { # agregar_bloque <archivo> <inicio> <fin> <entorno>
    local f="$1"
    [ -f "$f" ] || : > "$f"
    # Separar con una línea en blanco solo si el archivo no termina ya en una
    if [ -s "$f" ] && [ -n "$(tail -n 1 "$f")" ]; then
        echo "" >> "$f"
    fi
    cat >> "$f" <<EOF
$2
# Entorno de Programación 1 (agregado por install.sh; se quita con desinstalar.sh)
export P1_ENTORNO="$4"
[ -f "\$P1_ENTORNO/unix/p1-env.sh" ] && . "\$P1_ENTORNO/unix/p1-env.sh"
$3
EOF
}

# Quita el bloque entre marcas sin depender de 'sed -i' (difiere entre GNU y BSD).
# Devuelve 0 si había un bloque para quitar.
quitar_bloque() { # quitar_bloque <archivo> <inicio> <fin>
    local f="$1" tmp
    [ -f "$f" ] && grep -qxF "$2" "$f" || return 1
    tmp="$(mktemp)"
    awk -v s="$2" -v e="$3" '$0 == s { skip = 1; next } skip { if ($0 == e) skip = 0; next } { print }' \
        "$f" > "$tmp"
    # 'cat >' conserva permisos, dueño y enlaces simbólicos del perfil original
    cat "$tmp" > "$f"
    rm -f "$tmp"
    return 0
}

# Descarga el binario oficial de GitHub CLI y lo copia en <bin_dir>
instalar_gh() { # instalar_gh <bin_dir> <os>
    local dir="$1" os="$2" version url_final gh_os gh_arch ext tmp bin
    version="${P1_GH_VERSION:-}"
    if [ -z "$version" ]; then
        # La redirección de /releases/latest no consume cuota de la API de GitHub
        url_final="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest 2>/dev/null || true)"
        version="${url_final##*/v}"
        case "$version" in [0-9]*.[0-9]*) : ;; *) version="2.55.0" ;; esac
    fi
    case "$os" in Darwin) gh_os="macOS"; ext="zip" ;; *) gh_os="linux"; ext="tar.gz" ;; esac
    case "$(uname -m)" in
        x86_64|amd64)  gh_arch="amd64" ;;
        arm64|aarch64) gh_arch="arm64" ;;
        armv6*|armv7*) gh_arch="armv6" ;;
        i386|i686)     gh_arch="386" ;;
        *) return 1 ;;
    esac
    tmp="$(mktemp -d)"
    if ! curl -fsSL -o "$tmp/gh.$ext" \
        "https://github.com/cli/cli/releases/download/v$version/gh_${version}_${gh_os}_${gh_arch}.$ext"; then
        rm -rf "$tmp"; return 1
    fi
    if [ "$ext" = "zip" ]; then
        unzip -q "$tmp/gh.zip" -d "$tmp" || { rm -rf "$tmp"; return 1; }
    else
        tar -xzf "$tmp/gh.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
    fi
    bin="$(find "$tmp" -type f -path '*/bin/gh' | head -n 1)"
    if [ -z "$bin" ]; then rm -rf "$tmp"; return 1; fi
    cp "$bin" "$dir/gh"
    chmod +x "$dir/gh"
    rm -rf "$tmp"
    "$dir/gh" --version >/dev/null 2>&1
}

main "$@"

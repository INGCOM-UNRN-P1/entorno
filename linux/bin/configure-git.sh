#!/usr/bin/env bash
# configure-git.sh - Configura Git paso a paso dentro del entorno portable (Linux),
# incluyendo la autenticación con GitHub CLI (gh). Todo queda aislado en el HOME
# portable activado (~/.gitconfig y ~/.git-credentials), sin tocar el host.

set -u

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

say()  { printf "%b" "$1"; }
ok()   { say "${GREEN}[OK]${RESET} $1\n"; }
warn() { say "${YELLOW}[AVISO]${RESET} $1\n"; }
die()  { say "${RED}[ERROR]${RESET} $1\n" >&2; exit 1; }

# Pregunta con tolerancia a EOF (Ctrl+D): devuelve cadena vacía en lugar de abortar.
# El prompt se escribe en stderr para poder capturar el valor limpio con $().
ASK_EOF=0
ask() {
    local reply=""
    ASK_EOF=0
    printf "%b" "${CYAN}$1${RESET}" >&2
    if ! read -r reply; then
        reply=""
        ASK_EOF=1
    fi
    printf '%s' "$reply"
}

confirm() { # confirm "pregunta" "s|n" -> 0 si responde sí
    local default="$2" answer
    answer="$(ask "$1")"
    [ -z "$answer" ] && answer="$default"
    [[ "$answer" =~ ^[sS]$ ]]
}

if [ -z "${PORTABLE_ROOT:-}" ]; then
    die "No estás dentro del entorno portátil. Activá primero la sesión:
       source linux/activate.sh"
fi
command -v git >/dev/null 2>&1 || die "git no está instalado. Instalalo con tu gestor de paquetes (linux/bootstrap.sh sugiere el comando)."

echo -e "${CYAN}======================================================================${RESET}"
echo -e "${CYAN}          Configuración de Git Portable — Paso a paso${RESET}"
echo -e "${CYAN}======================================================================${RESET}"
echo "Todo se guardará en el HOME portable activo: ${HOME}"
echo ""

# ---------------------------------------------------------------
# Paso 1: Identidad (user.name y user.email)
# ---------------------------------------------------------------
step_n=1
say "${CYAN}=== Paso $((step_n++)): Identidad de Git ===${RESET}\n"

current_name="$(git config --global user.name || true)"
current_email="$(git config --global user.email || true)"
[ -n "$current_name" ] && echo "Nombre actual : $current_name"
[ -n "$current_email" ] && echo "Email actual  : $current_email"
[ -n "$current_name$current_email" ] && echo "(Presioná Enter para conservar el valor actual)"

while :; do
    git_name="$(ask "Ingresá tu nombre para Git (Ej: Martín René): ")"
    [ "$ASK_EOF" -eq 1 ] && die "Entrada agotada (EOF). Configuración cancelada."
    [ -z "$git_name" ] && git_name="$current_name"
    [ -n "$git_name" ] && break
    warn "El nombre no puede quedar vacío."
done

while :; do
    git_email="$(ask "Ingresá tu email para Git (Ej: usuario@gmail.com): ")"
    [ "$ASK_EOF" -eq 1 ] && die "Entrada agotada (EOF). Configuración cancelada."
    [ -z "$git_email" ] && git_email="$current_email"
    if [[ "$git_email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
        break
    fi
    warn "Ingresá un email con formato válido (ej: usuario@dominio.com)."
done

git config --global user.name "$git_name"
git config --global user.email "$git_email"
ok "Identidad guardada: $git_name <$git_email>"

# ---------------------------------------------------------------
# Paso 2: Preferencias básicas recomendadas
# ---------------------------------------------------------------
say "\n${CYAN}=== Paso $((step_n++)): Preferencias básicas ===${RESET}\n"

if confirm "¿Usar 'main' como rama por defecto en repositorios nuevos? (S/n): " "s"; then
    git config --global init.defaultBranch main
    ok "init.defaultBranch = main"
fi
git config --global core.autocrlf input
ok "core.autocrlf = input (finales de línea LF, ideal en Linux)"

# ---------------------------------------------------------------
# Paso 3: Credenciales de GitHub vía GitHub CLI (gh)
# ---------------------------------------------------------------
say "\n${CYAN}=== Paso $((step_n++)): Credenciales de GitHub (gh) ===${RESET}\n"

if command -v gh >/dev/null 2>&1; then
    # gh como credential helper para github.com (compartido con VS Code y consola)
    git config --global credential.https://github.com.helper '!gh auth git-credential'
    git config --global credential.https://gist.github.com.helper '!gh auth git-credential'
    ok "Credential helper de github.com apuntado a 'gh auth git-credential'."

    if gh auth status >/dev/null 2>&1; then
        ok "Ya existe una sesión activa de GitHub CLI."
        if [ -t 0 ] && confirm "¿Querés volver a iniciar sesión / refrescar ahora? (s/N): " "n"; then
            gh auth login || warn "El login interactivo fue cancelado o falló."
        fi
    elif [ ! -t 0 ]; then
        warn "Sesión no interactiva: se omite 'gh auth login'. Ejecutalo luego manualmente."
    else
        if confirm "¿Iniciar sesión en GitHub CLI ahora? (recomendado) (S/n): " "s"; then
            gh auth login || warn "El login interactivo fue cancelado o falló. Podés reintentarlo luego con 'gh auth login'."
        fi
    fi
else
    warn "GitHub CLI (gh) no está instalado en este sistema."
    echo "   linux/bootstrap.sh sugiere el comando de instalación para tu distribución."
    echo "   Más info: https://github.com/cli/cli#installation"
fi

# Fallback genérico para otros servidores (GitLab, Bitbucket, etc.)
git config --global credential.helper 'store --file ~/.git-credentials'
ok "Fallback 'store' configurado en ~/.git-credentials (dentro del HOME portable)."

# ---------------------------------------------------------------
# Paso 4: Resumen y verificación final
# ---------------------------------------------------------------
say "\n${CYAN}=== Paso $((step_n++)): Verificación ===${RESET}\n"
printf "Nombre      : %s\n" "$(git config --global user.name)"
printf "Email       : %s\n" "$(git config --global user.email)"
printf "Rama inicial: %s\n" "$(git config --global init.defaultBranch || echo '(no configurada)')"
printf "Config file : %s/.gitconfig\n" "$HOME"

if command -v gh >/dev/null 2>&1; then
    echo ""
    gh auth status 2>&1 | sed 's/^/  /' || true
fi

echo ""
echo -e "${GREEN}[ÉXITO] Git quedó configurado dentro del entorno portable.${RESET}"

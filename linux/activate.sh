#!/usr/bin/env bash
# activate.sh - Activa el entorno portable de desarrollo (variante Linux) en la sesión actual.
#
# Uso:
#   source linux/activate.sh    # activa el entorno en la sesión actual de Bash
#   deactivate                  # restaura la sesión original
#
# Efectos de la activación:
#   - Redirige $HOME hacia la carpeta portable (aislada del host, igual que en Windows).
#   - Agrega los scripts del entorno y el prefijo local de librerías al PATH.
#   - Exporta las variables del toolchain de C (CC, CXX, CPATH, LIBRARY_PATH,
#     PKG_CONFIG_PATH y CMAKE_PREFIX_PATH) apuntando a <raíz>/local.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "[ERROR] Este script debe cargarse con 'source' y no ejecutarse directamente." >&2
    echo "Uso:    source \"$(dirname "$0")/activate.sh\"" >&2
    exit 1
fi

__portable_activate() {
    local script_dir portable_root env_file home_dir_name home_dir prefix_dir line

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || return 1
    portable_root="$(dirname "$script_dir")"

    # Resolver el nombre del directorio HOME portable desde .env (misma convención que Windows)
    home_dir_name="home"
    env_file="$portable_root/.env"
    if [ -f "$env_file" ]; then
        line="$(sed -n -E 's/^set[[:space:]]+"HOME_DIR_NAME=([^"]+)"[[:space:]]*$/\1/p' "$env_file" | tail -n 1)"
        [ -z "$line" ] && line="$(sed -n -E 's/^HOME_DIR_NAME=([^"[:space:]]+)[[:space:]]*$/\1/p' "$env_file" | tail -n 1)"
        if [ -n "$line" ] && [[ "$line" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
            home_dir_name="$line"
        fi
    fi

    home_dir="$portable_root/$home_dir_name"
    prefix_dir="$portable_root/local"

    # Evitar doble activación del mismo entorno
    if [ "${__PORTABLE_ACTIVE:-}" = "$portable_root" ]; then
        echo "[INFO] El entorno ya está activo en esta sesión (HOME: ${__PORTABLE_HOME})."
        return 0
    fi

    # Resguardar el estado previo de la sesión para poder restaurarlo con 'deactivate'
    __PORTABLE_PREV_HOME="${HOME:-}"
    __PORTABLE_PREV_PATH="${PATH:-}"
    __PORTABLE_PREV_PS1="${PS1:-}"
    __PORTABLE_PREV_CC="${CC:-}"
    __PORTABLE_PREV_CXX="${CXX:-}"
    __PORTABLE_PREV_CFLAGS="${CFLAGS:-}"
    __PORTABLE_PREV_CPATH="${CPATH:-}"
    __PORTABLE_PREV_LIBRARY_PATH="${LIBRARY_PATH:-}"
    __PORTABLE_PREV_LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
    __PORTABLE_PREV_PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
    __PORTABLE_PREV_CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}"

    # Crear el HOME portable si falta y asegurar los archivos de inicio base (skel)
    mkdir -p "$home_dir" || return 1
    if [ ! -f "$home_dir/.bash_profile" ]; then
        cat > "$home_dir/.bash_profile" <<'EOF'
if [ -f "${HOME}/.bashrc" ]; then
  source "${HOME}/.bashrc"
fi
EOF
    fi
    if [ ! -f "$home_dir/.bashrc" ]; then
        cat > "$home_dir/.bashrc" <<'EOF'
# .bashrc - Entorno Portable de Desarrollo (UNRN Andina - Programación 1)
# Podés agregar tus alias y funciones personalizadas debajo de este bloque.

# Agregar los scripts del entorno al PATH (sin duplicar en shells anidados)
if [ -n "$PORTABLE_ROOT" ]; then
    case ":$PATH:" in
        *":$PORTABLE_ROOT/linux/bin:"*) : ;;
        *) export PATH="$PORTABLE_ROOT/linux/bin:$PORTABLE_ROOT/local/bin:$PATH" ;;
    esac
fi

alias ll='ls -alF --color=auto'

if [ -f "${HOME}/.bash_aliases" ]; then
    source "${HOME}/.bash_aliases"
fi

# === START INSTITUTIONAL BANNER ===
echo -e "\e[35m"
echo "======================================================================"
echo "  UNRN Andina - Programación 1"
echo "======================================================================"
echo -e "\e[0m"
command -v ayuda >/dev/null 2>&1 && ayuda
# === END INSTITUTIONAL BANNER ===
EOF
    fi

    # Activar el entorno sobre la sesión actual
    export PORTABLE_ROOT="$portable_root"
    export PORTABLE_PREFIX="$prefix_dir"
    export HOME="$home_dir"

    case ":$PATH:" in
        *":$portable_root/linux/bin:"*) : ;;
        *) export PATH="$portable_root/linux/bin:$prefix_dir/bin:$PATH" ;;
    esac

    export CC=gcc
    export CXX=g++
    export CFLAGS="-O2 -Wall"
    export CPATH="$prefix_dir/include${__PORTABLE_PREV_CPATH:+:$__PORTABLE_PREV_CPATH}"
    export LIBRARY_PATH="$prefix_dir/lib${__PORTABLE_PREV_LIBRARY_PATH:+:$__PORTABLE_PREV_LIBRARY_PATH}"
    export LD_LIBRARY_PATH="$prefix_dir/lib${__PORTABLE_PREV_LD_LIBRARY_PATH:+:$__PORTABLE_PREV_LD_LIBRARY_PATH}"
    export PKG_CONFIG_PATH="$prefix_dir/lib/pkgconfig:$prefix_dir/share/pkgconfig${__PORTABLE_PREV_PKG_CONFIG_PATH:+:$__PORTABLE_PREV_PKG_CONFIG_PATH}"
    export CMAKE_PREFIX_PATH="$prefix_dir${__PORTABLE_PREV_CMAKE_PREFIX_PATH:+:$__PORTABLE_PREV_CMAKE_PREFIX_PATH}"

    # Marca visual violeta en el prompt indicando que la sesión está activa
    if [ -n "${PS1:-}" ]; then
        PS1="\[\e[35m\](p1)\[\e[0m\] ${PS1}"
    fi

    export __PORTABLE_ACTIVE="$portable_root"
    export __PORTABLE_HOME="$home_dir"

    deactivate() {
        [ -n "${__PORTABLE_PREV_HOME}" ] && export HOME="${__PORTABLE_PREV_HOME}" || unset HOME
        export PATH="${__PORTABLE_PREV_PATH}"
        PS1="${__PORTABLE_PREV_PS1}"
        if [ -n "${__PORTABLE_PREV_CC}" ]; then export CC="${__PORTABLE_PREV_CC}"; else unset CC; fi
        if [ -n "${__PORTABLE_PREV_CXX}" ]; then export CXX="${__PORTABLE_PREV_CXX}"; else unset CXX; fi
        if [ -n "${__PORTABLE_PREV_CFLAGS}" ]; then export CFLAGS="${__PORTABLE_PREV_CFLAGS}"; else unset CFLAGS; fi
        if [ -n "${__PORTABLE_PREV_CPATH}" ]; then export CPATH="${__PORTABLE_PREV_CPATH}"; else unset CPATH; fi
        if [ -n "${__PORTABLE_PREV_LIBRARY_PATH}" ]; then export LIBRARY_PATH="${__PORTABLE_PREV_LIBRARY_PATH}"; else unset LIBRARY_PATH; fi
        if [ -n "${__PORTABLE_PREV_LD_LIBRARY_PATH}" ]; then export LD_LIBRARY_PATH="${__PORTABLE_PREV_LD_LIBRARY_PATH}"; else unset LD_LIBRARY_PATH; fi
        if [ -n "${__PORTABLE_PREV_PKG_CONFIG_PATH}" ]; then export PKG_CONFIG_PATH="${__PORTABLE_PREV_PKG_CONFIG_PATH}"; else unset PKG_CONFIG_PATH; fi
        if [ -n "${__PORTABLE_PREV_CMAKE_PREFIX_PATH}" ]; then export CMAKE_PREFIX_PATH="${__PORTABLE_PREV_CMAKE_PREFIX_PATH}"; else unset CMAKE_PREFIX_PATH; fi
        unset PORTABLE_ROOT PORTABLE_PREFIX
        unset __PORTABLE_ACTIVE __PORTABLE_HOME
        unset __PORTABLE_PREV_HOME __PORTABLE_PREV_PATH __PORTABLE_PREV_PS1 \
              __PORTABLE_PREV_CC __PORTABLE_PREV_CXX __PORTABLE_PREV_CFLAGS \
              __PORTABLE_PREV_CPATH __PORTABLE_PREV_LIBRARY_PATH __PORTABLE_PREV_LD_LIBRARY_PATH \
              __PORTABLE_PREV_PKG_CONFIG_PATH __PORTABLE_PREV_CMAKE_PREFIX_PATH
        unset -f deactivate
        echo "[OK] Entorno portable desactivado. Sesión original restaurada."
    }

    echo "======================================================================"
    echo "  UNRN Andina - Programación 1 — Entorno Portable activo (Linux)"
    echo "======================================================================"
    echo "Raíz del entorno : $PORTABLE_ROOT"
    echo "HOME portable    : $HOME"
    echo "Prefijo local    : $PORTABLE_PREFIX (librerías vía install-lib.sh)"
    echo ""
    echo "Ejecutá 'ayuda' para ver los comandos disponibles."
    echo "Ejecutá 'deactivate' para restaurar tu sesión original."
}

__portable_activate
unset -f __portable_activate

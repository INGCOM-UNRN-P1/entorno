#!/usr/bin/env bash
# test_instalador_unix.sh - Pruebas del instalador 'curl | bash' (install.sh) y de
# desinstalar.sh en macOS y Linux.
#
# Uso:  tests/test_instalador_unix.sh
# Variables:
#   P1_TEST_BASH=/bin/bash  intérprete con el que se ejecutan instalador y desinstalador
#                           (en macOS conviene /bin/bash para cubrir Bash 3.2).
#   P1_TEST_RED=1           habilita la prueba que descarga uv y gh reales de Internet.
#
# Cada escenario usa un HOME falso dentro de un sandbox temporal: nunca se toca
# el HOME real ni ~/p1 del host.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASH_BIN="${P1_TEST_BASH:-bash}"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Si las pruebas se lanzan desde una sesión del entorno, no heredar su estado
unset P1_SEPARADO P1_ENTORNO P1_DEV P1_MODO P1_RAMA P1_METODO P1_REPO_URL \
    P1_TARBALL_URL P1_SOURCE_DIR P1_TTY P1_SIN_HERRAMIENTAS P1_GH_VERSION

PASS=0
FAIL=0
assert() { # assert <descripcion> <comando...>
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        echo "FALLA: $desc"
        FAIL=$((FAIL + 1))
    fi
}

GIT_ID="-c user.name=Prueba -c user.email=prueba@test.local"

H=""
nuevo_home() { # crea un HOME falso vacío y lo deja en $H
    H="$(mktemp -d "$SANDBOX/home.XXXXXX")"
}

instalar() { # instalar [opciones...] — instala desde el árbol local sin red
    env HOME="$H" SHELL=/bin/bash P1_SOURCE_DIR="$REPO_ROOT" P1_SIN_HERRAMIENTAS=1 \
        "$BASH_BIN" "$REPO_ROOT/install.sh" "$@"
}

desinstalar() { # desinstalar [opciones...] — usa la copia instalada en ~/p1/entorno
    env HOME="$H" "$BASH_BIN" "$H/p1/entorno/desinstalar.sh" "$@"
}

bloques() { # bloques <archivo> — cantidad de bloques de integración en el archivo
    if [ -f "$1" ]; then grep -cxF "# >>> p1-entorno >>>" "$1"; else echo 0; fi
}

respuestas() { # respuestas <texto> — archivo que simula lo que se tipea en la terminal
    local f
    f="$(mktemp "$SANDBOX/tty.XXXXXX")"
    printf '%b' "$1" > "$f"
    echo "$f"
}

echo "== Instalador unix: $(uname -s) $(uname -m), $("$BASH_BIN" -c 'echo "bash $BASH_VERSION"')"

# ======================================================================
# 1. Modo separado
# ======================================================================
nuevo_home
printf '# configuración personal\nalias ll="ls -l"\n' > "$H/.bashrc"
cp "$H/.bashrc" "$SANDBOX/bashrc.original"
OUT="$(instalar --modo separado 2>&1)"; RC=$?
assert "separado: el instalador termina sin error" test "$RC" -eq 0
assert "separado: el entorno queda en ~/p1/entorno" test -f "$H/p1/entorno/unix/p1-env.sh"
assert "separado: se crea el espacio de trabajo ~/p1/dev/proyectos" test -d "$H/p1/dev/proyectos"
assert "separado: se crea el atajo ejecutable ~/p1/entrar" test -x "$H/p1/entrar"
assert "separado: el estado registra el modo" grep -qx "MODO=separado" "$H/p1/entorno/.p1-instalacion"
assert "separado: no modifica ~/.bashrc" cmp -s "$H/.bashrc" "$SANDBOX/bashrc.original"
assert "separado: no crea ~/.zshrc" test ! -e "$H/.zshrc"
assert "separado: no copia .git, home/ ni local/ del origen" \
    test ! -e "$H/p1/entorno/.git" -a ! -e "$H/p1/entorno/home"
assert "separado: skel .bashrc en el HOME aislado" test -f "$H/p1/dev/.bashrc"
assert "separado: skel .bash_profile en el HOME aislado" test -f "$H/p1/dev/.bash_profile"
assert "separado: el resumen indica cómo entrar" grep -q "p1/entrar" <<<"$OUT"

OUT="$(env HOME="$H" "$H/p1/entrar" bash -c 'echo "$HOME|$P1_DEV|$P1_SEPARADO|$PWD"')"
assert "entrar: HOME aislado apunta a ~/p1/dev" test "$OUT" = "$H/p1/dev|$H/p1/dev|1|$H/p1/dev"

OUT="$(env HOME="$H" "$H/p1/entrar" bash -c 'command -v verificar')"
assert "entrar: los comandos de cátedra están en el PATH" test "$OUT" = "$H/p1/entorno/unix/bin/verificar"

OUT="$(env HOME="$H" "$H/p1/entrar" bash -c '. "$P1_ENTORNO/unix/p1-env.sh"; echo "$PATH"' |
    tr ':' '\n' | grep -c "p1/entorno/unix/bin$")"
assert "entrar: recargar p1-env.sh no duplica el PATH" test "$OUT" -eq 1

env HOME="$H" "$H/p1/entrar" git config --global user.name "Alumno Aislado"
assert "entrar: git config --global queda en ~/p1/dev/.gitconfig" \
    grep -q "Alumno Aislado" "$H/p1/dev/.gitconfig"
assert "entrar: no crea ~/.gitconfig en el HOME real" test ! -e "$H/.gitconfig"

OUT="$(printf 'echo "DENTRO=$HOME"\ncommand -v ayuda\nexit\n' | env HOME="$H" "$H/p1/entrar" 2>/dev/null)"
assert "entrar: la sesión interactiva carga el skel (banner)" grep -q "espacio de trabajo separado" <<<"$OUT"
assert "entrar: la sesión interactiva usa el HOME aislado" grep -qx "DENTRO=$H/p1/dev" <<<"$OUT"
assert "entrar: la sesión interactiva ve los comandos" grep -q "unix/bin/ayuda" <<<"$OUT"

# Flujo completo de un TP dentro del espacio separado
env HOME="$H" "$H/p1/entrar" bash -c 'cd proyectos && nuevo-proyecto tp0' >/dev/null 2>&1
assert "entrar: nuevo-proyecto crea el TP en ~/p1/dev/proyectos" test -f "$H/p1/dev/proyectos/tp0/main.c"
TC="$(env HOME="$H" "$H/p1/entrar" bash -c 'verificar proyectos/tp0 >/dev/null 2>&1; echo $?')"
assert "entrar: verificar aprueba el TP recién creado" test "$TC" -eq 0

REMOTE="$SANDBOX/tp01.git"
git init -q --bare "$REMOTE"
SEED="$SANDBOX/seed"
mkdir -p "$SEED"
printf 'int main(void){return 0;}\n' > "$SEED/main.c"
git -C "$SEED" init -q
git -C "$SEED" add -A
# shellcheck disable=SC2086
git -C "$SEED" $GIT_ID commit -qm "TP inicial"
git -C "$SEED" push -q "$REMOTE" HEAD:refs/heads/main
git -C "$REMOTE" symbolic-ref HEAD refs/heads/main
env HOME="$H" "$H/p1/entrar" clonar "$REMOTE" >/dev/null 2>&1
assert "entrar: clonar deja el repositorio en ~/p1/dev/proyectos" test -d "$H/p1/dev/proyectos/tp01/.git"

# Guardas del modo separado
TC="$(env HOME="$H" P1_SOURCE_DIR="$REPO_ROOT" "$H/p1/entrar" "$BASH_BIN" "$REPO_ROOT/install.sh" \
    --modo separado --sin-herramientas >/dev/null 2>&1; echo $?)"
assert "guarda: el instalador se niega a correr dentro de la sesión separada" test "$TC" -ne 0
assert "guarda: no anida una instalación dentro de ~/p1/dev" test ! -e "$H/p1/dev/p1"
TC="$(env HOME="$H" "$H/p1/entrar" "$BASH_BIN" "$H/p1/entorno/desinstalar.sh" --si >/dev/null 2>&1; echo $?)"
assert "guarda: el desinstalador se niega a correr dentro de la sesión separada" test "$TC" -ne 0
assert "guarda: el entorno sigue instalado" test -d "$H/p1/entorno"

# ======================================================================
# 2. Reinstalación: cambio a integrado, preservación y respuestas por terminal
# ======================================================================
mkdir -p "$H/p1/entorno/local/bin"
printf '#!/bin/sh\necho herramienta\n' > "$H/p1/entorno/local/bin/herramienta-local"
chmod +x "$H/p1/entorno/local/bin/herramienta-local"
: > "$H/.zshrc"

ANS="$(respuestas '2\n')"
OUT="$(env HOME="$H" SHELL=/bin/bash P1_SOURCE_DIR="$REPO_ROOT" P1_TTY="$ANS" \
    "$BASH_BIN" "$REPO_ROOT/install.sh" --sin-herramientas 2>&1)"; RC=$?
assert "integrado: la respuesta '2' por terminal elige el modo integrado" test "$RC" -eq 0
assert "integrado: el estado registra el cambio de modo" grep -qx "MODO=integrado" "$H/p1/entorno/.p1-instalacion"
assert "integrado: agrega un bloque a ~/.bashrc" test "$(bloques "$H/.bashrc")" -eq 1
assert "integrado: agrega un bloque a ~/.zshrc existente" test "$(bloques "$H/.zshrc")" -eq 1
assert "integrado: conserva la configuración personal del usuario" grep -q 'alias ll="ls -l"' "$H/.bashrc"
assert "integrado: quita el atajo del modo separado" test ! -e "$H/p1/entrar"
assert "reinstalación: conserva local/ con herramientas descargadas" test -x "$H/p1/entorno/local/bin/herramienta-local"
assert "reinstalación: conserva los proyectos de ~/p1/dev" test -f "$H/p1/dev/proyectos/tp0/main.c"

instalar --modo integrado >/dev/null 2>&1
assert "integrado: reinstalar es idempotente en ~/.bashrc" test "$(bloques "$H/.bashrc")" -eq 1
assert "integrado: reinstalar es idempotente en ~/.zshrc" test "$(bloques "$H/.zshrc")" -eq 1

ANS="$(respuestas '\n')"
env HOME="$H" SHELL=/bin/bash P1_SOURCE_DIR="$REPO_ROOT" P1_TTY="$ANS" P1_SIN_HERRAMIENTAS=1 \
    "$BASH_BIN" "$REPO_ROOT/install.sh" >/dev/null 2>&1
assert "integrado: Enter conserva el modo de la instalación previa" \
    grep -qx "MODO=integrado" "$H/p1/entorno/.p1-instalacion"

OUT="$(env HOME="$H" PATH="/usr/bin:/bin" bash -c '. "$HOME/.bashrc"; command -v verificar; echo "$P1_DEV"')"
assert "integrado: ~/.bashrc expone los comandos de cátedra" grep -qx "$H/p1/entorno/unix/bin/verificar" <<<"$OUT"
assert "integrado: ~/.bashrc define P1_DEV" grep -qx "$H/p1/dev" <<<"$OUT"
if command -v zsh >/dev/null 2>&1; then
    OUT="$(env HOME="$H" ZDOTDIR="$H" zsh -c '. "$HOME/.zshrc"; command -v verificar')"
    assert "integrado: ~/.zshrc expone los comandos en zsh" test "$OUT" = "$H/p1/entorno/unix/bin/verificar"
fi

env HOME="$H" bash -c '. "$HOME/.bashrc"; clonar "'"$REMOTE"'" "$P1_DEV/otros"' >/dev/null 2>&1
assert "integrado: clonar respeta un destino explícito" test -d "$H/p1/dev/otros/tp01/.git"
rm -rf "$H/p1/dev/proyectos/tp01"
env HOME="$H" bash -c 'cd /; . "$HOME/.bashrc"; clonar "'"$REMOTE"'"' >/dev/null 2>&1
assert "integrado: clonar usa ~/p1/dev/proyectos por defecto" test -d "$H/p1/dev/proyectos/tp01/.git"

# Vuelta a separado: se limpia la integración
instalar --modo separado >/dev/null 2>&1
assert "separado tras integrado: quita el bloque de ~/.bashrc" test "$(bloques "$H/.bashrc")" -eq 0
assert "separado tras integrado: quita el bloque de ~/.zshrc" test "$(bloques "$H/.zshrc")" -eq 0
assert "separado tras integrado: recrea el atajo" test -x "$H/p1/entrar"

# ======================================================================
# 3. Desinstalación
# ======================================================================
instalar --modo integrado >/dev/null 2>&1

TC="$(env P1_TTY=/nonexistent/tty HOME="$H" "$BASH_BIN" "$H/p1/entorno/desinstalar.sh" >/dev/null 2>&1; echo $?)"
assert "desinstalar: sin terminal ni --si no hace nada" test "$TC" -ne 0 -a -d "$H/p1/entorno"

ANS="$(respuestas 'n\n')"
env P1_TTY="$ANS" HOME="$H" "$BASH_BIN" "$H/p1/entorno/desinstalar.sh" >/dev/null 2>&1
assert "desinstalar: responder 'n' cancela sin cambios" test -d "$H/p1/entorno" -a "$(bloques "$H/.bashrc")" -eq 1

ANS="$(respuestas 's\nn\n')"
env P1_TTY="$ANS" HOME="$H" "$BASH_BIN" "$H/p1/entorno/desinstalar.sh" >/dev/null 2>&1
assert "desinstalar: elimina ~/p1/entorno" test ! -e "$H/p1/entorno"
assert "desinstalar: quita el bloque de ~/.bashrc" test "$(bloques "$H/.bashrc")" -eq 0
assert "desinstalar: quita el bloque de ~/.zshrc" test "$(bloques "$H/.zshrc")" -eq 0
assert "desinstalar: conserva la configuración personal" grep -q 'alias ll="ls -l"' "$H/.bashrc"
assert "desinstalar: ~/.bashrc vuelve a su contenido original" \
    bash -c "diff <(grep -v '^\$' '$H/.bashrc') <(grep -v '^\$' '$SANDBOX/bashrc.original')"
assert "desinstalar: responder 'n' conserva ~/p1/dev con los proyectos" test -f "$H/p1/dev/proyectos/tp0/main.c"

TC="$(env HOME="$H" "$BASH_BIN" "$REPO_ROOT/desinstalar.sh" --si >/dev/null 2>&1; echo $?)"
assert "desinstalar: sin instalación previa termina sin error" test "$TC" -eq 0

instalar --modo separado >/dev/null 2>&1
desinstalar --si --borrar-dev >/dev/null 2>&1
assert "desinstalar --borrar-dev: no queda nada en ~/p1" test ! -e "$H/p1"

nuevo_home
mkdir -p "$H/p1/entorno"
printf 'mío\n' > "$H/p1/entorno/notas.txt"
TC="$(env HOME="$H" "$BASH_BIN" "$REPO_ROOT/desinstalar.sh" --si >/dev/null 2>&1; echo $?)"
assert "desinstalar: se niega a borrar un ~/p1/entorno ajeno" test "$TC" -ne 0 -a -f "$H/p1/entorno/notas.txt"
TC="$(instalar --modo separado >/dev/null 2>&1; echo $?)"
assert "instalar: se niega a pisar un ~/p1/entorno ajeno" test "$TC" -ne 0 -a -f "$H/p1/entorno/notas.txt"

# ======================================================================
# 4. Entrega por 'curl | bash' (el script llega por la entrada estándar)
# ======================================================================
nuevo_home
: > "$H/.bashrc"
ANS="$(respuestas '2\n')"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "file://$REPO_ROOT/install.sh" |
        env HOME="$H" SHELL=/bin/bash P1_SOURCE_DIR="$REPO_ROOT" P1_TTY="$ANS" P1_SIN_HERRAMIENTAS=1 \
            "$BASH_BIN" >/dev/null 2>&1
else
    env HOME="$H" SHELL=/bin/bash P1_SOURCE_DIR="$REPO_ROOT" P1_TTY="$ANS" P1_SIN_HERRAMIENTAS=1 \
        "$BASH_BIN" < "$REPO_ROOT/install.sh" >/dev/null 2>&1
fi
assert "curl|bash: las preguntas se leen de la terminal y no del script" \
    grep -qx "MODO=integrado" "$H/p1/entorno/.p1-instalacion"

nuevo_home
TC="$(env HOME="$H" P1_SOURCE_DIR="$REPO_ROOT" P1_TTY=/nonexistent/tty P1_SIN_HERRAMIENTAS=1 \
    "$BASH_BIN" < "$REPO_ROOT/install.sh" >/dev/null 2>&1; echo $?)"
assert "curl|bash: sin terminal y sin --modo aborta antes de descargar" test "$TC" -ne 0 -a ! -e "$H/p1/entorno"

TC="$(env HOME="$H" "$BASH_BIN" -s -- --modo cualquiera < "$REPO_ROOT/install.sh" >/dev/null 2>&1; echo $?)"
assert "curl|bash: un modo inválido se rechaza" test "$TC" -eq 2

env HOME="$H" SHELL=/bin/bash P1_SOURCE_DIR="$REPO_ROOT" P1_SIN_HERRAMIENTAS=1 \
    "$BASH_BIN" -s -- --modo separado < "$REPO_ROOT/install.sh" >/dev/null 2>&1
env HOME="$H" "$BASH_BIN" -s -- --si < "$REPO_ROOT/desinstalar.sh" >/dev/null 2>&1
assert "curl|bash: el desinstalador también funciona por la entrada estándar" test ! -e "$H/p1/entorno"
assert "curl|bash: el desinstalador conserva ~/p1/dev por defecto" test -d "$H/p1/dev"

# ======================================================================
# 5. Métodos de descarga: tarball (sin git) y git (con actualización)
# ======================================================================
ARBOL="$SANDBOX/tarball/entorno-main"
mkdir -p "$ARBOL"
(cd "$REPO_ROOT" && tar -cf - --exclude=./.git --exclude=./home --exclude=./local .) | tar -xf - -C "$ARBOL"
tar -czf "$SANDBOX/entorno.tar.gz" -C "$SANDBOX/tarball" entorno-main

nuevo_home
env HOME="$H" SHELL=/bin/bash P1_METODO=tarball P1_TARBALL_URL="file://$SANDBOX/entorno.tar.gz" \
    P1_SIN_HERRAMIENTAS=1 "$BASH_BIN" "$REPO_ROOT/install.sh" --modo separado >/dev/null 2>&1
assert "tarball: instala el entorno desde el .tar.gz" test -x "$H/p1/entorno/unix/entrar"
assert "tarball: registra el método" grep -qx "METODO=tarball" "$H/p1/entorno/.p1-instalacion"

nuevo_home
TC="$(env HOME="$H" P1_METODO=tarball P1_TARBALL_URL="file://$SANDBOX/no-existe.tar.gz" \
    P1_SIN_HERRAMIENTAS=1 "$BASH_BIN" "$REPO_ROOT/install.sh" --modo separado >/dev/null 2>&1; echo $?)"
assert "tarball: una descarga fallida aborta sin dejar restos" \
    bash -c "[ '$TC' -ne 0 ] && [ ! -e '$H/p1/entorno' ] && ! ls -d '$H/p1'/.instalando.* 2>/dev/null"

ORIGEN="$SANDBOX/origen-git"
cp -R "$ARBOL" "$ORIGEN"
git -C "$ORIGEN" init -q
git -C "$ORIGEN" checkout -q -b main
git -C "$ORIGEN" add -A 2>/dev/null
# shellcheck disable=SC2086
git -C "$ORIGEN" $GIT_ID commit -qm "entorno"

nuevo_home
env HOME="$H" SHELL=/bin/bash P1_METODO=git P1_REPO_URL="$ORIGEN" P1_SIN_HERRAMIENTAS=1 \
    "$BASH_BIN" "$REPO_ROOT/install.sh" --modo separado >/dev/null 2>&1
assert "git: clona el entorno en ~/p1/entorno" test -d "$H/p1/entorno/.git"
assert "git: el estado no ensucia el árbol de trabajo" \
    test -z "$(git -C "$H/p1/entorno" status --porcelain 2>/dev/null)"

printf 'novedad\n' > "$ORIGEN/NOVEDAD.txt"
git -C "$ORIGEN" add NOVEDAD.txt
# shellcheck disable=SC2086
git -C "$ORIGEN" $GIT_ID commit -qm "novedad"
env HOME="$H" SHELL=/bin/bash P1_METODO=git P1_REPO_URL="$ORIGEN" P1_SIN_HERRAMIENTAS=1 \
    "$BASH_BIN" "$REPO_ROOT/install.sh" --modo separado >/dev/null 2>&1
assert "git: reinstalar actualiza con git pull" test -f "$H/p1/entorno/NOVEDAD.txt"

# ======================================================================
# 6. Rutas problemáticas (regla de validación de rutas)
# ======================================================================
H="$SANDBOX/con espacios/Documentos"
mkdir -p "$H"
OUT="$(instalar --modo separado 2>&1)"; RC=$?
assert "ruta con espacios: instala igual" test "$RC" -eq 0
assert "ruta con espacios: advierte al usuario" grep -q "contiene espacios" <<<"$OUT"
OUT="$(env HOME="$H" "$H/p1/entrar" bash -c 'echo "$HOME"')"
assert "ruta con espacios: entrar funciona" test "$OUT" = "$H/p1/dev"
env HOME="$H" "$H/p1/entrar" bash -c 'cd proyectos && nuevo-proyecto tpe' >/dev/null 2>&1
TC="$(env HOME="$H" "$H/p1/entrar" bash -c 'verificar proyectos/tpe >/dev/null 2>&1; echo $?')"
assert "ruta con espacios: verificar compila y aprueba" test "$TC" -eq 0

H="$SANDBOX/OneDrive/usuario"
mkdir -p "$H"
OUT="$(instalar --modo separado 2>&1)"
assert "carpeta sincronizada: advierte al usuario" grep -q "carpeta sincronizada" <<<"$OUT"

# ======================================================================
# 7. (Opcional) Descarga real de uv y gh
# ======================================================================
if [ "${P1_TEST_RED:-0}" = "1" ]; then
    # PATH espejo sin uv/gh para forzar la descarga aunque el runner los traiga
    ESPEJO="$SANDBOX/path-espejo"
    mkdir -p "$ESPEJO"
    IFS_ORIG="$IFS"; IFS=:
    for d in $PATH; do
        [ -d "$d" ] || continue
        for f in "$d"/*; do
            n="${f##*/}"
            case "$n" in gh|uv|uvx) continue ;; esac
            if [ -x "$f" ] && [ ! -e "$ESPEJO/$n" ]; then ln -s "$f" "$ESPEJO/$n"; fi
        done
    done
    IFS="$IFS_ORIG"

    nuevo_home
    env PATH="$ESPEJO" HOME="$H" SHELL=/bin/bash P1_SOURCE_DIR="$REPO_ROOT" \
        "$BASH_BIN" "$REPO_ROOT/install.sh" --modo separado
    assert "red: uv descargado en ~/p1/entorno/local/bin" "$H/p1/entorno/local/bin/uv" --version
    assert "red: gh descargado en ~/p1/entorno/local/bin" "$H/p1/entorno/local/bin/gh" --version
    OUT="$(env PATH="$ESPEJO" HOME="$H" "$H/p1/entrar" bash -c 'command -v uv; command -v gh')"
    assert "red: entrar resuelve uv y gh locales" \
        test "$OUT" = "$H/p1/entorno/local/bin/uv
$H/p1/entorno/local/bin/gh"
    desinstalar --si >/dev/null 2>&1
    assert "red: desinstalar elimina uv y gh locales" test ! -e "$H/p1/entorno/local"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "OK: $PASS pruebas superadas."
    exit 0
else
    echo "FALLOS: $FAIL de $((PASS + FAIL)) pruebas."
    exit 1
fi

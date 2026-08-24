# Propuesta: Prompt de Bash Amigable para Estudiantes

Documento de diseño para mejorar el prompt del terminal portable como
herramienta pedagógica, con foco en estudiantes con poca experiencia de
consola. Propone qué integrar, por qué ayuda, dónde se implementa y cómo se
prueba. Estado: **propuesta** (pendiente de implementación).

---

## 1. Principios de diseño

1. **No invasivo:** el prompt se construye entre marcas (`# === START PROMPT ===`)
   respetando la personalización del alumno (mecanismo existente de
   `customize-terminal.sh`).
2. **Paridad total Windows/Linux:** misma información y colores en MSYS2 UCRT64
   y en la variante Linux.
3. **Cero costo cuando no aporta:** las partes caras (estado de Git) se calculan
   solo en sesiones interactivas y con guarda anti-retraso en pendrives lentos.
4. **Enseñar sin molestar:** cada elemento del prompt debe responder una
   pregunta que un principiante realmente se hace ("¿en qué carpeta estoy?",
   "¿funcionó mi comando?", "¿en qué rama estoy?").

## 2. Prompt objetivo

```
(p1) martinvilu@portable tp01 ── main* ✗1
$ _
```

Lectura de izquierda a derecha: badge del entorno portable → usuario/equipo →
carpeta actual (corta) → rama Git con marcador de cambios (*) → código de error
del comando anterior si falló. Todo en una línea corta que no se rompe aunque
la ruta sea larga.

## 3. Mejoras propuestas

### 3.1 Ruta legible y acortada — Prioridad alta

**Qué:** colapsar `$HOME` a `~` y truncar rutas profundas a los últimos 2-3
componentes (ej: `…/tp01/src`). Hoy `\w` imprime la ruta completa y en el HOME
portable profundo se vuelve inmanejable.

**Por qué ayuda:** el principiante pierde de referencia dónde está; una ruta
kilométrica empuja el cursor y desalinea mentalmente los comandos.

**Dónde:** función `_p1_prompt_dir` en el bloque de prompt compartido
(`linux/bin/customize-terminal.sh` genera la línea; el skel de ambos entornos
la consume).

### 3.2 Resultado del comando anterior visible — Prioridad alta

**Qué:** si el último comando terminó con error, mostrar `✗N` (N = código) en
rojo al final del prompt siguiente.

**Por qué ayuda:** es la lección más importante de consola: "los comandos
avisan si fallaron". Un principiante hoy no distingue un `make` roto de uno
exitoso salvo leyendo todo el scroll.

**Dónde:** `_p1_prompt_status` con `PROMPT_COMMAND`; se limpia al ejecutarse el
siguiente comando.

### 3.3 Rama Git y estado de trabajo — Prioridad alta

**Qué:** dentro de repositorios, mostrar `rama` y `*` si hay cambios sin
commitear (ej: `main*`). Sin paréntesis decorativos ni detalles de stash.

**Por qué ayuda:** el flujo GitHub Classroom (`clonar` → programar →
`entregar`) vive en Git; ver la rama y los cambios pendientes reduce el clásico
"commiteé en la rama equivocada" o "perdí mis cambios".

**Dónde:** `_p1_prompt_git` con lectura liviana de `.git/HEAD` (sin depender de
`__git_ps1`, que puede no estar cargado en MSYS2). Guarda: si `git status`
tarda más de ~200 ms en discos lentos, cachear durante unos segundos vía
marca temporal en variable de sesión.

### 3.4 Protección contra Ctrl+D accidental — Prioridad alta

**Qué:** `IGNOREEOF=3`: cerrar el terminal requiere escribir `exit` o presionar
Ctrl+D tres veces, con mensaje explicativo.

**Por qué ayuda:** Ctrl+D es la forma #1 en que un principiante cierra el
terminal "sin querer" mientras juega con el teclado, perdiendo el contexto de
la sesión portable.

**Dónde:** una línea en el skel `.bashrc` de ambos entornos.

### 3.5 Autocorrección de tipeo en `cd` — Prioridad media

**Qué:** `shopt -s cdspell dirspell`: tolera transposiciones y mayúsculas
incorrectas al entrar a carpetas (`cd Docuemntos` funciona y muestra lo que
corrigió).

**Por qué ayuda:** convierte el error más frecuente del principiante ("No such
file or directory") en un aprendizaje silencioso en vez de un bloqueo.

**Dónde:** skel `.bashrc`.

### 3.6 Historial más útil — Prioridad media

**Qué:** `HISTSIZE=5000`, `HISTCONTROL=ignoreboth` (no guardar duplicados ni
comandos con espacio inicial), `shopt -s histappend` (no pisar el historial
entre terminales).

**Por qué ayuda:** la flecha-arriba es la herramienta favorita del principiante;
que el historial sobreviva entre ventanas y no guarde basura lo hace confiable.

**Dónde:** skel `.bashrc`.

### 3.7 Alias de navegación y borrado prudente — Prioridad media

**Qué:**
- `..` → `cd ..` y `...` → `cd ../..` (navegar sin pensar).
- `rm` → `rm -I` (mayúscula): pide confirmación UNA sola vez cuando se borran
  más de 3 archivos o recursivamente; evita el spam de `-i` pero frena el
  `rm -rf` impulsivo.

**Por qué ayuda:** `..` elimina el error de sintaxis más común del primer
mes; `rm -I` es la red de seguridad con mínima fricción.

**Dónde:** skel `.bashrc` (junto al alias `ll` existente).

### 3.8 Indicador de entorno virtual Python activo — Prioridad baja

**Qué:** prefijo `(venv:nombre)` cuando hay un virtualenv activo (ya lo muestra
el propio venv, pero estandarizar color/formato junto al badge `(p1)`).

**Por qué ayuda:** conecta con la política `uv`/venv del entorno; deja claro
dónde van a parar los `pip install`.

**Dónde:** `_p1_prompt_venv` (lee `VIRTUAL_ENV`), opcional detrás de la
personalización.

### 3.9 Colores accesibles — Prioridad baja

**Qué:** ofrecer en `customize-terminal.sh` una variante de alto contraste
(azul oscuro/naranja en vez de cian/violeta) pensada para daltonismo y
proyectores de aula.

**Dónde:** nueva opción en el menú existente de Parte 2 (Prompt).

## 4. Implementación sugerida

| Paso | Contenido | Archivos |
|---|---|---|
| 1 | Funciones `_p1_prompt_*` + ensamblado del prompt | nuevo `bin/prompt.sh` consumido por el skel (fuente única) |
| 2 | Skel `.bashrc` de Windows y Linux: cargar `prompt.sh` + ajustes 3.4-3.7 | `setup.ps1`, `launch.ps1`, `linux/activate.sh`, `clean-shared-host.ps1` |
| 3 | Badge `(p1)` pasa a formar parte del mismo sistema | `linux/activate.sh` |
| 4 | Opción de alto contraste en personalización | `customize-terminal.sh` / `customize-bash.sh` |
| 5 | Pruebas en suite bash | `tests/test_linux_env.sh` |

**Consideraciones:**
- El prompt solo se activa en shells interactivas (`case $- in *i*)`), nunca en
  scripts ni en `smoke.sh`.
- En shells anidados el PATH ya se deduplica; el prompt debe comportarse igual
  (las funciones son idempotentes).
- La fuente única (`bin/prompt.sh`) debe agregarse a las listas de
  sincronización (`setup.ps1 filesToCopy`, `update-env.sh`) y viajará sola en
  `linux/bin/` para la variante Linux... decisión: vivir en `bin/` y que
  `linux/bin/prompt.sh` sea copia idéntica, como el resto de los comandos.

## 5. Criterios de aceptación (para la implementación)

1. Con sesión activa, el prompt muestra badge, ruta corta, rama Git y estado.
2. Tras un comando fallido aparece `✗N` y desaparece tras el siguiente comando.
3. Fuera de repositorios no hay rastro de Git ni demoras perceptibles.
4. Ctrl+D necesita tres intentos y sugiere `exit`.
5. `cd` corrige errores de tipeo menores mostrando la corrección.
6. La personalización previa del alumno (marcas en `.bashrc`) sigue intacta.
7. La suite bash valida: presencia de funciones tras activar, IGNOREEOF,
   cdspell activo y que `smoke.sh` no se vea afectado.

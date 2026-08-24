# Análisis del Proyecto: Mejoras y Problemas Detectados

Documento de trabajo que releva el estado actual del repositorio y registra el
histórico de problemas detectados con su resolución. Los números de ítem se
conservan por trazabilidad (aparecen en commits y conversaciones).

---

## 1. Estado General (actualizado a v1.1.0)

* **Versión:** `1.1.0` publicada con etiquetas anotadas `v1.0.0` y `v1.1.0`, licencia MIT y CHANGELOG (Keep-a-Changelog + SemVer sobre el archivo `VERSION`). El canal reproducible (`versions.json`, flag `-Latest`, `CHANNEL` en `.env`) usa los tags como base del cuatrimestre.
* **Versión Windows (madura):** instalador desatendido (`setup.ps1`) con verificación SHA256 estricta, marcadores por componente, actualizaciones atómicas de VS Code/WezTerm, preflight de espacio/rutas, reintentos uniformes de descarga (`Invoke-DownloadWithRetry`), caché de la API de GitHub y selección de espejo pacman por latencia; VS Code portable con datos aislados y parcheo quirúrgico de `settings.json`, WezTerm GPU desde plantilla física única, GitHub CLI, empaquetado offline con `-Compact`/`-ConExtensiones`/`-IncluirLibs` e instalador asistido del paquete.
* **Variante Linux (madura):** activación por sesión (`source linux/activate.sh`) con HOME portable, prefijo `local/`, paridad completa de comandos de cátedra y `update-env.sh`. Principio rector intacto: **cero modificaciones al host y cero permisos de administrador** (AGENTS.md).
* **Flujo del alumno:** `nuevo-proyecto` (con depuración F5/GDB, `.clang-format`, `.editorconfig` y caso de prueba inicial), `clonar` (GitHub Classroom), `verificar` (corrector local), `entregar` (valida, empaca y publica con confirmación), `backup`/`restaurar`, `doctor [--fix]`, `soporte` (informe anónimo), `ayuda`.
* **Calidad y CI:** linters (PSScriptAnalyzer, shellcheck, `bash -n`), suite bash de la variante Linux (27 pruebas), suites de lógica de `setup.ps1` y del módulo de lanzadores ejecutables en CI (11 + 17 pruebas) y cadena completa semanal/manual en `windows-latest` (setup → smoke → empaquetado → roundtrip offline).
* **Deuda viva:** únicamente la validación física periódica en host Windows de la cadena PowerShell.

## 2. Corregidos Recientemente

| Problema | Resolución | Referencia |
|---|---|---|
| Lanzadores con argumentos sin re-quoting y espera `INFINITE` | Re-quoting según reglas MSVCRT (validado con roundtrip) + timeout de guarda de 10 min | `348e765` |
| Consultas repetidas a la API de GitHub (rate limit en aulas con NAT) | Caché local `descargas/api_cache` con vencimiento y fallback vencido | `854919e` |
| Cuatro bucles de reintento de descarga duplicados y bloque de espejos inline | Consolidados en `Invoke-DownloadWithRetry` y `Select-PacmanMirrorByLatency` con pruebas | `3b06d0c` |
| Sin aviso de compatibilidad bajo PowerShell 7 | Aviso informativo no bloqueante al detectar pwsh 6+ | `0789425` |
| `doctor --fix` quedó sin commitear tras la sesión de origen | Restaurado, verificado en sandbox (Linux real + Windows simulado) y publicado | `dc01b1d` |
| Distribución formal imposible (sin LICENSE/tags) | Licencia MIT + etiquetas `v1.0.0`/`v1.1.0` + CHANGELOG de release | `9523e9b`, `2a8da45` |
| Lógica de lanzadores duplicada (~80% entre `launch.ps1` y `launch-vscode.ps1`) | Módulo común `env.common.psm1` con 17 pruebas propias en CI | `309d271` |
| Credenciales de respaldo solo en texto plano (`store`) | Elección entre caché temporal en memoria (TTL 1 h, defecto) o `store`; probado en suite bash | `74cf63b` |

Histórico anterior (pre-1.0.0): limpieza de hosts compartidos (`descargas/`, regeneración de skel sin `bash -env`, conservación de marcadores), plantilla UCRT64 canónica, TLS moderno y progreso desactivado, paquete offline sin datos personales, sincronización standalone con `linux/`, referencias rotas a `bootstrap --install`, PATH portable estable.

## 3. Registro de Problemas Originales (ítems 1-26: todos cerrados)

| # | Problema original | Resolución |
|---|---|---|
| 1 | Actualizaciones no atómicas de VS Code/WezTerm | Extracción en temporal, validación del binario clave, swap con rollback y `finally` |
| 2 | Regresión de `customize-terminal.ps1` en `wezterm.lua` | Generación desde la plantilla física única |
| 3 | Round-trip destructivo de `settings.json` | Parcheo quirúrgico de solo `C_Cpp.default.*` |
| 4/7 | Sin versionado reproducible / fallbacks antiguos | Canal `versions.json` pineado + `-Latest` + fallbacks del manifiesto con política semestral |
| 5 | Carpetas sincronizadas no detectadas | Detección OneDrive/Dropbox/etc. en setup y lanzadores |
| 6 | Sin integridad para gh/WezTerm/VS Code | Hash registrado en sidecar `.sha256` y verificación activa contra caché |
| 8 | Actualizaciones obligatoriamente interactivas | `-Yes` desatendido |
| 9 | `update-env.sh` desactualizado | Lista derivada del alcance actual, incluye `docs/` y `linux/` |
| 10 | Paquetes duplicados entre scripts | Fuente única `packages-baseline.txt` |
| 11-12 | Plantilla triplicada + migración por regex | Plantilla física única `wezterm.lua.template`; queda normalización residual mínima UCRT64 |
| 13 | `install-lib.sh` sin desinstalación | `uninstall-lib.sh` multiplataforma con manifiesto |
| 14 | Paquete offline pesado/lento | Poda `-Compact`, política explícita de `local/` (excluido por defecto), extracción rápida con `tar.exe` |
| 15 | `test.ps1` basura | Eliminado; hoy existen suites reales (bash + pwsh) |
| 16 | Links absolutos en plan.md | Rutas relativas |
| 17 | Sin LICENSE/tags/CHANGELOG | MIT + `v1.0.0`/`v1.1.0` + CHANGELOG (`9523e9b`, `2a8da45`) |
| 18 | `LANG=es_AR.UTF-8` inexistente en el host | Variante Linux sin locale forzado; documentado |
| 19-20 | Dubious ownership / PEP 668 | Documentados con guía (`docs/entorno.md`) |
| 21 | `launcher.c` quoting/timeout | Re-quoting MSVCRT + timeout acotado (`348e765`) |
| 22 | `diagnose.log` en CWD | Se escribe en `$PORTABLE_ROOT` |
| 23 | Solo Defender cubierto | Detección de AV de terceros con instrucciones específicas |
| 24 | Editor de Git por defecto | `core.editor "code --wait"` en ambas plataformas |
| 25-26 | GEMINI.md duplicado / docs sin Linux | GEMINI.md es stub de AGENTS.md; documentación con variante Linux |

## 3.5 Nueva Ola (ítems 27-42: todos implementados)

| # | Ítem | Evidencia |
|---|---|---|
| 27 | Scaffolding académico (`nuevo-proyecto`, `entregar`) | `bin/` + `linux/bin/`, probados en suite |
| 28 | Extensiones `.vsix` offline | `package-env.ps1 -ConExtensiones` con instalador offline |
| 29 | `doctor` unificado | Compila, valida Python/Git/gh/PATH; código de salida estándar |
| 30 | Canal por cuatrimestre | `CHANNEL=<tag>` en `.env` consumido por ambos `update-env.sh`; base: tags de release |
| 31 | Desinstalador completo | `desinstalar.ps1` con resumen y confirmación irreversible |
| 32 | Preflight de recursos | Espacio (~4 GB) y advertencia LongPaths antes de descargar |
| 33 | Reintentos uniformes de descargas grandes | `Invoke-DownloadWithRetry` (4 componentes), probado en CI (`3b06d0c`) |
| 34 | Pacman paralelo | `ParallelDownloads = 5` durante inicialización |
| 35 | Compatibilidad PowerShell 7 | Aviso informativo bajo pwsh 6+ (`0789425`); validación completa 5.1/7 requiere host Windows |
| 36 | Defender granular | Exclusiones solo `msys64/`, `vscode/`, `wezterm/` + detección AV de terceros |
| 37 | Fuente única de reglas de agente | GEMINI.md stub → AGENTS.md |
| 38 | Versión visible | `VERSION` en ayuda, banner, diagnóstico e informe de soporte |
| 39 | Política de `local/` en el paquete | Decidida y documentada: excluido por defecto, `-IncluirLibs` opcional |
| 40 | Tests de Linux en CI | `tests/test_linux_env.sh` (25 pruebas) en job dedicado |
| 41 | Resumen final de setup | Estado por componente al cierre del instalador |
| 42 | Paridad de actualización en Linux | `linux/bin/update-env.sh` con canal configurable |

## 3.6 Ola Pedagógica y de Confianza (ítems 43-53: todos implementados)

| # | Ítem | Evidencia |
|---|---|---|
| 43 | Depuración lista en `nuevo-proyecto` | `.vscode/launch.json`+`tasks.json` F5/GDB por plataforma, `.clang-format`, `.editorconfig` |
| 44 | Flujo GitHub Classroom | `clonar <url>` + publicación opcional commit+push en `entregar` (`ff2d609`) |
| 45 | Corrector local `verificar` | Convención `tests/caso_NN.in/.out` o `make test`; filtro en `entregar` (`9009f9a`) |
| 46 | Respaldo del entorno | `backup`/`restaurar` con manifiestos de librerías |
| 47 | Higiene en compartidas | Recordatorio visible en `ayuda` con sesión gh activa |
| 48 | CI real en windows-latest | Workflow semanal/manual: setup → smoke → `-Compact` → roundtrip offline (`d05b7f1`) |
| 49 | Espejo regional pacman | Por latencia con prioridad sudamericana, idempotente (`97f6308`) |
| 50 | Comando `soporte` | Informe único anonimizado listo para adjuntar (`c3078ca`) |
| 51 | `doctor --fix` | Regenera skel/marcadores/settings base sin reinstalar (`dc01b1d`) |
| 52 | `uv` por defecto para venvs | Con fallback automático a `python -m venv`; smoke reporta el motor (`b044d26`) |
| 53 | Módulo común de lanzadores `env.common.psm1` | Fuente única para advertencia de ruta, `.env` y sesión/toolchain; 17 pruebas en CI (`309d271`) |

## 4. Ideas a Futuro (no programadas)

* Alternativa `tar.zst` al ZIP del paquete offline si el tamaño volviera a ser problema.
* Soporte zsh en `activate.sh` (PS1 alternativo) según demanda real de estudiantes.
* Patrón `Execute-WithRetry` para `Expand-Archive` ante antivirus que bloquean archivos (hoy mitigado con reintentos de descarga y extracción atómica).

## 5. Roadmap

| Hito | Contenido | Estado |
|---|---|---|
| ~~1~~ | Atomicidad, customize-terminal, settings.json, `-Yes`, OneDrive | ✅ Completado |
| ~~2~~ | Canal de versiones reproducible (`versions.json` + `-Latest` + `CHANNEL`) | ✅ Completado |
| ~~3~~ | CI de linters + limpieza de repo + AGENTS.md | ✅ Completado |
| ~~4~~ | Plantilla física única `wezterm.lua.template` | ✅ Completado |
| ~~5~~ | Deuda técnica: launcher, caché API, licencia y tags | ✅ Completado |
| ~~6~~ | Producto educativo base (scaffolding, doctor, offline) | ✅ Completado |
| ~~7~~ | Mantenimiento fino (Defender, VERSION, tests CI) | ✅ Completado |
| ~~8~~ | Ola pedagógica completa (43-47, 50-51) | ✅ Completado |
| ~~9~~ | Confianza de despliegue (CI e2e, espejos, uv) | ✅ Completado |
| ~~10~~ | `env.common.psm1` (53) + credenciales cache TTL | ✅ Completado (`309d271`, `74cf63b`) |
| 11 | Validación física en host Windows de la cadena PowerShell | Pendiente (bajo) |

---
*Mantener este documento actualizado en cada corrección: mover los ítems resueltos a las tablas de este registro con referencia de commit.*

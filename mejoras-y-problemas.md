# Análisis del Proyecto: Mejoras y Problemas Detectados

Documento de trabajo que releva el estado actual del repositorio, enumera los problemas detectados con referencias exactas a código y propone mejoras priorizadas. Se actualiza a medida que se corrigen ítems.

---

## 1. Estado General

* **Versión Windows (madura):** Instalador desatendido (`setup.ps1`) con verificación SHA256 estricta de MSYS2, marcadores de estado por componente (`.msys_complete`, `.vscode_complete`, etc.), actualización automática de scripts, VS Code portable con datos aislados, WezTerm GPU, GitHub CLI y empaquetado offline (`package-env.ps1`).
* **Variante Linux (nueva):** Entorno por activación de sesión (`source linux/activate.sh`) con HOME portable, prefijo local `local/` para librerías, bootstrap solo diagnóstico, gestión de librerías (`install-lib.sh`), configuración de Git paso a paso con `gh`, personalización de terminal y comando `ayuda`. Principio rector: **cero modificaciones al host y cero permisos de administrador** (asentado como pauta en GEMINI.md).
* **Deuda documentada:** plan.md mantiene la Fase 9 (pruebas de aceptación manuales) sin ejecutar y un ítem pendiente en Fase 10 (`install-offline.ps1`).

## 2. Corregidos Recientemente

| Problema | Ubicación original |
|---|---|
| Limpieza en hosts compartidos apuntaba a `downloads/` inexistente (hoy `descargas/`) | clean-shared-host.ps1 |
| `bash -env` se interpreta como flags `-e -n -v`: no-op silencioso que impedía regenerar `.bashrc` con alias y banner institucional tras limpiar | clean-shared-host.ps1, setup.ps1 |
| Eliminación de `.vscode_complete` forzaba re-descarga de ~130 MB de VS Code ya saneado | clean-shared-host.ps1 |
| Plantilla `wezterm.lua` generada por setup usaba `MSYSTEM=CLANG64` y `clang64/bin`, contradictoria con el toolchain UCRT64 instalado | setup.ps1 |
| Degradación TLS 1.0/1.1 innecesaria y barra de progreso de PS 5.1 (descargas hasta 10x más lentas) | setup.ps1, install.ps1 |
| Paquete offline incluía `*.log` (con usuario/equipo) y restos personales en `home/` | package-env.ps1 |
| La sincronización de scripts standalone no incluía la carpeta `linux/` | setup.ps1 |
| Referencias rotas a `bootstrap.sh --install` tras eliminar el modo instalación automática | configure-git.sh, install-lib.sh |
| El PATH portable crecía sin control en cada shell anidado y el skel `.bashrc` de setup difería del de launch (faltaban ucrt64/usr) | activate.sh, setup.ps1, launch.ps1 |

## 3. Problemas Abiertos

> **Estado tras la implementación sistemática:** quedaron resueltos los puntos **1** (actualizaciones atómicas), **2** (plantilla canónica en customize-terminal), **3** (settings.json quirúrgico), **5** (detección OneDrive), **8** (`-Yes` desatendido), **9** (update-env propaga docs/linux), **10** (packages-baseline.txt), **11-12** (plantilla física única + fin de la migración masiva por regex), **13** (uninstall-lib con manifiesto multiplataforma), **14** (poda `-Compact` + registro y verificación activa de hashes), **15** (test.ps1 eliminado), **16** (links relativos), **22** (log de diagnóstico en raíz), **23** (AV de terceros), **24** (core.editor), **25** (AGENTS.md) y **26** (docs Linux); documentados **19-20** (safe.directory y PEP 668) con CI de linters. El punto **4/7** quedó cubierto por el canal de versiones (`versions.json` + `-Latest` + `CHANNEL` en `.env`); el **6** por verificación activa contra sidecars; y el plan.md cerró su deuda con `smoke.sh`, `update-packages.sh` e `install-offline.ps1`.

### Prioridad Alta

1. **Actualizaciones no atómicas de componentes** (`setup.ps1`, bloque VS Code y WezTerm): se elimina la instalación previa *antes* de extraer el ZIP nuevo y el respaldo `vscode_data_backup` se mueve sin `try/finally`. Una extracción interrumpida deja el entorno roto o pierde datos del usuario. Propuesta: extraer a directorio temporal, validar presencia del binario clave (`Code.exe`, `wezterm-gui.exe`) y recién entonces hacer swap; restaurar backup en `finally`.

2. **Regresión en `customize-terminal.ps1`** (generación de `wezterm.lua`, sección Parte 2): el config regenerado usa `MSYSTEM="CLANG64"`, pierde `MSYS2_PATH_TYPE`, `PORTABLE_ROOT` exportado, `LANG`, el prepend del PATH portable y `default_cwd`; además cae a `"./"` si `os.getenv("PORTABLE_ROOT")` no existe (ejecución fuera del lanzador). Debe generar exactamente la misma plantilla canónica que setup/launch.

3. **Round-trip destructivo de `settings.json`** (`launch-vscode.ps1:92-112`): cada inicio re-serializa todo el JSON con `ConvertFrom-Json/ConvertTo-Json` de PS 5.1, que corrompe comentarios, reordena claves y aplana arrays de un elemento. Si el alumno edita settings a mano, los pierde. Propuesta: parcheo quirúrgico por regex de solo las dos claves `C_Cpp.default.*`, escribiendo únicamente si cambian.

### Prioridad Media

4. **Sin versionado reproducible de componentes:** `setup.ps1` instala siempre "latest" (VS Code, gh, WezTerm, paquetes pacman del día). Dos estudiantes que inicialicen en fechas distintas obtienen toolchains diferentes dentro del mismo cuatrimestre. Mejora de fondo: manifiesto `versions.json` pineado por semestre (con flag `-Latest` opcional), extensiones de VS Code con versión fija y tags de release por cuatrimestre.

5. **Rutas bajo carpetas sincronizadas no detectadas:** la validación solo advierte espacios/no-ASCII, pero `Documentos` redirigido a OneDrive/Dropbox rompe MSYS2 y compilaciones de forma errática. Agregar detección de patrones de sync en el warning de setup y lanzadores.

6. **Sin verificación de integridad para gh / WezTerm / VS Code:** solo heurísticas de tamaño (>5 MB, >10 MB, >50 MB). MSYS2 sí verifica SHA256 estrictamente. Al menos registrar hash descargado en el marcador `.version` para detectar corrupción entre reintentos.

7. **URLs fallback antiguas y sin política de rotación:** MSYS2 `2025-02-21`, gh `2.49.0`, WezTerm `20240203`. Definir revisión semestral o pin por tag estable documentado (se integra naturalmente con el manifiesto del punto 4).

8. **Modo interactivo obligatorio en actualizaciones:** las preguntas s/n de setup (VS Code, gh, WezTerm) impiden despliegue desatendido en laboratorios. Agregar `-Yes` (aceptar todo) y `-NonInteractive`.

9. **`update-env.sh` desactualizado respecto al alcance actual:** copia scripts raíz y `bin/*` pero ni `docs/` ni `linux/`; además su lista fija de archivos envejece mal (mismo problema que tenía setup antes del fix).

10. **Lista de paquetes duplicada** entre `setup.ps1` y `bin/download-baseline.sh`: riesgo de drift real (ya divergió históricamente). Fuente única (ej. `packages-baseline.txt`) leída por ambos.

11. **Plantilla `wezterm.lua` triplicada** (setup, launch.ps1 fallback, customize-terminal.ps1) con contenido divergente: consolidar en un único archivo canónico parametrizado (sustitución de variables, sin cirugía por regex).

12. **Migración por regex de `wezterm.lua` en `launch.ps1:134-185`:** frágil ante cualquier cambio de formato; desaparece naturalmente si se adopta la plantilla única del punto 11.

13. **`install-lib.sh`:** sin comando de desinstalación; en Windows la copia manual usa `find -maxdepth 2` plano (colisiones) mientras el port Linux copia conservando estructura — unificar comportamiento y agregar `uninstall-lib`.

14. **Tamaño y velocidad del paquete offline:** sin poda de documentación/locales de MSYS2 (`usr/share/doc`, `usr/share/man`) ni herramientas alternativas; `Compress-Archive` es lento y tiene límite de 4 GB por archivo. Evaluar `-Compact` (poda opcional) y `tar.gz/zst`.

### Prioridad Baja

15. **`test.ps1` basura commiteada** (debug con BOM): eliminar o convertir en test Pester real.
16. **Links absolutos `file:///home/mrtin/...` en plan.md:** rompen para cualquier otro usuario; usar rutas relativas.
17. **Sin LICENSE, sin tags/releases ni CHANGELOG:** dificulta distribución formal de la cátedra.
18. **`LANG=es_AR.UTF-8` puede no existir en el host** (warning silencioso de setlocale en bash); considerar `C.UTF-8` como fallback.
19. **Git dubious ownership en laboratorios multiusuario:** documentar (o configurar) `safe.directory` para repos en unidades compartidas.
20. **Python/uv:** `uv pip install` exige virtualenv activo y en Linux moderno `pip` choca con PEP 668 (externally-managed). Prever wrapper o guía (con sesión activada, `--user` cae dentro del HOME portable, que es el comportamiento deseado).
21. **`launcher.c`:** los argumentos se pasan sin re-quoting (rutas con espacios vía `launch-vscode.exe "ruta"` fallan) y espera `INFINITE` sin timeout.
22. **`diagnose-env.sh` escribe `diagnose.log` en el CWD actual:** debería escribirlo en `$PORTABLE_ROOT`.
23. **`fix-antivirus.ps1` solo cubre Defender:** detectar antivirus de terceros y dar instrucciones específicas.
24. **Editor por defecto para Git:** `configure-git.sh` podría fijar `core.editor "code --wait"` en ambas plataformas (menor fricción para alumnos en rebase/commit).
25. **GEMINI.md → AGENTS.md:** adoptar el nombre estándar multi-agente manteniendo GEMINI.md como copia/enlace.
26. **Docs sin variante Linux:** ~~resuelto~~ (ver sección 2).

## 3.5 Nueva Ola Detectada (revisión posterior a la implementación)

> **Estado de implementación:** ítems **27, 28, 29, 30, 31, 32, 33, 34, 36, 37, 38, 39, 40, 41 y 42 quedaron implementados** (35 quedó como aviso informativo de compatibilidad bajo pwsh; la validación completa 5.1/7 requiere host Windows). De esta ola ya están implementados **43** (depuración F5 + clang-format + editorconfig en `nuevo-proyecto`), **44** (flujo GitHub Classroom: comando `clonar` + publicación opcional commit+push en `entregar`), **45** (corrector local `verificar` con casos `tests/caso_NN` y filtro en `entregar`), **46** (`backup`/`restaurar` con exclusión de cachés y reinstalación guiada de librerías), **47** (recordatorio de higiene en ayuda con sesión gh activa + tip al configurar Git), **50** (comando `soporte` con informe anónimo listo para adjuntar) y **51** (`doctor --fix`: regenera skel del HOME, marcadores de estado y settings.json base solo cuando falten, sin reinstalar). Con esto, el hito 8 (ola pedagógica) queda completo.

### Producto / Educativo (mayor valor)

27. **Scaffolding académico:** comandos `nuevo-proyecto <nombre>` (genera estructura C con Makefile/CMakeLists/.gitignore de cátedra) y `entregar <tp>` (empaqueta y valida el TP en ZIP listo para entrega). Es la mejora de mayor impacto directo para Programación 1.
28. **Extensiones VS Code offline:** el paquete distribuido a aulas sin internet no puede instalar extensiones ni el language pack. Que `package-env.ps1` descargue los `.vsix` pineados y los incluya con un instalador offline.
29. **`doctor` unificado:** smoke test post-instalación por plataforma (compila hello.c, importa Python, verifica identidad git y sesión gh, valida PATH). Eleva las Pruebas A-D de plan.md a un comando ejecutable por el alumno.
30. **Canal estable por cuatrimestre:** variable `CHANNEL=<tag>` en `.env` que fije qué versión de scripts/componentes usar (`update-env.sh` y bootstrap remoto apuntan al tag), base simple del manifiesto de versiones pendiente.
31. **Desinstalación completa del entorno:** `desinstalar.ps1` con confirmación y resumen (hoy solo existe limpieza de datos personales).

### Robustez de instalación

32. **Preflight de recursos:** verificar espacio libre (~4 GB) y advertir sobre límite de rutas >260 chars (LongPaths) antes de descargar; hoy falla recién durante la extracción.
33. **Reintentos uniformes de descargas grandes:** MSYS2/VS Code/WezTerm/gh se descargan en un solo intento (solo la verificación SHA tiene reintentos).
34. **Pacman paralelo:** habilitar `ParallelDownloads` en `pacman.conf` durante la inicialización acelera sensiblemente la primera instalación.
35. **Compatibilidad PowerShell 7:** scripts validados implícitamente contra 5.1; probar/garantizar ejecución bajo `pwsh` (encoding, ConvertTo-Json) o documentar restricción.

### Seguridad y mantenimiento

36. **Exclusiones Defender granulares:** excluir solo `msys64/` y `vscode/` en vez de la raíz completa (menor superficie expuesta, misma performance de compilación).
37. **Fuente única de reglas de agente:** GEMINI.md duplica AGENTS.md; convertir GEMINI.md en stub que apunte a AGENTS.md para evitar drift.
38. **Versión visible del entorno:** archivo `VERSION` + línea en banner/ayuda/diagnóstico para identificar builds al pedir soporte.
39. **Política del prefijo `local/` en el paquete offline:** hoy se empaqueta siempre; decidir si va por defecto, detrás de `-ConLibs`, o excluido (consistencia de cátedra vs tamaño).
40. **Tests bats para Linux en CI:** activación/desactivación, parsing de `.env`, bloques de `.bashrc`.
41. **Exit codes estandarizados** y resumen final de setup (éxitos/fallos por componente).
42. **Paridad de actualización en Linux:** equivalente de `update-env.sh` (git pull consciente) o guía documentada para instalaciones clonadas.

## 3.6 Ola Propuesta: Pedagogía y Confianza (revisión final)

### Educativa — flujo del alumno (mayor valor)

43. **Depuración lista para usar:** que `nuevo-proyecto` genere además `.vscode/launch.json` + `tasks.json` preconfigurados (F5 compila y lanza con GDB), `.clang-format` y `.editorconfig`. Hoy el alumno enfrenta el depurador sin andamiaje; es el mayor cuello de aprendizaje post-"Hola Mundo".
44. **Flujo GitHub Classroom:** comando `clonar <url-tp>` (clona el assignment en la carpeta de proyectos y fija upstream) e integración opcional de `entregar` con commit+push al repositorio del alumno, cerrando el ciclo clonar→programar→entregar.
45. **Corrector local:** convención de tests de cátedra dentro del TP (carpeta `tests/` con casos estándar) y comando `verificar` que los ejecuta antes de permitir `entregar`. Autoevaluación previa a la entrega = menos reentregas.
46. **Respaldo del entorno:** comandos `backup` / `restaurar` que empaqueten `home/` + manifiestos de `local/portable-libs` en un ZIP fechado. Los pendrives se pierden o corrompen constantemente; el código del alumno vive ahí.
47. **Higiene en compartidas:** si existe sesión activa de `gh` al abrir terminal en un equipo ajeno, mostrar recordatorio visible de ejecutar `clean-shared-host.ps1` antes de retirarse.

### Infraestructura — confianza de la cátedra

48. **CI real sobre Windows runner:** job (manual `workflow_dispatch` + programado semanal) que ejecute `setup.ps1 -Yes` en `windows-latest`, luego `smoke.ps1`, y cierre el circuito con `package-env.ps1 -Compact` + `install-offline.ps1` en otra carpeta. Es el único camino de validar automáticamente toda la cadena PowerShell que hoy depende de pruebas manuales en host físico.
49. **Espejo regional de pacman:** durante la inicialización, medir latencia contra espejos sudamericanos y configurar el más rápido en `/etc/pacman.conf`; reduce drásticamente el tiempo de primera instalación desde Red UNRN.
50. **Comando `soporte`:** genera un único archivo anónimo (diagnóstico + cola de install.log + VERSION + sistema) listo para adjuntar en la consulta al docente, estandarizando el troubleshooting.
51. **Autorreparación ligera:** `doctor --fix` que regenere skel de `home/`, marcadores de estado y `settings.json` base cuando falten, sin reinstalar componentes.

### Técnica de soporte

52. `uv` como creador de entornos por defecto cuando exista (más rápido y sin dependencias externas que `python -m venv`) con fallback automático.
53. Mantenedores: `env.common.psm1` (lógica común de lanzadores), caché de respuestas API GitHub y quoting de args en `launcher.c` quedan como deuda técnica menor ya relevada (hito 5).

## 4. Mejoras Propuestas por Eje

* **Reproducibilidad académica (nuevo eje prioritario)**
  * Manifiesto de versiones por semestre: componentes nativos (MSYS2 snapshot, VS Code, gh, WezTerm), lista de paquetes pacman y versiones de extensiones de VS Code en un único `versions.json` consumido por setup (puntos 4, 6 y 7).
  * Tags de release (`2026-c1`, etc.) como base del bootstrap remoto (`irm .../tag/.../setup.ps1`) para estabilidad durante el cuatrimestre.
* **Robustez**
  * Instalaciones/actualizaciones atómicas con validación post-extracción (punto 1).
  * Reintentos con backoff para `Expand-Archive` ante archivos bloqueados por antivirus (patrón `Execute-WithRetry` ya existente en customize-terminal.ps1).
  * Smoke tests ejecutables post-instalación que automaticen las Pruebas A-D de plan.md (`smoke.ps1` / port futuro a Linux).
* **Seguridad y privacidad**
  * Hash registrado por componente descargado (punto 6).
  * Ofrecer `credential.helper cache` con TTL como alternativa a `store` en texto plano.
  * Documentar implicancias de excluir toda la carpeta en Windows Defender.
* **Rendimiento**
  * Extracción de ZIPs grandes con `tar.exe` (incluido desde Win10 1803) en lugar de `Expand-Archive`.
  * Caché local de respuestas de la API de GitHub (rate limit 60 req/h por IP en aulas con NAT compartido).
  * Empaquetado offline compacto y alternativas a Compress-Archive (punto 14).
* **Mantenibilidad**
  * Fuente única de verdad para: versiones/paquetes (manifiesto), plantilla wezterm.lua (punto 11), listado de archivos a sincronizar (punto 9).
  * Módulo PowerShell común (`env.common.psm1`) para la lógica duplicada entre `launch.ps1` y `launch-vscode.ps1` (~80% compartido: advertencia de ruta —ampliada con detección OneDrive—, carga `.env`, inyección de variables del toolchain).
  * Portar `install-lib.sh` Linux↔Windows hacia una base común con shim de plataforma + `uninstall-lib` (punto 13).
* **Calidad y CI**
  * GitHub Actions: `PSScriptAnalyzer`, `shellcheck` y `bash -n` en cada push (el repo es 100% scripts: es el mayor multiplicador de calidad disponible).
  * Adoptar AGENTS.md estándar y limpieza de repo (test.ps1, LICENSE, links relativos).
* **UX educativa**
  * Flags `-Yes`/`-HomeDirName` combinables para instalación masiva (punto 8).
  * Concretar `install-offline.ps1` (pendiente explícito de plan.md Fase 10).
  * Guía de language pack offline (vsix side-load) para aulas sin internet.
  * Detección temprana de carpetas sincronizadas (OneDrive) en la advertencia de ruta.
* **Variante Linux**
  * Incluir `linux/` en `update-env.sh` (completar paridad con el fix ya hecho en setup.ps1).
  * Suite mínima de tests bash (bats) para activate/deactivate, parsing de `.env` y bloques de `.bashrc`.
  * Evaluar soporte zsh en `activate.sh` (PS1 alternativo) según demanda real de estudiantes.

## 5. Roadmap Sugerido

| Hito | Contenido | Esfuerzo estimado |
|---|---|---|
| ~~1~~ ✅ | Atomicidad, customize-terminal, settings.json, `-Yes`, OneDrive | Completado |
| ~~2~~ ✅ | Canal de versiones: `versions.json` + `-Latest` + `CHANNEL`; fallbacks migrados al manifiesto; extensiones pineables (4, 7) | Completado |
| ~~3~~ ✅ | CI de linters + limpieza de repo + AGENTS.md | Completado |
| ~~4~~ ✅ | Plantilla física única `wezterm.lua.template` + migración mínima residual (11-12) | Completado |
| 5 | Restantes: caché de respuestas API GitHub, quoting de args en `launcher.c` (21), LICENSE/tag institucional (17 parcial: falta LICENSE) | Bajo-Medio |
| ~~6~~ ✅ | **Producto educativo:** scaffolding, extensiones offline, doctor, desinstalador, smoke automatizado, install-offline (27-31 + Fase 9/10 del plan) | Completado |
| ~~7~~ ✅ | Mantenimiento fino: Defender granular, GEMINI stub, VERSION, política local/, tests CI, resumen setup, update-env Linux (32-42) | Completado |
| ~~8~~ ✅ | **Ola pedagógica completa:** depuración lista, `backup`/`restaurar`, higiene compartidas, `doctor --fix`, GitHub Classroom (`clonar`+push), corrector `verificar` y `soporte` (43-47, 50-51) | Completado |
| 9 | Confianza de despliegue: CI real en windows-latest con setup+smoke+roundtrip offline; espejo regional pacman; uv por defecto (48-49, 52) | Medio-Alto |

---
*Mantener este documento actualizado en cada corrección: mover ítems resueltos a la sección 2 con referencia de commit.*

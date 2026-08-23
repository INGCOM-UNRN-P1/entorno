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

## 3. Problemas Abiertos

### Prioridad Alta

1. **Actualizaciones no atómicas de componentes** (`setup.ps1`, bloque VS Code y WezTerm): se elimina la instalación previa *antes* de extraer el ZIP nuevo y el respaldo `vscode_data_backup` se mueve sin `try/finally`. Una extracción interrumpida deja el entorno roto o pierde datos del usuario. Propuesta: extraer a directorio temporal, validar presencia del binario clave (`Code.exe`, `wezterm-gui.exe`) y recién entonces hacer swap; restaurar backup en `finally`.

2. **Regresión en `customize-terminal.ps1`** (generación de `wezterm.lua`, sección Parte 2): el config regenerado usa `MSYSTEM="CLANG64"`, pierde `MSYS2_PATH_TYPE`, `PORTABLE_ROOT` exportado, `LANG`, el prepend del PATH portable y `default_cwd`; además cae a `"./"` si `os.getenv("PORTABLE_ROOT")` no existe (ejecución fuera del lanzador). Debe generar exactamente la misma plantilla canónica que setup/launch.

3. **Round-trip destructivo de `settings.json`** (`launch-vscode.ps1:92-112`): cada inicio re-serializa todo el JSON con `ConvertFrom-Json/ConvertTo-Json` de PS 5.1, que corrompe comentarios, reordena claves y aplana arrays de un elemento. Si el alumno edita settings a mano, los pierde. Propuesta: parcheo quirúrgico por regex de solo las dos claves `C_Cpp.default.*`, escribiendo únicamente si cambian.

### Prioridad Media

4. **Sin verificación de integridad para gh / WezTerm / VS Code:** solo heurísticas de tamaño (>5 MB, >10 MB, >50 MB). MSYS2 sí verifica SHA256 estrictamente. Al menos registrar hash descargado en el marcador `.version` para detectar corrupción entre reintentos.

5. **URLs fallback antiguas y sin política de rotación:** MSYS2 `2025-02-21`, gh `2.49.0`, WezTerm `20240203`. Definir revisión semestral o pin por tag estable documentado.

6. **Modo interactivo obligatorio en actualizaciones:** las preguntas s/n de setup (VS Code, gh, WezTerm) impiden despliegue desatendido en laboratorios. Agregar `-Yes` (aceptar todo) y `-NonInteractive`.

7. **`update-env.sh` desactualizado respecto al alcance actual:** copia scripts raíz y `bin/*` pero ni `docs/` ni `linux/`; además su lista fija de archivos envejece mal (mismo problema que tenía setup antes del fix).

8. **Lista de paquetes duplicada** entre `setup.ps1` y `bin/download-baseline.sh`: riesgo de drift real (ya divergió históricamente). Fuente única (ej. `packages-baseline.txt`) leída por ambos.

9. **Plantilla `wezterm.lua` triplicada** (setup, launch.ps1 fallback, customize-terminal.ps1) con contenido divergente: consolidar en un único archivo canónico parametrizado (sustitución de variables, sin cirugía por regex).

10. **Migración por regex de `wezterm.lua` en `launch.ps1:134-185`:** frágil ante cualquier cambio de formato; desaparece naturalmente si se adopta la plantilla única del punto 9.

11. **`install-lib.sh` (Windows):** la copia manual de cabeceras usa `find -maxdepth 2` plano (colisiones de nombres) y no existe `uninstall-lib`. El port Linux ya copia conservando estructura; alinear ambos.

### Prioridad Baja

12. **`test.ps1` basura commiteada** (debug con BOM): eliminar o convertir en test Pester real.
13. **Links absolutos `file:///home/mrtin/...` en plan.md:** rompen para cualquier otro usuario; usar rutas relativas.
14. **Sin LICENSE, sin tags/releases ni CHANGELOG:** dificulta distribución formal de la cátedra.
15. **`LANG=es_AR.UTF-8` puede no existir en el host** (warning silencioso de setlocale en bash); considerar `C.UTF-8` como fallback.
16. **Git dubious ownership en laboratorios multiusuario:** documentar (o configurar) `safe.directory` para repos en unidades compartidas.
17. **Python/uv:** `uv pip install` exige virtualenv activo y en Linux moderno `pip` choca con PEP 668 (externally-managed). Prever wrapper o guía (con sesión activada, `--user` cae dentro del HOME portable, que es el comportamiento deseado).

## 4. Mejoras Propuestas por Eje

* **Robustez**
  * Instalaciones/actualizaciones atómicas con validación post-extracción (punto 1).
  * Reintentos con backoff para `Expand-Archive` ante archivos bloqueados por antivirus (patrón `Execute-WithRetry` ya existente en customize-terminal.ps1).
* **Seguridad y privacidad**
  * Hash registrado por componente descargado (punto 4).
  * Ofrecer `credential.helper cache` con TTL como alternativa a `store` en texto plano.
  * Documentar implicancias de excluir toda la carpeta en Windows Defender.
* **Rendimiento**
  * Extracción de ZIPs grandes con `tar.exe` (incluido desde Win10 1803) en lugar de `Expand-Archive`.
  * Caché local de respuestas de la API de GitHub (rate limit 60 req/h por IP en aulas con NAT compartido).
* **Mantenibilidad**
  * Fuente única de verdad para: paquetes pacman (punto 8), plantilla wezterm.lua (punto 9), listado de archivos a sincronizar (punto 7).
  * Módulo PowerShell común (`env.common.psm1`) para la lógica duplicada entre `launch.ps1` y `launch-vscode.ps1` (~80% compartido: advertencia de ruta, carga `.env`, inyección de variables del toolchain).
  * Portar `install-lib.sh` Linux↔Windows hacia una base común con shim de plataforma.
* **Calidad y CI**
  * GitHub Actions: `PSScriptAnalyzer`, `shellcheck` y `bash -n` en cada push (el repo es 100% scripts: es el mayor multiplicador de calidad disponible).
  * Automatizar al menos Pruebas A-D de plan.md como smoke tests ejecutables.
* **UX educativa**
  * Flags `-Yes`/`-HomeDirName` combinables para instalación masiva (punto 6).
  * Concretar `install-offline.ps1` (pendiente explícito de plan.md Fase 10).
  * Guía de language pack offline (vsix side-load) para aulas sin internet.
* **Variante Linux**
  * Incluir `linux/` en `update-env.sh` (completar paridad con el fix ya hecho en setup.ps1).
  * Suite mínima de tests bash (bats) para activate/deactivate, parsing de `.env` y bloques de `.bashrc`.
  * Evaluar soporte zsh en `activate.sh` (PS1 alternativo) según demanda real de estudiantes.

## 5. Roadmap Sugerido

| Hito | Contenido | Esfuerzo estimado |
|---|---|---|
| 1 | Puntos 1-3 (atomicidad, customize-terminal, settings.json) | Medio-Alto |
| 2 | CI de linters + limpieza test.ps1/LICENSE/links (11-14) | Bajo |
| 3 | Fuentes únicas de verdad (7, 8, 9) + `-Yes` (6) | Medio |
| 4 | Integridad de descargas, caché API, install-offline.ps1, tests automáticos | Medio |

---
*Mantener este documento actualizado en cada corrección: mover ítems resueltos a la sección 2 con referencia de commit.*

# Instrucciones para el Agente (GEMINI.md)

Este documento detalla las directrices obligatorias para cualquier modelo de IA o agente de desarrollo que modifique o colabore en este repositorio.

---

## 1. Convención de Commits Semánticos

Cada cambio o grupo de cambios cohesivos debe confirmarse utilizando commits semánticos en **español**. Las etiquetas permitidas son:

*   **`feat:`** Nuevas características o herramientas añadidas (ej: `feat: agregar script de empaquetado offline`).
*   **`fix:`** Corrección de errores en scripts, paths o variables (ej: `fix: corregir validación de caracteres especiales`).
*   **`docs:`** Cambios exclusivamente en la documentación del repositorio (ej: `docs: actualizar README con pasos de distribución`).
*   **`style:`** Formateo de código, corrección de espaciados o sangrías sin cambios de lógica.
*   **`refactor:`** Reestructuración de scripts o funciones que no altera el comportamiento externo.
*   **`test:`** Cambios en casos de prueba o scripts de validación.
*   **`chore:`** Tareas administrativas o de mantenimiento general de la estructura del repositorio (ej: `chore: actualizar exclusiones en gitignore`).

El formato del mensaje debe ser: `<tipo>: <descripción breve en minúsculas y en español>`.

---

## 2. Pautas de Desarrollo y Entorno Portable

*   **Aislamiento del Host:** Cualquier script o herramienta incorporada debe respetar estrictamente el directorio local `home/` como `$HOME`. No se debe escribir nada en la ruta de usuario local del host (`~`).
*   **Compatibilidad con UCRT64:** Todas las compilaciones nativas de C deben realizarse utilizando el prefijo `/ucrt64` y el compilador GCC provisto en MSYS2.
*   **Validación de Rutas:** Cualquier cargador o script nuevo que resuelva directorios del sistema debe comprobar si el path absoluto posee espacios o caracteres no ASCII, advirtiendo al usuario de posibles errores con las herramientas C tradicionales.

*   **Codificación y BOM:** Todo script de PowerShell (.ps1) debe guardarse OBLIGATORIAMENTE con codificación UTF-8 con BOM (Byte Order Mark). PowerShell 5.1 falla al interpretar caracteres acentuados (como Ó, ó) sin el BOM, asumiendo codificación ANSI y corrompiendo el parseo de comillas.

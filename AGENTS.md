# Instrucciones para el Agente (AGENTS.md)

> Este archivo es la **fuente normativa única** para cualquier agente de desarrollo
> (punto de entrada estándar). GEMINI.md se mantiene como stub de compatibilidad.

## Resumen de Reglas Obligatorias

1. **Commits semánticos en español** con el formato `<tipo>: <descripción breve en minúsculas>`.
   Tipos permitidos: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`.

2. **Aislamiento del Host:** Todo script debe respetar el directorio `home/` como `$HOME` portátil.
   Nunca escribir en la ruta de usuario del host.

3. **Cero Huella en Linux:** La variante `linux/` no modifica nada del sistema ni requiere
   permisos de administrador. Escrituras solo dentro del repositorio (`home/`, `local/`) y
   temporales del sistema. Las dependencias del sistema se diagnostican y sugieren, nunca se instalan.

4. **Compatibilidad UCRT64:** Las compilaciones nativas de C en Windows usan `/ucrt64` y GCC.

5. **Validación de Rutas:** Advertir ante rutas con espacios, caracteres no ASCII o carpetas
   sincronizadas (OneDrive/Dropbox).

6. **Codificación:** Los scripts PowerShell (`.ps1`, `.psm1`, `.psd1`) son **ASCII básico
   obligatorio**: sin acentos, sin `ñ`, sin `¿`/`¡`, sin comillas tipográficas, sin emojis ni
   BOM (solo bytes 0x20-0x7E, tabulación y fin de línea CRLF). Así PowerShell 5.1 los lee igual
   sin importar la página de códigos del sistema. Escribir `Instalacion`, `configuracion`,
   `anio`; si un mensaje necesita un carácter no ASCII, generarlo en tiempo de ejecución
   (`[char]0x00E9`). El CI (lint) lo verifica. Los scripts Bash/Lua/C van en UTF-8 sin BOM.

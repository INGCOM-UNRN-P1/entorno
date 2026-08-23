# Instrucciones para el Agente (AGENTS.md)

> Este archivo es el punto de entrada estándar para cualquier agente de desarrollo.
> El contenido normativo vive en [GEMINI.md](GEMINI.md), que se mantiene como copia
> idéntica por compatibilidad. Ante dudas, prevalece GEMINI.md.

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

6. **Codificación y BOM:** Los `.ps1` se guardan OBLIGATORIAMENTE en UTF-8 **con BOM**
   (PowerShell 5.1 corrompe acentos sin BOM). Los scripts Bash/Lua/C van en UTF-8 sin BOM.

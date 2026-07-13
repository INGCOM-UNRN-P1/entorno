# Manual de Compilación con GCC (MinGW-w64)

Este manual describe el funcionamiento del compilador GCC (GNU Compiler Collection) integrado en el subsistema portable UCRT64. El objetivo es comprender cómo se transforma tu código fuente en lenguaje C/C++ en un ejecutable binario nativo optimizado para Windows utilizando la biblioteca UCRT (Universal C Runtime).

---

## 1. Flujo de Compilación con GCC

GCC procesa tu código fuente a través de múltiples fases (Preprocesamiento, Compilación, Ensamblado y Enlazado) para generar el ejecutable final. A continuación podés observar el flujo detallado:

```{image} images/flujo_compilacion.svg
:alt: Flujo de Compilación en GCC / UCRT64
:align: center
:width: 100%
```

### Descripción de las Fases

1.  **Preprocesador (cpp):** Procesa las directivas del preprocesador (ej: `#include`, `#define`, `#ifdef`). Expande macros e incluye los archivos de cabecera directamente en el código fuente. Genera un archivo intermedio expandido.
2.  **Compilador (cc1):** Toma el código fuente expandido del preprocesador y lo traduce a código ensamblador específico para la arquitectura x86-64. En esta fase se realizan los chequeos semánticos, de tipo y las optimizaciones de código. Genera un archivo `.s`.
3.  **Ensamblador (as):** Traduce las instrucciones de lenguaje ensamblador a código binario objeto. Produce archivos `.o` que contienen instrucciones de máquina pero que todavía no están enlazadas.
4.  **Enlazador (ld):** Combina los archivos objeto (.o) con las bibliotecas estándar del sistema (como la UCRT de Windows) y cualquier biblioteca de terceros para resolver las referencias a funciones externas y producir el archivo ejecutable binario final (`.exe`).

---

## 2. Compilación Básica en la Terminal

Una vez que iniciás tu terminal con `launch.bat`, tenés disponible la suite completa de MinGW-w64 en tu PATH de sesión.

### Compilar un Programa Simple
Para compilar un archivo fuente único llamado `main.c`, ejecutá:
```bash
gcc main.c -o main.exe
```

### Advertencias y Diagnósticos de Compilación
Se recomienda compilar siempre habilitando las advertencias del compilador para prevenir errores de lógica, accesos inválidos de memoria o variables no inicializadas:
```bash
gcc -Wall -Wextra main.c -o main.exe
```
*   **`-Wall`**: Habilita todas las advertencias comunes del compilador.
*   **`-Wextra`**: Habilita advertencias adicionales para mejorar el rigor del código.

---

## 3. Niveles de Optimización del Código

GCC te permite controlar el balance entre el tiempo de compilación, el rendimiento del ejecutable y el tamaño del binario final mediante banderas de optimización:

| Bandera | Propósito | Descripción |
| :--- | :--- | :--- |
| **`-O0`** | Sin Optimización | Valor por defecto. Mapeo directo del código a ensamblador. Ideal para depurar con GDB. |
| **`-O1`** | Optimización Básica | Reduce tamaño y tiempo de ejecución sin incrementar drásticamente el tiempo de compilación. |
| **`-O2`** | Optimización Estándar | Recomendado para producción. Aplica la mayoría de las optimizaciones de velocidad del compilador sin comprometer tamaño. |
| **`-O3`** | Optimización Agresiva | Habilita optimizaciones que incrementan el tamaño del binario (ej. vectorización agresiva y desenrollado de bucles) para maximizar la velocidad. |
| **`-Os`** | Optimización de Tamaño | Optimiza la velocidad pero manteniendo a raya el crecimiento físico del ejecutable. |

Ejemplo para compilar en producción con optimización estándar:
```bash
gcc -O2 -Wall -Wextra main.c -o main.exe
```

---

## 4. Compilación Multiarchivo y Enlazado

Cuando tu proyecto crece y se divide en múltiples módulos, debés compilar cada archivo fuente a código objeto (.o) y enlazarlos en un paso posterior.

### Compilación por Módulos
```bash
# 1. Compilar cada archivo fuente a objeto
gcc -c main.c -o main.o
gcc -c math_utils.c -o math_utils.o

# 2. Enlazar los objetos en el ejecutable final
gcc main.o math_utils.o -o programa.exe
```

### Proyectos Complejos (CMake y Ninja)
Para no tener que escribir comandos manuales en la consola, el entorno portable incluye **CMake** y **Ninja**. Podés definir un archivo `CMakeLists.txt` básico:
```cmake
cmake_minimum_required(VERSION 3.20)
project(MiProyecto C)

set(CMAKE_C_STANDARD 11)

add_executable(programa main.c math_utils.c)
```

Y luego compilar desde tu consola ejecutando:
```bash
cmake -G Ninja -B build
cmake --build build
```
Ninja utilizará el compilador GCC en paralelo para realizar compilaciones incrementales ultrarrápidas de forma transparente.

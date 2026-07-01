# compile-launch-vscode.ps1 - Compila el cargador de VS Code a un ejecutable nativo (launch-vscode.exe)
# Idioma: Español rioplatense con voseo.

$ErrorActionPreference = "Stop"
$portableRoot = $PSScriptRoot

# Rutas de compiladores dentro del entorno portable (UCRT64)
$gccPath = Join-Path $portableRoot "msys64\ucrt64\bin\gcc.exe"
$clangPath = Join-Path $portableRoot "msys64\ucrt64\bin\clang.exe"
$compiler = ""

if (Test-Path $clangPath) {
    $compiler = $clangPath
} elseif (Test-Path $gccPath) {
    $compiler = $gccPath
} else {
    # Probar si está en el PATH del sistema
    $compiler = Get-Command "clang" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $compiler) {
        $compiler = Get-Command "gcc" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    }
}

if (-not $compiler) {
    Write-Error "No se encontró ningún compilador (Clang o GCC) en el entorno portable ni en el sistema. Asegurate de correr setup.ps1 primero."
    return
}

Write-Host "Compilador detectado: $compiler" -ForegroundColor Cyan

# Código fuente del wrapper de C
$cSource = @'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

int main() {
    char exe_path[MAX_PATH];
    GetModuleFileNameA(NULL, exe_path, MAX_PATH);

    char *last_backslash = strrchr(exe_path, '\\');
    if (last_backslash != NULL) {
        *last_backslash = '\0';
    }

    char ps1_path[MAX_PATH + 32];
    snprintf(ps1_path, sizeof(ps1_path), "%s\\launch-vscode.ps1", exe_path);

    char *cmd_line = GetCommandLineA();
    char *args = "";
    if (cmd_line != NULL) {
        if (cmd_line[0] == '"') {
            cmd_line++;
            while (*cmd_line != '\0' && *cmd_line != '"') {
                cmd_line++;
            }
            if (*cmd_line == '"') {
                cmd_line++;
            }
        } else {
            while (*cmd_line != '\0' && *cmd_line != ' ') {
                cmd_line++;
            }
        }
        while (*cmd_line == ' ') {
            cmd_line++;
        }
        args = cmd_line;
    }

    char command[MAX_PATH * 2 + 128];
    snprintf(command, sizeof(command), "powershell -NoProfile -ExecutionPolicy Bypass -File \"%s\" %s", ps1_path, args);

    return system(command);
}
'@

# Crear archivo temporal C
$tempCFile = Join-Path $portableRoot "launch-vscode.c"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tempCFile, $cSource, $utf8NoBom)

$outputExe = Join-Path $portableRoot "launch-vscode.exe"
Write-Host "Compilando launch-vscode.c -> launch-vscode.exe..." -ForegroundColor Cyan

# Compilar como aplicación de GUI (-mwindows) para que no se abra ventana de consola al iniciarlo
$process = Start-Process -FilePath $compiler -ArgumentList $tempCFile, "-o", $outputExe, "-mwindows" -Wait -NoNewWindow -PassThru

if (Test-Path $tempCFile) {
    Remove-Item $tempCFile -Force
}

if ($process.ExitCode -eq 0) {
    Write-Host "¡Compilación exitosa! Ejecutable creado en: $outputExe" -ForegroundColor Green
} else {
    Write-Error "Fallo en la compilación de launch-vscode.exe (Código de salida: $($process.ExitCode))"
}

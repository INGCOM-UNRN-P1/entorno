#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

/* Tiempo máximo de espera por el proceso de PowerShell (guarda contra cuelgues).
 * Los lanzadores normales terminan en segundos; el margen amplio cubre el caso
 * de diálogos interactivos (avisos del propio launch.ps1) que el usuario atiende. */
#define LAUNCHER_TIMEOUT_MS (10 * 60 * 1000)

extern char **__argv;
extern int __argc;

/* Agrega un argumento a 'dst' con el escapado exigido por las reglas de línea
 * de comandos de Windows (MSVCRT): comillas envolventes cuando hace falta,
 * duplicado de barras invertidas previas a una comilla y comilla interior como \" . */
static void append_quoted_arg(char *dst, size_t dst_size, const char *arg) {
    size_t len = strlen(dst);

    /* Separador entre argumentos */
    if (len > 0) {
        if (len + 1 >= dst_size) return;
        dst[len++] = ' ';
        dst[len] = '\0';
    }

    int needs_quotes = (strpbrk(arg, " \t\"") != NULL) || (arg[0] == '\0');
    if (!needs_quotes) {
        size_t alen = strlen(arg);
        if (len + alen >= dst_size) return;
        strcat(dst, arg);
        return;
    }

    if (len + 1 >= dst_size) return;
    dst[len++] = '"';

    size_t i = 0;
    while (arg[i] != '\0') {
        size_t backslashes = 0;
        while (arg[i] == '\\') {
            backslashes++;
            i++;
        }
        if (arg[i] == '"') {
            /* Cada barra previa a la comilla se duplica y la comilla se escapa */
            size_t emit = backslashes * 2 + 1; /* +1 por la barra de \" */
            for (size_t k = 0; k < emit; k++) {
                if (len + 1 >= dst_size) return;
                dst[len++] = '\\';
            }
            dst[len++] = '"';
            i++;
        } else if (arg[i] == '\0') {
            /* Barras al final: se duplican para que la comilla de cierre sea literal */
            for (size_t k = 0; k < backslashes * 2; k++) {
                if (len + 1 >= dst_size) return;
                dst[len++] = '\\';
            }
            break;
        } else {
            for (size_t k = 0; k < backslashes; k++) {
                if (len + 1 >= dst_size) return;
                dst[len++] = '\\';
            }
            if (len + 1 >= dst_size) return;
            dst[len++] = arg[i];
            i++;
        }
    }

    if (len + 2 >= dst_size) return;
    dst[len++] = '"';
    dst[len] = '\0';
}

#ifndef LAUNCHER_TEST_OMIT_WINMAIN
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    (void)hInstance;
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    char exe_path[MAX_PATH];
    if (GetModuleFileNameA(NULL, exe_path, MAX_PATH) == 0) {
        return 1;
    }

    // Extraer la ruta del directorio y el nombre del ejecutable
    char dir_path[MAX_PATH];
    strcpy(dir_path, exe_path);
    char *last_backslash = strrchr(dir_path, '\\');
    char exe_name[MAX_PATH] = "";
    if (last_backslash != NULL) {
        strcpy(exe_name, last_backslash + 1);
        *last_backslash = '\0';
    } else {
        strcpy(exe_name, exe_path);
        dir_path[0] = '\0';
    }

    // Convertir a minúsculas para comparar de forma segura
    for (int i = 0; exe_name[i]; i++) {
        if (exe_name[i] >= 'A' && exe_name[i] <= 'Z') {
            exe_name[i] = exe_name[i] - 'A' + 'a';
        }
    }

    // Determinar qué script de PowerShell ejecutar
    char script_name[64];
    if (strstr(exe_name, "wezterm") != NULL) {
        strcpy(script_name, "launch.ps1");
    } else if (strstr(exe_name, "vscode") != NULL) {
        strcpy(script_name, "launch-vscode.ps1");
    } else {
        MessageBoxA(NULL, "Nombre de ejecutable no reconocido. Debe contener 'wezterm' o 'vscode'.", "Error - Lanzador Portable", MB_ICONERROR);
        return 1;
    }

    char ps1_path[MAX_PATH + 64];
    if (dir_path[0] != '\0') {
        snprintf(ps1_path, sizeof(ps1_path), "%s\\%s", dir_path, script_name);
    } else {
        snprintf(ps1_path, sizeof(ps1_path), "%s", script_name);
    }

    // Reconstruir la línea de argumentos con re-quoting seguro (rutas con espacios,
    // comillas o barras invertidas viajan como un único argumento cada una)
    static char command[32768];
    snprintf(command, sizeof(command), "powershell -NoProfile -ExecutionPolicy Bypass -File \"%s\"", ps1_path);
    for (int i = 1; i < __argc; i++) {
        append_quoted_arg(command, sizeof(command), __argv[i]);
    }

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    memset(&pi, 0, sizeof(pi));

    // Ejecutar PowerShell sin ventana de consola (CREATE_NO_WINDOW)
    if (CreateProcessA(NULL, command, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &si, &pi)) {
        DWORD wait_result = WaitForSingleObject(pi.hProcess, LAUNCHER_TIMEOUT_MS);
        DWORD exit_code = 0;
        if (wait_result == WAIT_TIMEOUT) {
            TerminateProcess(pi.hProcess, 1);
            WaitForSingleObject(pi.hProcess, 5000);
            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
            MessageBoxA(NULL, "El lanzador tardó demasiado en responder y fue cancelado.", "Error - Lanzador Portable", MB_ICONERROR);
            return 2;
        }
        GetExitCodeProcess(pi.hProcess, &exit_code);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        return exit_code;
    } else {
        char err_msg[512];
        snprintf(err_msg, sizeof(err_msg), "No se pudo iniciar el proceso de PowerShell para: %s", script_name);
        MessageBoxA(NULL, err_msg, "Error - Lanzador Portable", MB_ICONERROR);
    }

    return 1;
}
#endif

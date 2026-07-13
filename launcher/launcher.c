#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

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

    // Obtener argumentos pasados por línea de comandos
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

    char command[MAX_PATH * 2 + 256];
    snprintf(command, sizeof(command), "powershell -NoProfile -ExecutionPolicy Bypass -File \"%s\" %s", ps1_path, args);

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    memset(&pi, 0, sizeof(pi));

    // Ejecutar PowerShell sin ventana de consola (CREATE_NO_WINDOW)
    if (CreateProcessA(NULL, command, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &si, &pi)) {
        WaitForSingleObject(pi.hProcess, INFINITE);
        DWORD exit_code = 0;
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

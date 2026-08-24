#ifndef WINSTUB_H
#define WINSTUB_H
#include <stddef.h>
#define MAX_PATH 260
#define WINAPI
#define TRUE 1
#define FALSE 0
typedef unsigned long DWORD;
typedef int BOOL;
typedef void *HANDLE;
typedef struct { DWORD cb; unsigned long dwFlags; unsigned short wShowWindow; } STARTUPINFOA;
typedef struct { HANDLE hProcess, hThread; } PROCESS_INFORMATION;
#define STARTF_USESHOWWINDOW 0x1
#define SW_HIDE 0
#define CREATE_NO_WINDOW 0x08000000
#define WAIT_TIMEOUT 258L
#define MB_ICONERROR 0x10
BOOL GetModuleFileNameA(void *, char *, DWORD);
char *GetCommandLineA(void);
BOOL CreateProcessA(const char *, char *, void *, void *, BOOL, DWORD, void *, void *, STARTUPINFOA *, PROCESS_INFORMATION *);
DWORD WaitForSingleObject(HANDLE, DWORD);
BOOL TerminateProcess(HANDLE, unsigned int);
BOOL GetExitCodeProcess(HANDLE, DWORD *);
BOOL CloseHandle(HANDLE);
int MessageBoxA(void *, const char *, const char *, unsigned);
#endif
#ifndef WINSTUB_EXTRA
#define WINSTUB_EXTRA
typedef void *HINSTANCE;
typedef char *LPSTR;
#endif

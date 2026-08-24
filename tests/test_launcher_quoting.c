/* test_launcher_quoting.c - Verifica el re-quoting de argumentos del lanzador
 * ejecutable incluyendo el fuente REAL (launcher/launcher.c) con cabeceras
 * stub de Windows, para que compile en cualquier plataforma con GCC.
 *
 * Compilación:  gcc -Itests/stub -o /tmp/qt tests/test_launcher_quoting.c
 * El símbolo LAUNCHER_TEST_OMIT_WINMAIN evita que WinMain entre en conflicto.
 */

#define LAUNCHER_TEST_OMIT_WINMAIN 1
#include "../launcher/launcher.c"
#include <stdio.h>

/* Parser de referencia con las reglas canónicas de línea de comandos de Windows */
static int ref_parse(const char *p, char out[][256]) {
    int argc = 0;
    while (*p) {
        while (*p == ' ' || *p == '\t') p++;
        if (!*p) break;
        char buf[256]; size_t b = 0; int inq = 0;
        while (*p && (inq || (*p != ' ' && *p != '\t'))) {
            if (*p == '\\') {
                size_t run = 0;
                while (p[run] == '\\') run++;
                p += run;
                if (*p == '"') {
                    size_t half = run / 2;
                    for (size_t k = 0; k < half && b < 255; k++) buf[b++] = '\\';
                    if (run % 2 == 0) { inq = !inq; p++; }
                    else { if (b < 255) buf[b++] = '"'; p++; }
                } else {
                    for (size_t k = 0; k < run && b < 255; k++) buf[b++] = '\\';
                }
                continue;
            }
            if (*p == '"') {
                if (inq && p[1] == '"') { if (b < 255) buf[b++] = '"'; p += 2; }
                else { inq = !inq; p++; }
                continue;
            }
            buf[b++] = *p++;
        }
        buf[b] = '\0';
        strcpy(out[argc++], buf);
    }
    return argc;
}

int main(void) {
    struct { const char *in; } casos[] = {
        {"mi carpeta"}, {"simple"}, {""}, {"a\"b"}, {"back\\end"},
        {"a\\b\"c"}, {"dos  espacios"}, {"ruta\\con\\barras"},
        {"espacio\\"}, {"tab\ttab"},
    };
    int fails = 0, total = (int)(sizeof(casos)/sizeof(casos[0]));

    for (int c = 0; c < total; c++) {
        char line[1024] = "PROG";
        append_quoted_arg(line, sizeof(line), casos[c].in);
        char parsed[16][256];
        int n = ref_parse(line, parsed);
        if (n != 2 || strcmp(parsed[1], casos[c].in) != 0) {
            printf("FALLA [%s]: '%s' -> %d args", casos[c].in, line, n);
            if (n >= 2) printf(", ultimo='%s'", parsed[n-1]);
            printf("\n");
            fails++;
        }
    }

    /* Múltiples argumentos y preservación de vacíos */
    char line[1024] = "";
    append_quoted_arg(line, sizeof(line), "uno");
    append_quoted_arg(line, sizeof(line), "");
    append_quoted_arg(line, sizeof(line), "dos tres");
    char parsed[16][256];
    int n = ref_parse(line, parsed);
    if (n != 3 || strcmp(parsed[0], "uno") || strcmp(parsed[1], "") || strcmp(parsed[2], "dos tres")) {
        printf("FALLA multi: '%s' -> %d args\n", line, n);
        fails++;
    }

    if (fails == 0) {
        printf("OK: %d casos de quoting del lanzador con roundtrip MSVCRT\n", total);
        return 0;
    }
    return 1;
}

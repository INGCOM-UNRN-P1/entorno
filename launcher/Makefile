CC = gcc
CFLAGS = -O2 -Wall -mwindows
LDFLAGS = 

TARGETS = ../launch_vscode.exe ../launch-vscode.exe ../launch_wezterm.exe ../launch-wezterm.exe

all: $(TARGETS)

../launch_vscode.exe: launcher.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

../launch-vscode.exe: launcher.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

../launch_wezterm.exe: launcher.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

../launch-wezterm.exe: launcher.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS)

.PHONY: all clean

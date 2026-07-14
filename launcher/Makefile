CC = gcc
CFLAGS = -O2 -Wall -mwindows
LDFLAGS = 

TARGETS = ../launch-vscode.exe ../launch-wezterm.exe

all: $(TARGETS)

../launch-vscode.exe: launcher.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

../launch-wezterm.exe: launcher.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS)

.PHONY: all clean

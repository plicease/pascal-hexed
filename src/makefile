# HEXED, Free Pascal build.
#
#   make                    build ../build/hexed (with its help and config)
#   make install            install under $(PREFIX) (default /usr/local)
#   make win64              cross compile ../build/hexed.exe (needs the
#                           win64 RTL and rtl-console units installed)
#
# the old Turbo Pascal build was "tpc -B hexed"; see the git history.

FPC=fpc
FPCFLAGS=-Mtp -O2 -Xs
BUILD=../build
PREFIX=/usr/local
DATA=hexed.hlp hexed.cfg

all: hexed

hexed:
	mkdir -p $(BUILD)/units
	$(FPC) $(FPCFLAGS) -FU$(BUILD)/units -o$(BUILD)/hexed hexed.pas
	cp $(DATA) $(BUILD)/

win64:
	mkdir -p $(BUILD)/units-win64
	$(FPC) -Twin64 -Px86_64 $(FPCFLAGS) -FU$(BUILD)/units-win64 -o$(BUILD)/hexed.exe hexed.pas
	cp $(DATA) $(BUILD)/

# hexed looks for its help and config files next to the executable, so
# they all go in one directory with a link from bin
install: hexed
	mkdir -p $(DESTDIR)$(PREFIX)/lib/hexed $(DESTDIR)$(PREFIX)/bin
	cp $(BUILD)/hexed $(DATA) $(DESTDIR)$(PREFIX)/lib/hexed/
	ln -sf ../lib/hexed/hexed $(DESTDIR)$(PREFIX)/bin/hexed

clean:
	rm -rf $(BUILD)

.PHONY: all hexed win64 install clean

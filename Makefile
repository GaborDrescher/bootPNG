# vim: set et ts=4 sw=4:
# -----------------------------------------------------------------------------
# 
#                              M A K E F I L E
# 
# Zum Uebungsbetriebssystem OO/MP-StuBS der Lehrveranstaltung Betriebssysteme.
# -----------------------------------------------------------------------------
#
# Durch Eingabe von 'make' werden die Quelltexte des Systems kompiliert.
# Es gibt Targets in jeweils zwei Varianten, <name> und <name>-noopt.
# Targets mit dem Suffix -noopt werden ohne Optimierungen kompiliert. Dies
# kann sich z.B. für das Debugging mit gdb eignen.
#
# Folgende Targets sind verfügbar (jeweils auch mit -noopt):
# all:      Das System wird gebaut und liegt anschließend als ELF-Binary vor.
#
# kvm:      KVM wird gestartet und führt euer System in einer
#           Hardware-Beschleunigten virtuellen Maschine aus. Dieses Target ruft
#           aus Sicherhietsgründen ein CIP-Pool spezifisches Script auf.
#
# netboot:  Das System wird in das Netzwerkverzeichnis kopiert und kann auf den
#           Testrechner gestartet werden
#
# qemu:     QEMU wird gestartet und führt euer System aus. Da QEMU langsamer
#           ist als KVM treten hier u.U. andere Fehler hervor als in KVM oder
#           auf der Hardware.
#
# qemu-gdb: QEMU wird mit aktiviertem GDB-Stub gestartet und eine GDB-Instanz
#           angehängt, damit lässt sich euer System Schritt für Schritt
#           debuggen
#
# qemu-ddd: Wie qemu-gdb nur dient hier DDD als Frontend.
#
# -----------------------------------------------------------------------------
# Rewrite 02/2014: gabor
# -----------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Default target

.DEFAULT_GOAL = all

# --------------------------------------------------------------------------
# Zu uebersetzende Quelldateien (Wichtig: vor common.mk definieren!)
CC_SOURCES = $(shell find . -name "*.cc")
C_SOURCES = $(shell find . -name "*.c")
ASM_SOURCES = $(shell find . -name "*.asm" -and ! -name "startup.asm")
STARTUP_SOURCE = startup.asm
STARTUP_OBJECT = $(OBJDIR)/_startup.o

# --------------------------------------------------------------------------
# Globale Variablen und Standard-Rezepte einbinden
include common.mk

# -----------------------------------------------------------------------------
# Parameter:
QEMUKERNEL = $(OBJDIR)/system

all: $(QEMUKERNEL)

# Rezept zum Linken des Systemimages
$(QEMUKERNEL): $(STARTUP_OBJECT) $(OBJPRE) $(MAKEFILE_LIST)
	@echo "LD		$@"
	@if test \( ! \( -d $(@D) \) \) ;then mkdir -p $(@D);fi
	$(VERBOSE) $(LD) -Wl,-e,mystart -Wl,-T,boot/sections.ld $(LDFLAGS) $(CXXFLAGS) -o $(QEMUKERNEL) $(STARTUP_OBJECT) $(LDHEAD) $(OBJPRE) $(LDTAIL)
	objcopy -O binary  --set-section-flags .bss=alloc,load,contents build/system system.bin
	cat system.bin tmp/crc tmp/footer > tmp/out.png 
	qemu-system-x86_64 -kernel tmp/out.png -serial stdio -no-reboot

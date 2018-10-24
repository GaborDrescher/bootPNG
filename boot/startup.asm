; vim: set et ts=4 sw=4:

;******************************************************************************
;* Betriebssysteme                                                            *
;*----------------------------------------------------------------------------*
;*                                                                            *
;*                        S T A R T U P . A S M                               *
;*                                                                            *
;*----------------------------------------------------------------------------*
;* 'startup' ist der Eintrittspunkt des eigentlichen Systems. Die Umschaltung *
;* in den 'Protected Mode' ist bereits erfolgt. Es wird alles vorbereitet,    *
;* damit so schnell wie moeglich die weitere Ausfuehrung durch C/C++-Code     *
;* erfolgen kann.                                                             *
;******************************************************************************

; Multiboot-Konstanten
MULTIBOOT_PAGE_ALIGN equ 1<<0
MULTIBOOT_MEMORY_INFO equ 1<<1
MULTIBOOT_AOUT_KLUDGE equ  0x00010000
MULTIBOOT_HEADER_MAGIC equ 0x1badb002
MULTIBOOT_HEADER_FLAGS equ MULTIBOOT_PAGE_ALIGN | MULTIBOOT_MEMORY_INFO | MULTIBOOT_AOUT_KLUDGE
MULTIBOOT_HEADER_CHKSUM equ -(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS)
MULTIBOOT_START_ADDRESS equ 0x1000000
INIT_STACK_SIZE equ (4096*16)

; Deskriptoren global machen für realmode.asm
;[GLOBAL idt_desc_global]

; Globaler Einsprungspunkt für das System
[GLOBAL startup]
[GLOBAL mystart]
[GLOBAL bumpStart]

; externe Funktionen und Variablen, die hier benötigt werden
;[EXTERN guardian] ; Wird zur Interruptbehandlung aufgerufen
[EXTERN kernel_init] ; Wird zur Interruptbehandlung aufgerufen
[EXTERN gdt_desc_global]        ; Der "Pointer" zur globalen Deskriptortabelle (machine/gdt.cc)
[EXTERN ___BSS_START___]
[EXTERN ___IMG_END___]

[SECTION .text]

startup:

; png header
db 0x89
db 0x50
db 0x4E
db 0x47
db 0x0D
db 0x0A
db 0x1A
db 0x0A
db 0x00
db 0x00
db 0x00
db 0x0D
db 0x49
db 0x48
db 0x44
db 0x52
db 0x00
db 0x00
db 0x00
db 0xF0
db 0x00
db 0x00
db 0x01
db 0x40
db 0x08
db 0x00
db 0x00
db 0x00
db 0x00
db 0xA7
db 0x83
db 0xAE
db 0x8F

dd 0 ; TODO length of this chunk
dd 0 ; TODO type of this chunk

align 4
mystart:
	jmp skip_multiboot_hdr

; multiboot header
align 4
multiboot_header:
	dd MULTIBOOT_HEADER_MAGIC
	dd MULTIBOOT_HEADER_FLAGS
	dd MULTIBOOT_HEADER_CHKSUM

	dd multiboot_header
	dd startup; png start
	dd ___IMG_END___ + 31546 ; png end
	dd ___IMG_END___ + 31546 ; png end
	dd mystart ; entry symbol


skip_multiboot_hdr:

; Unterbrechungen sperren
	cli
; NMI verbieten
	mov al, 0x80
	out 0x70, al

    ;mov dword [ap_stack], init_stack + INIT_STACK_SIZE

; GDT setzen
	lgdt [gdt_desc_global]
; Unterbrechungsbehandlung sicherstellen
    ;lidt [idt_desc_global]

; Datensegmentregister initialisieren
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

; cs Segment Register neu laden
	jmp 0x8:load_cs

load_cs:

; Stackpointer initialisieren
	mov eax, ___IMG_END___
	add eax, 31546 + 4096 + 4096
	and eax, 0xfffff000
	add eax, INIT_STACK_SIZE
	mov [bumpStart], eax
	mov esp, eax
; Richtung für String-Operationen festlegen
	cld

; Wechsel in C/C++
    jmp kernel_init


;Unterbrechungsbehandlungen

;; Spezifischer Kopf der Unterbrechungsbehandlungsroutinen
;; wird in einer Macro-Schleife automatisch erzeugt.
;%macro wrapper 1
;align 8
;wrapper_%1:
;	push eax
;	mov al, %1
;	jmp wrapper_body
;%endmacro
;
;%assign i 0
;%rep 256
;wrapper i
;%assign i i+1
;%endrep
;
;; Gemeinsamer Rumpf
;align 8
;wrapper_body:
;    cld ; Richtung für String-Operationen festlegen
;    push ecx ; Sichern der restlichen flüchtigen Register
;    push edx
;    and eax, 0xff ; Der generierte Wrapper liefert nur 8 Bits
;    push eax ; Nummer der Unterbrechung übergeben
;    ;call guardian
;    add esp, 4 ; Parameter vom Stack entfernen
;    pop edx ; flüchtige Register wieder herstellen
;    pop ecx
;    pop eax
;    iret
;
;[SECTION .data]
;
;;  'interrupt descriptor table' mit 256 Eintraegen.
;align 4 
;idt:
;%macro idt_entry 1
;	dw (wrapper_%1 - startup + MULTIBOOT_START_ADDRESS) & 0xffff
;	dw 0x0008
;    	dw	0x8e00
;	dw ((wrapper_%1 - startup + MULTIBOOT_START_ADDRESS) & 0xffff0000) >> 16
;%endmacro
;
;%assign i 0
;%rep 256
;idt_entry i
;%assign i i+1
;%endrep
;
;idt_desc_global:
;	dw	256*8-1		; idt enthaelt 256 Eintraege
;	dd	idt


[SECTION .data]
align 4 
bumpStart:
	dd 0

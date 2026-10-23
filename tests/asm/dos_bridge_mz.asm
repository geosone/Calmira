; SPDX-License-Identifier: GPL-3.0-or-later
; Minimal MZ, no CRT startup and no protected-mode extender.
.model small
.stack 1024
.data
filename db 'C:\MZENTRY.LOG', 0
.code
ifdef PAD_ENTRY
    db 512 dup(90h)
endif
start:
    mov dx, 0e9h
    mov al, 'Z'
    out dx, al
    mov ax, @data
ifdef FOUR_RELOCS
    mov bx, @data
    mov cx, @data
    mov di, @data
endif
    mov ds, ax
    mov dx, offset filename
    xor cx, cx
    mov ah, 3ch
    int 21h
    jc failed
    mov bx, ax
    mov ah, 3eh
    int 21h
    mov ax, 4c00h
    int 21h
failed:
    mov ax, 4c01h
    int 21h
ifdef LARGE_IMAGE
    db 8192 dup(90h)
endif
end start

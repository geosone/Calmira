; SPDX-License-Identifier: GPL-3.0-or-later
; No C runtime, archive parser or protected-mode extender is involved.
.model tiny
.code
org 100h
start:
    mov dx, offset filename
    xor cx, cx
    mov ah, 3ch
    int 21h
    jc failed
    mov bx, ax
    mov dx, offset text
    mov cx, text_end - text
    mov ah, 40h
    int 21h
    mov ah, 3eh
    int 21h
    mov ax, 4c00h
    int 21h
failed:
    mov ax, 4c01h
    int 21h
filename db 'C:\TINY.LOG', 0
text db 'entered real-mode COM', 13, 10
text_end:
end start

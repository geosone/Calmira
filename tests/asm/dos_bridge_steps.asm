; SPDX-License-Identifier: GPL-3.0-or-later
; Separate real-mode startup primitives using marker files, no CRT.
.model tiny
.code
org 100h
start:
    mov dx, offset before
    call marker
    mov ah, 30h
    int 21h
    mov dx, offset version_done
    call marker
    mov sp, 0ff0h
    push cs
    pop es
    mov bx, 100h
    mov ah, 4ah
    int 21h
    jc failed
    mov dx, offset shrink_done
    call marker
    mov ax, 4c00h
    int 21h
failed:
    mov ax, 4c01h
    int 21h
marker proc near
    xor cx, cx
    mov ah, 3ch
    int 21h
    jc done
    mov bx, ax
    mov ah, 3eh
    int 21h
done:
    ret
marker endp
before db 'C:\STEP0.LOG', 0
version_done db 'C:\STEP1.LOG', 0
shrink_done db 'C:\STEP2.LOG', 0
end start

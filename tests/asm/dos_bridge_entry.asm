; SPDX-License-Identifier: GPL-3.0-or-later
; Optional diagnostic entry trampoline, preserving the DOS loader registers.
.model small
.code
extrn _cstart_:near
public TraceEntry
TraceEntry proc near
    pushf
    push ax
    push dx
    push cx
    mov dx, 0e9h
    mov al, 'S'
    out dx, al
    mov ax, cs
    call WriteHex
    mov al, 'R'
    out dx, al
    ; Verify and report the installed cstart's MOV CX,DGROUP immediate.
    ; Relative offset checked against the extracted clibs.lib startup object.
    cmp byte ptr cs:[_cstart_+3ah], 0b9h
    jne unknown_layout
    mov ax, word ptr cs:[_cstart_+3bh]
    call WriteHex
    jmp short newline
unknown_layout:
    mov al, '?'
    out dx, al
newline:
    mov al, 10
    out dx, al
    pop cx
    pop dx
    pop ax
    popf
    jmp _cstart_
TraceEntry endp
WriteHex proc near
    mov cx, 4
next_digit:
    rol ax, 1
    rol ax, 1
    rol ax, 1
    rol ax, 1
    push ax
    and al, 0fh
    add al, '0'
    cmp al, '9'
    jbe emit
    add al, 7
emit:
    out dx, al
    pop ax
    loop next_digit
    ret
WriteHex endp
end

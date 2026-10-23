; SPDX-License-Identifier: GPL-3.0-or-later
; Linux i386 probe: compare ENTER imm16 stack allocation with native execution.
; nasm -f elf32 ... ; ld -m elf_i386 ... ; run natively and with qemu-i386.
bits 32
global _start
section .text
_start:
    mov esp, stack_top
%macro sample 2
    enter %1, 0
    mov eax, ebp
    sub eax, esp
    leave
    mov [allocation + %2 * 4], eax
%endmacro
    sample 7fffh, 0
    sample 8000h, 1
    sample 846ch, 2
    sample 0ffffh, 3
    mov eax, 4                  ; four little-endian allocation counts
    mov ebx, 1
    mov ecx, allocation
    mov edx, 16
    int 80h
    mov eax, 1
    xor ebx, ebx
    cmp dword [allocation], 7fffh
    jne failed
    cmp dword [allocation + 4], 8000h
    jne failed
    cmp dword [allocation + 8], 846ch
    jne failed
    cmp dword [allocation + 12], 0ffffh
    je finished
failed:
    inc ebx
finished:
    int 80h
section .bss
align 16
allocation: resd 4
stack: resb 20000h
stack_top:

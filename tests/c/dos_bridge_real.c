/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <stdio.h>
#include <i86.h>
#include <dos.h>
#include <string.h>
#include <stdlib.h>
static void mark(char value);
#pragma aux mark = "mov dx,0e9h" "out dx,al" __parm [__al] __modify [__dx]
#ifdef BRIDGE_TRACE_INIT
/* Watcom's documented XI ABI: near callback, ascending 8-bit priority.
 * Match the 16-bit small-code layout in bld/watcom/h/rtinit.h. */
#pragma pack(push, 1)
struct InitProbe { unsigned char kind, priority; void (*callback)(void); unsigned padding; };
#pragma pack(pop)
typedef char init_probe_must_be_six_bytes[sizeof(struct InitProbe) == 6 ? 1 : -1];
static void init0(void) { mark('0'); }
static void init11(void) { mark('1'); }
static void init31(void) { mark('2'); }
static void init33(void) { mark('3'); }
static void init255(void) { mark('4'); }
struct InitProbe __based(__segname("XI")) trace0 = { 0, 0, init0, 0 };
struct InitProbe __based(__segname("XI")) trace11 = { 0, 11, init11, 0 };
struct InitProbe __based(__segname("XI")) trace31 = { 0, 31, init31, 0 };
struct InitProbe __based(__segname("XI")) trace33 = { 0, 33, init33, 0 };
struct InitProbe __based(__segname("XI")) trace255 = { 0, 255, init255, 0 };
#endif
int main(void)
{
#if defined(BRIDGE_HEAP)
    void *block;
    mark('H');
    block = malloc(16);
    mark(block ? 'A' : 'F');
    free(block);
    mark('R');
    return 0;
#elif defined(BRIDGE_MINIMAL)
    mark('m');
    return 0;
#else
    union REGS in, out;
    FILE *log;
    mark('M');
    /* Mark main entry using ordinary AH=3Ch, before fopen can choose an LFN
     * or extended DOS API. The marker deliberately has no C stream IO. */
    memset(&in, 0, sizeof(in));
    in.h.ah = 0x3c; in.x.dx = (unsigned)"C:\\ENTRY.LOG";
    intdos(&in, &out);
    mark('I');
    if (!out.x.cflag) {
        in.h.ah = 0x3e; in.x.bx = out.x.ax; intdos(&in, &out);
    }
    log = fopen("C:\\REAL16.LOG", "w");
    mark('O');
    if (!log) return 1;
    fputs("entered real-mode MZ C runtime\n", log);
    mark('W');
    return fclose(log) ? 2 : 0;
#endif
}

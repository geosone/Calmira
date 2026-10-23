/* SPDX-License-Identifier: GPL-3.0-or-later
 * Budget upstream new/new[] and C allocations. CRT bookkeeping is separate. */
#include <stdlib.h>
#include <string.h>
#include <new>
#define ARC_HEAP_LIMIT (8UL * 1024 * 1024)
union ArcAllocation {
    struct { size_t size; } info;
    long double alignment;
    void *pointer;
};
static size_t heap_used;
static unsigned blocks;
extern "C" void *arc_mem_alloc(size_t size)
{
    ArcAllocation *header;
    if (!size) size = 1;
    if (size > ARC_HEAP_LIMIT - sizeof(ArcAllocation) ||
        heap_used > ARC_HEAP_LIMIT - size - sizeof(ArcAllocation) || blocks >= 16384) return NULL;
    header = (ArcAllocation *)malloc(size + sizeof(ArcAllocation));
    if (!header) return NULL;
    header->info.size = size + sizeof(ArcAllocation);
    heap_used += header->info.size; blocks++;
    return header + 1;
}
extern "C" void arc_mem_free(void *pointer)
{
    ArcAllocation *header;
    if (!pointer) return;
    header = (ArcAllocation *)pointer - 1;
    heap_used -= header->info.size; blocks--;
    free(header);
}
extern "C" void *arc_mem_realloc(void *pointer, size_t size)
{
    void *replacement;
    size_t previous;
    if (!pointer) return size ? arc_mem_alloc(size) : NULL;
    if (!size) { arc_mem_free(pointer); return NULL; }
    previous = ((ArcAllocation *)pointer - 1)->info.size - sizeof(ArcAllocation);
    replacement = arc_mem_alloc(size);
    if (replacement) {
        memcpy(replacement, pointer, size < previous ? size : previous);
        arc_mem_free(pointer);
    }
    return replacement;
}
void *operator new(size_t size)
{
    void *p = arc_mem_alloc(size);
    if (!p) throw std::bad_alloc();
    return p;
}
void *operator new[](size_t size) { return ::operator new(size); }
void operator delete(void *p) throw() { arc_mem_free(p); }
void operator delete[](void *p) throw() { arc_mem_free(p); }

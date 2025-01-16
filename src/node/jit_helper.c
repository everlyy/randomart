#include <sys/mman.h>
#include <stdlib.h>
#include <string.h>

void* jit_setup(void* code, unsigned long sz) {
    void* result = mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
    if(!result)
        return NULL;

    memcpy(result, code, sz);
    mprotect(result, sz, PROT_READ | PROT_EXEC);
    return result;
}

void jit_free(void* code, unsigned long sz) {
    munmap(code, sz);
}

#include "CSwiftLogAndroidSupport.h"

void *shim_stdout(void) {
    return stdout;
}

void *shim_stderr(void) {
    return stderr;
}

void shim_flockfile(void *file) {
    flockfile(file);
}

void shim_funlockfile(void *file) {
    funlockfile(file);
}

size_t shim_fwrite(const void *ptr, size_t size, size_t count, void *file) {
    return fwrite(ptr, size, count, file);
}

int shim_fflush(void *file) {
    return fflush(file);
}

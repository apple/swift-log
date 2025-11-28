#ifndef SWIFT_LOG_ANDROID_SUPPORT_H
#define SWIFT_LOG_ANDROID_SUPPORT_H

#include <stdio.h>

// These C functions will be called from Swift. They provide a stable
// interface, hiding the pointer type differences between Android versions.

void *shim_stdout(void);
void *shim_stderr(void);

void shim_flockfile(void *file);
void shim_funlockfile(void *file);
size_t shim_fwrite(const void *ptr, size_t size, size_t count, void *file);
int shim_fflush(void *file);

#endif // SWIFT_LOG_ANDROID_SUPPORT_H

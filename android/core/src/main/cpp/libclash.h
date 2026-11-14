#ifndef LIBCLASH_H
#define LIBCLASH_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint8_t startTUN(int fd, void* callback);
void stopTun();
void suspend(int suspended);
void registerCallbacks(void (*protect)(void*, int), const char* (*resolve)(void*, int, const char*, const char*, int), void (*release)(void*));

#ifdef __cplusplus
}
#endif

#endif

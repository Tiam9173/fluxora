#ifndef LIBCLASH_H
#define LIBCLASH_H

#ifdef __cplusplus
extern "C" {
#endif

void startTUN(int fd, void* callback);
void stopTun();
void suspend(int suspended);
void registerCallbacks(void (*protect)(void*, int), const char* (*resolve)(void*, int, const char*, const char*, int), void (*release)(void*));

#ifdef __cplusplus
}
#endif

#endif

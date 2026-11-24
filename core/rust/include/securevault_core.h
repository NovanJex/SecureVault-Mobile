#ifndef SECUREVAULT_CORE_H
#define SECUREVAULT_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Unified C-ABI JSON entrypoint for Android (JNI), iOS (Swift C-ABI), and HarmonyOS NEXT (NAPI).
 * Returns a newly allocated UTF-8 JSON string:
 *   {"ok": true, "data": ...} or {"ok": false, "error": "..."}
 * Caller MUST free the returned pointer with sv_free_string().
 */
char* sv_invoke(const char* cmd_ptr, const char* args_json_ptr);

/**
 * Frees a UTF-8 C string returned by sv_invoke().
 */
void sv_free_string(char* ptr);

#ifdef __cplusplus
}
#endif

#endif /* SECUREVAULT_CORE_H */

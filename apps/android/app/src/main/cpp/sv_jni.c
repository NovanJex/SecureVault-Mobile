#include <jni.h>
#include "securevault_core.h"

JNIEXPORT jstring JNICALL
Java_app_suoxia_vault_bridge_RustCore_svInvoke(
    JNIEnv* env,
    jobject thiz,
    jstring cmd,
    jstring args_json
) {
    (void)thiz;
    const char* c_cmd = (*env)->GetStringUTFChars(env, cmd, NULL);
    const char* c_args = (*env)->GetStringUTFChars(env, args_json, NULL);
    char* raw = sv_invoke(c_cmd, c_args);
    jstring out = (*env)->NewStringUTF(env, raw ? raw : "{\"ok\":false,\"error\":\"ERR_NULL\"}");
    if (raw) {
        sv_free_string(raw);
    }
    (*env)->ReleaseStringUTFChars(env, cmd, c_cmd);
    (*env)->ReleaseStringUTFChars(env, args_json, c_args);
    return out;
}

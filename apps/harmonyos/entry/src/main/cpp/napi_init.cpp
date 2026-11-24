#include "napi/native_api.h"
#include "securevault_core.h"
#include <string>

static std::string GetStringArg(napi_env env, napi_value val) {
  size_t len = 0;
  napi_get_value_string_utf8(env, val, nullptr, 0, &len);
  std::string out(len, '\0');
  if (len > 0) {
    napi_get_value_string_utf8(env, val, &out[0], len + 1, &len);
  }
  return out;
}

static napi_value SvInvoke(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 2) {
    napi_value empty;
    napi_create_string_utf8(env, "{\"ok\":false,\"error\":\"ERR_ARGS\"}", NAPI_AUTO_LENGTH, &empty);
    return empty;
  }
  std::string cmd = GetStringArg(env, args[0]);
  std::string jsonArgs = GetStringArg(env, args[1]);
  char* raw = sv_invoke(cmd.c_str(), jsonArgs.c_str());
  napi_value result;
  napi_create_string_utf8(env, raw ? raw : "{\"ok\":false,\"error\":\"ERR_NULL\"}", NAPI_AUTO_LENGTH, &result);
  if (raw) {
    sv_free_string(raw);
  }
  return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
      {"svInvoke", nullptr, SvInvoke, nullptr, nullptr, nullptr, napi_default, nullptr}
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
  return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "suoxia_napi",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterSuoxiaModule(void) {
  napi_module_register(&demoModule);
}

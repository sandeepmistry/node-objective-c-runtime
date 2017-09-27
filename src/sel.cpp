// Copyright (c) Sandeep Mistry. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <objc/runtime.h>

#include "napi.h"

// SEL sel_registerName(const char *str)
napi_value RegisterName(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 1) {
    napi_throw_type_error(env, NULL, "Expected 'str' argument!");
    return nullptr;
  }

  napi_valuetype valuetype0;
  napi_typeof(env, args[0], &valuetype0);

  if (valuetype0 != napi_string) {
    napi_throw_type_error(env, NULL, "Expected 'str' argument to be a string!");
    return nullptr;
  }

  size_t strlen = 0;
  napi_get_value_string_utf8(env, args[0], NULL, 0, &strlen);

  char str[strlen + 1];
  napi_get_value_string_utf8(env, args[0], str, sizeof(str), &strlen);

  SEL sel = sel_registerName(str);

  if (sel == NULL) {
    return nullptr;
  }

  napi_value result;
  napi_create_int64(env, (int64_t)sel, &result);

  return result;
}

#define DECLARE_NAPI_METHOD(name, func)                          \
  { name, 0, func, 0, 0, 0, napi_default, 0 }

void Init(napi_env env, napi_value exports, napi_value module, void* priv) {
  napi_status status;

  napi_property_descriptor registerName = DECLARE_NAPI_METHOD("registerName", RegisterName);

  const napi_property_descriptor properties[] = {
    registerName,
  };

  status = napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
  assert(status == napi_ok);
}

NAPI_MODULE(addon, Init)

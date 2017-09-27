// Copyright (c) Sandeep Mistry. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <dlfcn.h>

#include "napi.h"

// void* dlopen(const char* path, int mode);
napi_value Open(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 1) {
    napi_throw_type_error(env, NULL, "Expected 'path' argument!");
    return nullptr;
  }

  napi_valuetype valuetype0;
  napi_typeof(env, args[0], &valuetype0);

  if (valuetype0 != napi_string) {
    napi_throw_type_error(env, NULL, "Expected 'path' argument to be a string!");
    return nullptr;
  }

  size_t pathlen = 0;
  napi_get_value_string_utf8(env, args[0], NULL, pathlen, &pathlen);

  char path[pathlen + 1];
  napi_get_value_string_utf8(env, args[0], path, sizeof(path), &pathlen);

  int64_t mode = RTLD_LAZY;

  if (argc > 1) {
    napi_valuetype valuetype1;
    napi_typeof(env, args[1], &valuetype1);

    if (valuetype1 != napi_number) {
      napi_throw_type_error(env, NULL, "Expected 'mode' argument to be a number!");
      return nullptr;
    }

    napi_get_value_int64(env, args[1], &mode);
  }

  void* dl = dlopen(path, mode);

  napi_value result;
  napi_create_int64(env, (int64_t)dl, &result);

  return result;
}

#define DECLARE_NAPI_METHOD(name, func)                          \
  { name, 0, func, 0, 0, 0, napi_default, 0 }

void Init(napi_env env, napi_value exports, napi_value module, void* priv) {
  napi_status status;

  napi_property_descriptor _open = DECLARE_NAPI_METHOD("open", Open);

  const napi_property_descriptor properties[] = {
    _open
  };

  status = napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
  assert(status == napi_ok);
}

NAPI_MODULE(addon, Init)

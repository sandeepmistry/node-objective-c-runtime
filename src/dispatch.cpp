// Copyright (c) Sandeep Mistry. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <dispatch/dispatch.h>

#include "napi.h"

// dispatch_queue_t dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);
napi_value QueueCreate(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 2) {
    napi_throw_type_error(env, NULL, "Expected 'label' and 'attr' arguments!");
    return nullptr;
  }

  napi_valuetype valuetype0;
  napi_typeof(env, args[0], &valuetype0);

  if (valuetype0 != napi_string) {
    napi_throw_type_error(env, NULL, "Expected 'label' argument to be a string!");
    return nullptr;
  }

  napi_valuetype valuetype1;
  napi_typeof(env, args[1], &valuetype1);

  if (valuetype1 != napi_number) {
    napi_throw_type_error(env, NULL, "Expected 'attr' argument to be a number!");
    return nullptr;
  }

  size_t labellen = 0;
  napi_get_value_string_utf8(env, args[0], NULL, 0, &labellen);

  char label[labellen + 1];
  napi_get_value_string_utf8(env, args[0], label, sizeof(label), &labellen);

  dispatch_queue_attr_t attr = 0;
  napi_get_value_int64(env, args[1], (int64_t*)&attr);

  dispatch_queue_t q = dispatch_queue_create(label, attr);

  if (q == NULL) {
    return nullptr;
  }

  napi_value result;
  napi_create_buffer_copy(env, sizeof(q), &q, NULL, &result);

  return result;
}

#define DECLARE_NAPI_METHOD(name, func)                          \
  { name, 0, func, 0, 0, 0, napi_default, 0 }

void Init(napi_env env, napi_value exports, napi_value module, void* priv) {
  napi_status status;

  napi_property_descriptor queueCreate = DECLARE_NAPI_METHOD("queue_create", QueueCreate);

  const napi_property_descriptor properties[] = {
    queueCreate,
  };

  status = napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
  assert(status == napi_ok);
}

NAPI_MODULE(addon, Init)

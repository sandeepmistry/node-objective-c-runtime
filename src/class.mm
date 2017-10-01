// Copyright (c) Sandeep Mistry. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <objc/runtime.h>

#include <map>
#include <tuple>

#import <Foundation/Foundation.h>

#include <uv.h>

#include "napi.h"

static uv_thread_t mainThread;
static uv_async_t  callbackHandle;

static id          callbackSelf;
static SEL         callbackCmd;
static va_list     callbackValist;

static uv_mutex_t  methodWrapperMutex;
static uv_sem_t    returnValueSemaphore;

static std::map<std::pair<Class, SEL>, std::tuple<napi_env, napi_ref>> callbacks;

// const char *class_getName(Class cls)
napi_value GetName(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 1) {
    napi_throw_type_error(env, NULL, "Expected 'cls' argument!");
    return nullptr;
  }

  bool valuetype0isbuffer = false;
  napi_is_buffer(env, args[0], &valuetype0isbuffer);

  if (!valuetype0isbuffer) {
    napi_throw_type_error(env, NULL, "Expected 'cls' argument to be a buffer!");
    return nullptr;
  }

  void* clsData;
  size_t clsLength;
  napi_get_buffer_info(env, args[0], &clsData, &clsLength);

  Class cls;
  memcpy(&cls, clsData, sizeof(cls));

  const char* name = class_getName(cls);

  napi_value result;
  napi_create_string_utf8(env, name, -1, &result);

  return result;
}

// Method class_getClassMethod(Class cls, SEL name)
napi_value GetClassMethod(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 2) {
    napi_throw_type_error(env, NULL, "Expected 'cls' and 'name' arguments!");
    return nullptr;
  }

  bool valuetype0isbuffer = false;
  napi_is_buffer(env, args[0], &valuetype0isbuffer);

  if (!valuetype0isbuffer) {
    napi_throw_type_error(env, NULL, "Expected 'cls' argument to be a buffer!");
    return nullptr;
  }

  bool valuetype1isbuffer = false;
  napi_is_buffer(env, args[1], &valuetype1isbuffer);

  if (!valuetype1isbuffer) {
    napi_throw_type_error(env, NULL, "Expected 'name' argument to be a buffer!");
    return nullptr;
  }

  void* clsData;
  size_t clsLength;
  napi_get_buffer_info(env, args[0], &clsData, &clsLength);

  Class cls;
  memcpy(&cls, clsData, sizeof(cls));

  void* nameData;
  size_t nameLength;
  napi_get_buffer_info(env, args[1], &nameData, &nameLength);

  SEL name;
  memcpy(&name, nameData, sizeof(name));

  Method method = class_getClassMethod(cls, name);

  if (method == NULL) {
    return nullptr;
  }

  napi_value result;
  napi_create_int64(env, (int64_t)method, &result);

  return result;
}

void callbackExecutor(uv_async_t* handle) {
  Class cls = [callbackSelf class];

  napi_env env;
  napi_ref cbref;

  std::tie (env, cbref) = callbacks[std::make_pair(cls, callbackCmd)];

  napi_handle_scope scope;
  napi_open_handle_scope(env, &scope);

  napi_value cb;
  napi_get_reference_value(env, cbref, &cb);

  Method method = class_getInstanceMethod(cls, callbackCmd);
  const char* methodEncoding = method_getTypeEncoding(method);
  NSMethodSignature* methodSignature = [NSMethodSignature signatureWithObjCTypes:methodEncoding];
  size_t numberOfArguments = methodSignature.numberOfArguments;
  const char* methodReturnType = methodSignature.methodReturnType;

  napi_value argv[numberOfArguments];

  napi_create_buffer_copy(env, sizeof(callbackSelf), &callbackSelf, NULL, &argv[0]);
  napi_create_buffer_copy(env, sizeof(callbackCmd), &callbackCmd, NULL, &argv[1]);

  for (size_t i = 2; i < numberOfArguments; i++) {
    const char* argumentType = [methodSignature getArgumentTypeAtIndex:i];

    if (strcmp("@", argumentType) == 0) {
      id arg = va_arg(callbackValist, id);

      napi_create_buffer_copy(env, sizeof(arg), &arg, NULL, &argv[i]);
    } else {
      napi_fatal_error("callbackExecutor", [[NSString stringWithFormat:@"Unsupported argument type '%s'!", argumentType] UTF8String]);
      return;
    }
  }

  if (strcmp("v", methodReturnType) != 0) {
    napi_fatal_error("callbackExecutor", [[NSString stringWithFormat:@"Unsupported return type type '%s'!", methodReturnType] UTF8String]);
    return;
  }

  napi_value result;
  napi_call_function(env, cb, cb, numberOfArguments, argv, &result);

  napi_close_handle_scope(env, scope);
  uv_sem_post(&returnValueSemaphore);
}

id methodWrapper(id self, SEL cmd, ...) {
  uv_mutex_lock(&methodWrapperMutex);

  callbackSelf = self;
  callbackCmd = cmd;
  va_start(callbackValist, cmd);

  uv_thread_t currentThread = uv_thread_self();

  if (uv_thread_equal(&mainThread, &currentThread)) {
    // already on the main thread, call the callback
    callbackExecutor(NULL);
  } else {
    uv_async_send(&callbackHandle);
    uv_sem_wait(&returnValueSemaphore);
  }

  va_end(callbackValist);
  uv_mutex_unlock(&methodWrapperMutex);

  return nil;
}

// BOOL class_addMethod(Class cls, SEL name, IMP imp, const char *types)
napi_value AddMethod(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 4) {
    napi_throw_type_error(env, NULL, "Expected 'cls', 'name', 'imp', and 'types' arguments!");
    return nullptr;
  }

  bool valuetype0isbuffer = false;
  napi_is_buffer(env, args[0], &valuetype0isbuffer);

  if (!valuetype0isbuffer) {
    napi_throw_type_error(env, NULL, "Expected 'cls' argument to be a buffer!");
    return nullptr;
  }

  bool valuetype1isbuffer = false;
  napi_is_buffer(env, args[1], &valuetype1isbuffer);

  if (!valuetype1isbuffer) {
    napi_throw_type_error(env, NULL, "Expected 'name' argument to be a buffer!");
    return nullptr;
  }

  napi_valuetype valuetype3;
  napi_typeof(env, args[3], &valuetype3);

  if (valuetype3 != napi_string) {
    napi_throw_type_error(env, NULL, "Expected 'types' argument to be a string!");
    return nullptr;
  }

  void* clsData;
  size_t clsLength;
  napi_get_buffer_info(env, args[0], &clsData, &clsLength);

  Class cls;
  memcpy(&cls, clsData, sizeof(cls));

  void* nameData;
  size_t nameLength;
  napi_get_buffer_info(env, args[1], &nameData, &nameLength);

  SEL name;
  memcpy(&name, nameData, sizeof(name));

  napi_value cb = args[2];

  size_t typeslen = 0;
  napi_get_value_string_utf8(env, args[3], NULL, 0, &typeslen);

  char types[typeslen + 1];
  napi_get_value_string_utf8(env, args[3], types, sizeof(types), &typeslen);

  BOOL added = class_addMethod(cls, name, methodWrapper, types);

  if (added) {
    napi_ref cbref;
    napi_create_reference(env, cb, 1, &cbref);

    callbacks[std::make_pair(cls, name)] = {env, cbref};
  }

  napi_value result;
  napi_get_boolean(env, added, &result);

  return result;
}

#define DECLARE_NAPI_METHOD(name, func)                          \
  { name, 0, func, 0, 0, 0, napi_default, 0 }

void Init(napi_env env, napi_value exports, napi_value module, void* priv) {
  napi_status status;

  napi_property_descriptor getName = DECLARE_NAPI_METHOD("getName", GetName);
  napi_property_descriptor getClassMethod = DECLARE_NAPI_METHOD("getClassMethod", GetClassMethod);
  napi_property_descriptor addMethod = DECLARE_NAPI_METHOD("addMethod", AddMethod);

  const napi_property_descriptor properties[] = {
    getName,
    getClassMethod,
    addMethod
  };

  status = napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
  assert(status == napi_ok);

  mainThread = uv_thread_self();
  uv_async_init(uv_default_loop(), &callbackHandle, callbackExecutor);
  uv_mutex_init(&methodWrapperMutex);
  uv_sem_init(&returnValueSemaphore, 0);
}

NAPI_MODULE(addon, Init)

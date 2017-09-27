// Copyright (c) Sandeep Mistry. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <objc/runtime.h>
#include <objc/message.h>

#import <Foundation/Foundation.h>

#include "napi.h"

// Class objc_getClass(const char *name)
napi_value GetClass(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 1) {
    napi_throw_type_error(env, NULL, "Expected 'name' argument!");
    return nullptr;
  }

  napi_valuetype valuetype0;
  napi_typeof(env, args[0], &valuetype0);

  if (valuetype0 != napi_string) {
    napi_throw_type_error(env, NULL, "Expected 'name' argument to be a string!");
    return nullptr;
  }

  size_t namelen = 0;
  napi_get_value_string_utf8(env, args[0], NULL, 0, &namelen);

  char name[namelen + 1];
  napi_get_value_string_utf8(env, args[0], name, sizeof(name), &namelen);

  Class c = objc_getClass(name);

  if (c == NULL) {
    return nullptr;
  }

  napi_value result;
  napi_create_int64(env, (int64_t)c, &result);

  return result;
}

// Class objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes)
napi_value AllocateClassPair(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 3) {
    napi_throw_type_error(env, NULL, "Expected 'superclass', 'name', and 'extraBytes' arguments!");
    return nullptr;
  }

  napi_valuetype valuetype0;
  napi_typeof(env, args[0], &valuetype0);

  if (valuetype0 != napi_number) {
    napi_throw_type_error(env, NULL, "Expected 'superclass' argument to be a number!");
    return nullptr;
  }

  napi_valuetype valuetype1;
  napi_typeof(env, args[1], &valuetype1);

  if (valuetype1 != napi_string) {
    napi_throw_type_error(env, NULL, "Expected 'name' argument to be a string!");
    return nullptr;
  }

  napi_valuetype valuetype2;
  napi_typeof(env, args[2], &valuetype2);

  if (valuetype2 != napi_number) {
    napi_throw_type_error(env, NULL, "Expected 'extraBytes' argument to be a number!");
    return nullptr;
  }

  Class superclass;
  napi_get_value_int64(env, args[0], (int64_t*)&superclass);

  size_t namelen = 0;
  napi_get_value_string_utf8(env, args[0], NULL, 0, &namelen);

  char name[namelen + 1];
  napi_get_value_string_utf8(env, args[0], name, sizeof(name), &namelen);

  size_t extraBytes = 0;
  napi_get_value_int64(env, args[2], (int64_t*)&extraBytes);

  Class c = objc_allocateClassPair(superclass, name, extraBytes);

  napi_value result;
  napi_create_int64(env, (int64_t)c, &result);

  return result;
}

#include <dispatch/dispatch.h>

// id objc_msgSend(id self, SEL op, ...)
napi_value MsgSend(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 2) {
    napi_throw_type_error(env, NULL, "Expected 'self' and 'op' arguments!");
    return nullptr;
  }

  napi_valuetype valuetype0;
  napi_typeof(env, args[0], &valuetype0);

  if (valuetype0 != napi_number) {
    napi_throw_type_error(env, NULL, "Expected 'self' argument to be a number!");
    return nullptr;
  }

  napi_valuetype valuetype1;
  napi_typeof(env, args[1], &valuetype1);

  if (valuetype1 != napi_number) {
    napi_throw_type_error(env, NULL, "Expected 'op' argument to be a number!");
    return nullptr;
  }

  id self;
  napi_get_value_int64(env, args[0], (int64_t*)&self);

  SEL op;
  napi_get_value_int64(env, args[1], (int64_t*)&op);

  Method method = object_isClass(self) ? class_getClassMethod(self, op) : class_getInstanceMethod([self class], op);

  if (method == NULL) {
    Class cls = object_isClass(self) ? (Class)self : [self class];

    napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Class `%s` does not respond to selector '%s'!", class_getName(cls), sel_getName(op)] UTF8String]);
    return nullptr;
  }

  const char* methodEncoding = method_getTypeEncoding(method);
  NSMethodSignature* methodSignature = [NSMethodSignature signatureWithObjCTypes:methodEncoding];
  size_t numberOfArguments = methodSignature.numberOfArguments;
  const char* methodReturnType = methodSignature.methodReturnType;

  if (argc < numberOfArguments) {
    napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Expected %lu arguments!", numberOfArguments] UTF8String]);
    return nullptr;
  }

  NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:methodSignature];

  invocation.target = self;
  invocation.selector = op;

  napi_value vargs[argc];

  napi_get_cb_info(env, info, &argc, vargs, nullptr, nullptr);

  for (size_t i = 2; i < numberOfArguments; i++) {
    const char* argumentType = [methodSignature getArgumentTypeAtIndex:i];

    napi_valuetype valuetype;
    napi_typeof(env, vargs[i], &valuetype);

    if (strcmp("r*", argumentType) == 0) {
      if (valuetype1 != napi_string) {
        napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Expected argument %lu to be a string!", (i + 1)] UTF8String]);
        return nullptr;
      }

      size_t strlen = 0;
      strlen = (size_t)napi_get_value_string_utf8(env, vargs[i], NULL, 0, &strlen);

      char* str = (char*)malloc(strlen);
      napi_get_value_string_utf8(env, vargs[i], str, strlen, &strlen);

      [invocation setArgument:&str atIndex:i];
    } else if (strcmp("Q", argumentType) == 0 || strcmp("@", argumentType) == 0) {
      if (valuetype1 != napi_number) {
        napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Expected argument %lu to be a number!", (i + 1)] UTF8String]);
        return nullptr;
      }

      int64_t num = 0;
      napi_get_value_int64(env, vargs[i], &num);

      [invocation setArgument:&num atIndex: i];
    } else {
      // TODO: other types from: https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100

      napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Unsupported argument type '%s'!", argumentType] UTF8String]);
      return nullptr;
    }
  }

  [invocation invoke];

  for (size_t i = 2; i < numberOfArguments; i++) {
    const char* argumentType = [methodSignature getArgumentTypeAtIndex:i];

    if (strcmp("r*", argumentType) == 0) {
      char* str = NULL;

      [invocation getArgument:&str atIndex: i];

      if (str != NULL) {
        free(str);
      }
    }
  }

  napi_value result = nullptr;

  if (strcmp("v", methodReturnType) == 0) {
    return nullptr;
  } else if (strcmp("@", methodReturnType) == 0 || strcmp("q", methodReturnType) == 0) {
    id returnValue;
    [invocation getReturnValue:&returnValue];

    napi_create_int64(env, (int64_t)returnValue, &result);
  } else {
    napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Unsupported return type '%s'!", methodReturnType] UTF8String]);
    return nullptr;
  }

  return result;
}

#define DECLARE_NAPI_METHOD(name, func)                          \
  { name, 0, func, 0, 0, 0, napi_default, 0 }

void Init(napi_env env, napi_value exports, napi_value module, void* priv) {
  napi_status status;

  napi_property_descriptor getClass = DECLARE_NAPI_METHOD("getClass", GetClass);
  napi_property_descriptor allocateClassPair = DECLARE_NAPI_METHOD("allocateClassPair", AllocateClassPair);
  napi_property_descriptor msgSend = DECLARE_NAPI_METHOD("msgSend", MsgSend);

  const napi_property_descriptor properties[] = {
    getClass,
    allocateClassPair,
    msgSend
  };

  status = napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
  assert(status == napi_ok);
}

NAPI_MODULE(addon, Init)

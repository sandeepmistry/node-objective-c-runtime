// Copyright (c) Sandeep Mistry. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <objc/runtime.h>
#include <objc/message.h>

#import <Foundation/Foundation.h>

#include <napi.h>

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

  Class cls = objc_getClass(name);

  if (cls == NULL) {
    return nullptr;
  }

  napi_value result;
  napi_create_buffer_copy(env, sizeof(cls), &cls, NULL, &result);

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

  bool valuetype0isbuffer = false;
  napi_is_buffer(env, args[0], &valuetype0isbuffer);

  if (!valuetype0isbuffer) {
    napi_throw_type_error(env, NULL, "Expected 'superclass' argument to be a buffer!");
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

  void* superclassData;
  size_t superclassLength;
  napi_get_buffer_info(env, args[0], &superclassData, &superclassLength);

  Class superclass;
  memcpy(&superclass, superclassData, sizeof(superclass));

  size_t namelen = 0;
  napi_get_value_string_utf8(env, args[1], NULL, 0, &namelen);

  char name[namelen + 1];
  napi_get_value_string_utf8(env, args[1], name, sizeof(name), &namelen);

  size_t extraBytes = 0;
  napi_get_value_int64(env, args[2], (int64_t*)&extraBytes);

  Class cls = objc_allocateClassPair(superclass, name, extraBytes);

  napi_value result;
  napi_create_buffer_copy(env, sizeof(cls), &cls, NULL, &result);

  return result;
}

// id objc_msgSend(id self, SEL op, ...)
napi_value MsgSend(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2];

  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  if (argc < 2) {
    napi_throw_type_error(env, NULL, "Expected 'self' and 'op' arguments!");
    return nullptr;
  }

  bool valuetype0isbuffer = false;
  napi_is_buffer(env, args[0], &valuetype0isbuffer);

  if (!valuetype0isbuffer) {
    napi_throw_type_error(env, NULL, "Expected 'self' argument to be a buffer!");
    return nullptr;
  }

  bool valuetype1isbuffer = false;
  napi_is_buffer(env, args[1], &valuetype1isbuffer);

  if (!valuetype1isbuffer) {
    napi_throw_type_error(env, NULL, "Expected 'op' argument to be a buffer!");
    return nullptr;
  }

  void* selfData;
  size_t selfLength;
  napi_get_buffer_info(env, args[0], &selfData, &selfLength);

  id self;
  memcpy(&self, selfData, sizeof(self));

  if (self == nil) {
    return nullptr;
  }

  void* opData;
  size_t opLength;
  napi_get_buffer_info(env, args[1], &opData, &opLength);

  SEL op;
  memcpy(&op, opData, sizeof(op));

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

    bool valueisbuffer = false;
    napi_is_buffer(env, vargs[i], &valueisbuffer);

    if (strcmp("r*", argumentType) == 0) {
      if (valuetype != napi_string) {
        napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Expected argument %lu to be a string!", (i + 1)] UTF8String]);
        return nullptr;
      }

      size_t strlen = 0;
      napi_get_value_string_utf8(env, vargs[i], NULL, 0, &strlen);

      char* str = (char*)malloc(strlen + 1);
      napi_get_value_string_utf8(env, vargs[i], str, strlen + 1, &strlen);

      [invocation setArgument:&str atIndex:i];
    } else if (strcmp("q", argumentType) == 0 || strcmp("Q", argumentType) == 0 || strcmp("i", argumentType) == 0) {
      if (valuetype != napi_number) {
        napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Expected argument %lu to be a number!", (i + 1)] UTF8String]);
        return nullptr;
      }

      int64_t num;
      napi_get_value_int64(env, vargs[i], &num);

      [invocation setArgument:&num atIndex: i];
    } else if (strcmp("c", argumentType) == 0) {
      if (valuetype != napi_boolean) {
        napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Expected argument %lu to be a boolean!", (i + 1)] UTF8String]);
        return nullptr;
      }

      bool b;
      napi_get_value_bool(env, vargs[i], &b);

      [invocation setArgument:&b atIndex: i];
    } else if (strcmp("@", argumentType) == 0) {
      if (!valueisbuffer && valuetype != napi_null) {
        napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Expected argument %lu to be a buffer!", (i + 1)] UTF8String]);
        return nullptr;
      }

      id obj = nil;

      if (valuetype != napi_null) {
        void* objData;
        size_t objLength;
        napi_get_buffer_info(env, vargs[i], &objData, &objLength);
        memcpy(&obj, objData, sizeof(obj));
      }

      [invocation setArgument:&obj atIndex: i];
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

  if (strcmp("v", methodReturnType) == 0 || strcmp("Vv", methodReturnType) == 0) {
    return nullptr;
  } else if (strcmp("r*", methodReturnType) == 0) {
    const char* returnValue;
    [invocation getReturnValue:&returnValue];

    napi_create_string_utf8(env, returnValue, -1, &result);
  } else if (strcmp("@", methodReturnType) == 0 || strcmp("#", methodReturnType) == 0) {
    id returnValue;
    [invocation getReturnValue:&returnValue];

    if (returnValue == nil) {
      napi_get_null(env, &result);
    } else {
      napi_create_buffer_copy(env, sizeof(returnValue), &returnValue, NULL, &result);
    }
  } else if (strcmp("q", methodReturnType) == 0 || strcmp("Q", methodReturnType) == 0) {
    int64_t returnValue;
    [invocation getReturnValue:&returnValue];

    napi_create_int64(env, returnValue, &result);
  } else if (strcmp("i", methodReturnType) == 0) {
    int returnValue;
    [invocation getReturnValue:&returnValue];

    napi_create_int64(env, returnValue, &result);
  } else if (strcmp("c", methodReturnType) == 0) {
    bool returnValue;
    [invocation getReturnValue:&returnValue];

    napi_get_boolean(env, returnValue, &result);
  } else {
    napi_throw_type_error(env, NULL, [[NSString stringWithFormat:@"Unsupported return type '%s'!", methodReturnType] UTF8String]);
    return nullptr;
  }

  return result;
}

napi_value GetClassList(napi_env env, napi_callback_info info) {
  napi_value result;

  int numClasses = objc_getClassList(NULL, 0);
  napi_create_array_with_length(env, numClasses, &result);

  Class classes[numClasses];
  numClasses = objc_getClassList(classes, numClasses);

  for (int i = 0; i < numClasses; i++) {
    const char* className = class_getName(classes[i]);

    napi_value value;
    napi_create_string_utf8(env, className, -1, &value);

    napi_set_element(env, result, i, value);
  }

  return result;
}

// void objc_registerClassPair(Class cls);
napi_value RegisterClassPair(napi_env env, napi_callback_info info) {
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

  objc_registerClassPair(cls);

  return nullptr;
}

#define DECLARE_NAPI_METHOD(name, func)                          \
  { name, 0, func, 0, 0, 0, napi_default, 0 }

napi_value__* Init(napi_env env, napi_value exports) {
  napi_status status;

  napi_property_descriptor getClass = DECLARE_NAPI_METHOD("getClass", GetClass);
  napi_property_descriptor allocateClassPair = DECLARE_NAPI_METHOD("allocateClassPair", AllocateClassPair);
  napi_property_descriptor msgSend = DECLARE_NAPI_METHOD("msgSend", MsgSend);
  napi_property_descriptor getClassList = DECLARE_NAPI_METHOD("getClassList", GetClassList);
  napi_property_descriptor registerClassPair = DECLARE_NAPI_METHOD("registerClassPair", RegisterClassPair);

  const napi_property_descriptor properties[] = {
    getClass,
    allocateClassPair,
    msgSend,
    getClassList,
    registerClassPair
  };

  status = napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
  assert(status == napi_ok);
}

NAPI_MODULE(addon, Init)

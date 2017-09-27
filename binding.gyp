# Copyright (c) Sandeep Mistry. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

{
  'targets': [
    {
      'target_name': 'class',
      'conditions': [
        ['OS=="mac"', {
          'sources': [
            'src/class.mm'
          ],
          'xcode_settings': {
            'CLANG_CXX_LIBRARY': 'libc++',
            'MACOSX_DEPLOYMENT_TARGET': '10.8'
          }
        }]
      ],
      'include_dirs': ["<!@(node -p \"require('node-addon-api').include\")"],
      'dependencies': ["<!(node -p \"require('node-addon-api').gyp\")"],
      'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ],
      "link_settings": {
        "libraries": ["/System/Library/Frameworks/Foundation.framework"]
      }
    },
    {
      'target_name': 'dispatch',
      'conditions': [
        ['OS=="mac"', {
          'sources': [
            'src/dispatch.cpp'
          ],
          'xcode_settings': {
            'CLANG_CXX_LIBRARY': 'libc++',
            'MACOSX_DEPLOYMENT_TARGET': '10.8'
          }
        }]
      ],
      'include_dirs': ["<!@(node -p \"require('node-addon-api').include\")"],
      'dependencies': ["<!(node -p \"require('node-addon-api').gyp\")"],
      'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ]
    },
    {
      'target_name': 'dl',
      'conditions': [
        ['OS=="mac"', {
          'sources': [
            'src/dl.cpp'
          ],
          'xcode_settings': {
            'CLANG_CXX_LIBRARY': 'libc++',
            'MACOSX_DEPLOYMENT_TARGET': '10.8'
          }
        }]
      ],
      'include_dirs': ["<!@(node -p \"require('node-addon-api').include\")"],
      'dependencies': ["<!(node -p \"require('node-addon-api').gyp\")"],
      'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ]
    },
    {
      'target_name': 'objc',
      'conditions': [
        ['OS=="mac"', {
          'sources': [
            'src/objc.mm'
          ],
          'xcode_settings': {
            'CLANG_CXX_LIBRARY': 'libc++',
            'MACOSX_DEPLOYMENT_TARGET': '10.8'
          }
        }]
      ],
      'include_dirs': ["<!@(node -p \"require('node-addon-api').include\")"],
      'dependencies': ["<!(node -p \"require('node-addon-api').gyp\")"],
      'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ],
      "link_settings": {
        "libraries": ["/System/Library/Frameworks/Foundation.framework"]
      }
    },
    {
      'target_name': 'sel',
      'conditions': [
        ['OS=="mac"', {
          'sources': [
            'src/sel.cpp'
          ],
          'xcode_settings': {
            'CLANG_CXX_LIBRARY': 'libc++',
            'MACOSX_DEPLOYMENT_TARGET': '10.8'
          }
        }]
      ],
      'include_dirs': ["<!@(node -p \"require('node-addon-api').include\")"],
      'dependencies': ["<!(node -p \"require('node-addon-api').gyp\")"],
      'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ]
    }
  ]
}

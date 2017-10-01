// Copyright (c) Sandeep Mistry. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

var fs = require('fs');
var util = require('util');

var ocr = require('./index');

var shim = function(value) {
  if (typeof(value) === 'string') {
    return shim.NSString('stringWithUTF8String', value);
  }

  return undefined;
}

function importFramework(framework) {
  var frameworkPath = util.format('/System/Library/Frameworks/%s.framework', framework);

  if (!fs.existsSync(frameworkPath)) {
    throw new Error(util.format('Framework %s not found', framework));
  }

  var dylibPath = util.format('%s/%s', frameworkPath, framework);

  var handle = ocr.dl.open(dylibPath);

  var classList = ocr.objc.getClassList();

  classList.forEach(function(className) {
    var classId = ocr.objc.getClass(className);

    shim[className] = createClassWrapper(classId);
  });

  return handle;
}

function performSelector(id, args) {
  var selectorString = args[0];

  var applyArgs = [id, undefined];

  for (var i = 1; i < args.length; i++) {
    if ((i % 2) === 0) {
      selectorString += args[i];
    } else {
      selectorString += ':';

      if (args[i] && args[i].isId) {
        applyArgs.push(args[i].id);
      } else {
        applyArgs.push(args[i]);
      }
    }
  }

  var selector = ocr.sel.registerName(selectorString);

  applyArgs[1] = selector;

  var result = ocr.objc.msgSend.apply(ocr.objc.msgSend, applyArgs);

  if (Buffer.isBuffer(result) && result.length === 8) {
    result = createIdWrapper(result);
  }

  return result;
};

function createClassWrapper(id) {
  return (function(id) {
    var wrapper = createIdWrapper(id);

    wrapper.extend = function(name) {
      var cls = ocr.objc.allocateClassPair(id, name, 0);

      return createClassWrapper(cls);
    };

    wrapper.addMethod = function(name, types, impl) {
      return ocr.class.addMethod(id, ocr.sel.registerName(name), function() {
        var applyArgs = [];
        for (var i = 0; i < arguments.length; i++) {
          applyArgs[i] = arguments[i];

          if (Buffer.isBuffer(applyArgs[i]) && applyArgs[i].length === 8) {
            applyArgs[i] = createIdWrapper(applyArgs[i]);
          }
        }

        try {
          impl.apply(impl, applyArgs);
        } catch (e) {
          console.log(e);
        }
      }, types);
    }

    return wrapper;
  })(id);
}

function createIdWrapper(id) {
  return (function(id) {
    var wrapper = function(id) {
      return performSelector(id, Array.prototype.slice.call(arguments, 1));
    }.bind(wrapper, id);

    wrapper.id = id;
    wrapper.isId = true;

    wrapper.toString = function() {
      return wrapper('description')('UTF8String');
    };

    return wrapper;
  })(id);
}

shim.import = importFramework;

module.exports = shim;

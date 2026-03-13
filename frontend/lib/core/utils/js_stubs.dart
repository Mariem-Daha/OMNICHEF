// Stub for dart:js — used on non-web platforms so that files which
// conditionally import 'dart:js' as js compile on Windows/native.
library js_stubs;

class _JsContext {
  dynamic operator [](String key) => null;
}

final context = _JsContext();

// Stub for dart:html — used on non-web platforms so that files which
// conditionally import 'dart:html' as html compile on Windows/native.
library web_stubs;

class MessageEvent {
  final dynamic data;
  const MessageEvent({this.data});
}

class _Window {
  Stream<MessageEvent> get onMessage => const Stream.empty();
}

final window = _Window();

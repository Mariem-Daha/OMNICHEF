import 'package:flutter/foundation.dart' show kIsWeb;
import 'base_recorder.dart';
import 'native_recorder.dart';
import 'web_recorder.dart';

class RecorderFactory {
  static BaseRecorder createRecorder() {
    if (kIsWeb) {
      return WebRecorder();
    } else {
      return NativeRecorder();
    }
  }
}

// Stub for mp_audio_stream on non-web platforms
// This file is imported when dart.library.io is available (Native platforms)

import 'dart:typed_data';

class AudioStream {
  void init({
    int bufferMilliSec = 3000,
    int waitingBufferMilliSec = 100,
    int channels = 1,
    int sampleRate = 44100,
  }) {}

  void resume() {}
  void push(Float32List data) {}
  void uninit() {}
}

AudioStream getAudioStream() => AudioStream();

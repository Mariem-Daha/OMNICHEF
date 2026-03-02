import 'dart:async';
import 'dart:typed_data';

class RecordingConfig {
  final int sampleRate;
  final int numChannels;
  final Duration? maxDuration;

  const RecordingConfig({
    required this.sampleRate,
    this.numChannels = 1,
    this.maxDuration,
  });
}

abstract class BaseRecorder {
  // Methods
  Stream<Uint8List>? get audioChunkStream;

  Future<bool> initialize();
  Future<bool> hasPermission();
  Future<bool> startRecording(RecordingConfig config);
  Future<void> stopRecording();
  bool isRecording();
  Future<void> dispose();
  
  // Audio analysis
  Future<double> getAmplitude();
  
  // Debug info
  int getBytesRecorded();
}

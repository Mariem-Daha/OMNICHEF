import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'base_recorder.dart';

class WebRecorder implements BaseRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  StreamController<Uint8List>? _chunkController;
  StreamSubscription? _audioStreamSubscription;
  bool _isRecording = false;
  int _bytesRecorded = 0;
  
  double _currentAmplitude = -160.0;
  Timer? _amplitudeTimer;

  @override
  Stream<Uint8List>? get audioChunkStream => _chunkController?.stream;

  @override
  Future<bool> initialize() async {
    return true;
  }

  @override
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  @override
  Future<bool> startRecording(RecordingConfig config) async {
    if (await _recorder.hasPermission()) {
      // Broadcast so multiple subscribers (listening vs barge-in) can attach/
      // detach without buffering stale chunks or blocking each other.
      _chunkController = StreamController<Uint8List>.broadcast();
      
      const recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000, 
        numChannels: 1,
        // Request AEC + NS so the browser applies hardware echo cancellation
        // — prevents AI speaker output from feeding back into the mic.
        echoCancel: true,
        noiseSuppress: true,
      );

      final stream = await _recorder.startStream(recordConfig);
      
      _audioStreamSubscription = stream.listen((chunk) {
        _bytesRecorded += chunk.length;
        _chunkController?.add(chunk);
      });
      
      _isRecording = true;
      _startAmplitudeCheck();
      
      return true;
    }
    return false;
  }
  
  void _startAmplitudeCheck() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_isRecording) {
        final amp = await _recorder.getAmplitude();
        _currentAmplitude = amp.current;
      }
    });
  }

  @override
  Future<void> stopRecording() async {
    _isRecording = false;
    _amplitudeTimer?.cancel();
    await _audioStreamSubscription?.cancel();
    await _recorder.stop();
    await _chunkController?.close();
    _chunkController = null;
  }

  @override
  bool isRecording() => _isRecording;

  @override
  Future<void> dispose() async {
    await stopRecording();
    _recorder.dispose();
  }
  
  @override
  Future<double> getAmplitude() async {
    return _currentAmplitude;
  }
  
  @override
  int getBytesRecorded() {
    return _bytesRecorded;
  }
}

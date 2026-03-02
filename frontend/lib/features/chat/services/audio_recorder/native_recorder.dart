import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'base_recorder.dart';

class NativeRecorder implements BaseRecorder {
  AudioRecorder? _recorder;
  bool _isRecording = false;
  int _bytesRecorded = 0;
  
  StreamController<Uint8List>? _chunkController;
  StreamSubscription? _audioStreamSubscription;
  
  // Amplitude
  double _currentAmplitude = -160.0;
  Timer? _amplitudeTimer;

  @override
  Stream<Uint8List>? get audioChunkStream => _chunkController?.stream;

  @override
  Future<bool> initialize() async {
    try {
      _recorder = AudioRecorder();
      return true;
    } catch (e) {
      print('NativeRecorder init error: $e');
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    return await _recorder?.hasPermission() ?? false;
  }

  @override
  Future<bool> startRecording(RecordingConfig config) async {
    if (_recorder == null) return false;
    
    try {
      // Try to request permission first (works on mobile; no-op on Windows Win32)
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        print('⚠️ NativeRecorder: hasPermission=false, attempting anyway (Win32 may not require explicit grant)');
      }

      _chunkController = StreamController<Uint8List>.broadcast();
      
      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: config.sampleRate,
        numChannels: config.numChannels,
      );

      final stream = await _recorder!.startStream(recordConfig);
      
      _audioStreamSubscription = stream.listen((Uint8List chunk) {
        _bytesRecorded += chunk.length;
        _chunkController?.add(chunk);
      }, onError: (e) {
        print('❌ Recording stream error: $e');
      });
      
      _isRecording = true;
      _startAmplitudeCheck();
      print('✅ NativeRecorder: recording started (${config.sampleRate}Hz, ${config.numChannels}ch)');
      return true;
    } catch (e) {
      print('❌ NativeRecorder.startRecording error: $e');
      await _chunkController?.close();
      _chunkController = null;
      return false;
    }
  }

  void _startAmplitudeCheck() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_isRecording && _recorder != null) {
        final amp = await _recorder!.getAmplitude();
        _currentAmplitude = amp.current;
      }
    });
  }

  @override
  Future<void> stopRecording() async {
    _isRecording = false;
    _amplitudeTimer?.cancel();
    await _audioStreamSubscription?.cancel();
    await _recorder?.stop();
    await _chunkController?.close();
    _chunkController = null;
  }

  @override
  bool isRecording() => _isRecording;

  @override
  Future<double> getAmplitude() async {
    return _currentAmplitude;
  }

  @override
  int getBytesRecorded() => _bytesRecorded;
  
  @override
  Future<void> dispose() async {
    await stopRecording();
    _recorder?.dispose();
    _recorder = null;
  }
}

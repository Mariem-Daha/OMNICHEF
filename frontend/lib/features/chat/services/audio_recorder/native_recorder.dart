import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
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
    if (_recorder == null) return false;
    // On iOS/Android, record's hasPermission() both checks and triggers
    // the system dialog on first call, then returns cached state.
    // On Windows/Web it always returns true (no OS permission needed).
    if (kIsWeb) return true;
    return await _recorder!.hasPermission();
  }

  @override
  Future<bool> startRecording(RecordingConfig config) async {
    if (_recorder == null) return false;
    
    try {
      // ── iOS / Android: request microphone permission ──────────────────
      // On web/Windows this is a no-op (permission_handler returns granted).
      if (!kIsWeb) {
        final status = await Permission.microphone.status;
        if (status.isDenied) {
          // First time — show the system permission dialog.
          final result = await Permission.microphone.request();
          if (!result.isGranted) {
            print('❌ NativeRecorder: microphone permission denied by user');
            return false;
          }
        } else if (status.isPermanentlyDenied) {
          // User previously hit "Don't Allow" — we must send them to Settings.
          print('❌ NativeRecorder: microphone permanently denied — open Settings');
          return false;
        }
      }

      _chunkController = StreamController<Uint8List>.broadcast();
      
      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: config.sampleRate,
        numChannels: config.numChannels,
        // Enable hardware-level echo cancellation and noise suppression.
        // On Android this routes through the voiceCommunication audio source
        // which activates the onboard AEC/NS DSP, preventing the speaker
        // output from being picked up by the mic.
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
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

// ============================================================================
// GEMINI LIVE SERVICE - Real-time Bidirectional Audio Streaming
// ============================================================================
// WebSocket-based voice assistant using Gemini Live API
// 
// Features:
// - Bidirectional audio streaming (16kHz PCM input, 24kHz PCM output)
// - Real-time function calling with backend integration
// - Cross-platform support
// - Automatic reconnection and error recovery
// - Interruption handling
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_recorder/base_recorder.dart';
import 'audio_recorder/recorder_factory.dart';

// Web-specific imports
// import 'package:mp_audio_stream/mp_audio_stream.dart' if (dart.library.io) 'audio_stream_stub.dart';

/// Gemini Live session states
enum LiveState {
  disconnected,   // Not connected to server
  connecting,     // Connecting to WebSocket
  connected,      // Connected but not streaming
  listening,      // Recording user audio
  processing,     // Gemini is processing
  speaking,       // Gemini is speaking
  error,          // Error state
}

/// Gemini Live Service - manages WebSocket connection and audio streaming
class GeminiLiveService {
  static final GeminiLiveService _instance = GeminiLiveService._internal();
  factory GeminiLiveService() => _instance;
  GeminiLiveService._internal();

  // WebSocket connection
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  
  // Audio components
  BaseRecorder? _recorder;
  AudioPlayer? _audioPlayer;
  
  // State management
  LiveState _state = LiveState.disconnected;
  bool _isInitialized = false;
  String? _sessionId;
  
  // Audio configuration (optimized for low latency)
  static const int _sendSampleRate = 16000;  // Send to server
  
  // Recording control
  Timer? _audioStreamTimer;
  bool _isStreaming = false;
  StreamSubscription? _audioChunkSubscription;
  StreamSubscription? _bargeInSubscription;  // monitors mic during AI speech
  
  // Audio buffering per turn
  final BytesBuilder _audioBuffer = BytesBuilder();
  int? _currentTurnSampleRate;
  bool _isSpeaking = false;
  
  // Connection health
  Timer? _heartbeatTimer;

  // ── Client-side VAD (silence detection) ──────────────────────────────────
  // Runs on every outgoing PCM chunk; no server round-trip needed.
  bool _vadSpeechDetected = false;       // true once the user starts speaking
  DateTime? _vadLastSpeechTime;          // wall-clock of last loud chunk
  Timer? _vadSilenceTimer;               // fires end_of_turn after silence
  // RMS energy threshold (0-1 normalised). ~0.008 catches normal speech while
  // ignoring background hiss.  Adjust downward for quiet microphones.
  static const double _vadEnergyThreshold = 0.008;
  // How long silence must last (after speech detected) before we end the turn.
  // 650ms feels natural — long enough not to cut mid-sentence, fast enough to
  // feel responsive.
  static const Duration _vadSilenceDuration = Duration(milliseconds: 650);

  // ── Adaptive noise floor ─────────────────────────────────────────────────
  // Tracks the ambient noise level and raises the effective VAD threshold so
  // background hiss / room noise doesn't count as speech.  Updated only on
  // *quiet* chunks (below current threshold) using a slow EMA (α = 0.02).
  double _adaptiveNoiseFloor = 0.003;
  static const double _noiseFloorAlpha = 0.02;   // EMA smoothing factor
  static const double _noiseFloorHeadroom = 2.5; // how many × above floor counts as speech
  DateTime? _lastPongTime;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 3;
  String? _lastServerUrl;
  
  // Callbacks
  Function(String)? onTranscriptReceived;
  Function(String, Map<String, dynamic>)? onFunctionExecuted;
  Function(String)? onError;
  Function(LiveState)? onStateChanged;
  Function(Map<String, dynamic>)? onVADMetrics;  // Voice Activity Detection metrics
  Function(Uint8List, int)? onAudioReadyToPlay;  // Audio data ready for UI thread playback
  Function(double)? onAmplitudeChanged;           // Real-time mic RMS 0.0–1.0 for visualizer

  // Latency tracking
  double _currentLatencyMs = 0.0;
  DateTime? _lastAudioSentTime;
  
  // Getters
  LiveState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _state != LiveState.disconnected && _state != LiveState.error;
  bool get isSpeaking => _state == LiveState.speaking;
  bool get isListening => _state == LiveState.listening;
  String? get sessionId => _sessionId;
  double get currentLatencyMs => _currentLatencyMs;

  // =========================================================================
  // INITIALIZATION
  // =========================================================================

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('🎤 Initializing Gemini Live Service...');
      print('🌐 Platform: ${kIsWeb ? "Web" : "Native"}');

      // Create platform-appropriate recorder
      _recorder = RecorderFactory.createRecorder();

      if (_recorder != null) {
        final initialized = await _recorder!.initialize();
        if (!initialized) {
          print('❌ Recorder initialization failed');
          print('⚠️ Continuing without recorder...');
        } else {
          final hasPermission = await _recorder!.hasPermission();
          if (!hasPermission) {
            print('⚠️ Microphone permission not granted yet');
          }
        }
      } else {
        print('❌ Failed to create recorder');
      }

      // Initialize audio player for all platforms
      try {
        _audioPlayer = AudioPlayer();
        await _audioPlayer?.setReleaseMode(ReleaseMode.stop);
        print('✅ Audio player initialized');
      } catch (e) {
        print('❌ Audio player initialization failed: $e');
      }

      _isInitialized = true;
      print('✅ Gemini Live Service initialized');
      return true;
    } catch (e) {
      print('❌ Error initializing: $e');
      return false;
    }
  }

  void _setState(LiveState newState) {
    if (_state != newState) {
      _state = newState;
      onStateChanged?.call(_state);
    }
  }

  // =========================================================================
  // WEBSOCKET CONNECTION
  // =========================================================================

  /// Connect to Gemini Live API WebSocket
  Future<bool> connect(String serverUrl) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        print('❌ Initialization failed, cannot connect');
        return false;
      }
    }

    // Safari fix: Always cleanup any existing connection state before connecting
    if (_channel != null || _wsSubscription != null) {
      print('⚠️ Cleaning up stale connection before reconnecting...');
      await _forceCleanup();
    }

    if (_state == LiveState.connecting) {
      print('⚠️ Already connecting, please wait...');
      return false;
    }

    try {
      _setState(LiveState.connecting);
      _lastServerUrl = serverUrl;
      print('🔌 Connecting to Gemini Live API: $serverUrl');
      
      // Create WebSocket connection - URL should already be wss://
      final wsUrl = serverUrl.startsWith('ws') 
          ? serverUrl 
          : serverUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      print('🔌 WebSocket URL: $wsUrl');
      
      try {
        final uri = Uri.parse(wsUrl);
        _channel = WebSocketChannel.connect(uri);
        print('✅ WebSocketChannel created');
      } catch (e) {
        print('❌ Failed to create WebSocket channel: $e');
        _setState(LiveState.error);
        onError?.call('WS_CREATE_FAILED: $e');
        return false;
      }

      final connectionConfirmed = Completer<bool>();

      _wsSubscription = _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message as String);
            if (data['type'] == 'connected' && !connectionConfirmed.isCompleted) {
              print('✅ Received connected confirmation from server');
              connectionConfirmed.complete(true);
            }
            _handleWebSocketMessage(message);
          } catch (e) {
            print('❌ Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket stream error: $error');
          if (!connectionConfirmed.isCompleted) {
            connectionConfirmed.complete(false);
          }
          onError?.call('STREAM_ERROR: $error');
          _handleWebSocketError(error);
        },
        onDone: () {
          print('🔌 WebSocket stream done');
          if (!connectionConfirmed.isCompleted) {
            connectionConfirmed.complete(false);
            onError?.call('STREAM_CLOSED: WebSocket closed before confirmation');
          }
          _handleWebSocketClosed();
        },
        cancelOnError: false,
      );

      final connected = await connectionConfirmed.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('❌ Connection timeout after 15 seconds');
          onError?.call('TIMEOUT: WebSocket created but no response from server after 15s');
          return false;
        },
      );
      
      if (connected) {
        print('✅ Connected to Gemini Live API (Session: $_sessionId)');
        _reconnectAttempts = 0;  // Reset reconnect counter
        _startHeartbeat();
        return true;
      } else {
        print('❌ Connection failed - no confirmation received');
        _setState(LiveState.error);
        onError?.call('CONNECTION_FAILED: WebSocket connected but server did not confirm');
        return false;
      }
    } catch (e) {
      print('❌ Connection error: $e');
      _setState(LiveState.error);
      onError?.call('EXCEPTION: $e');
      _attemptReconnection();
      return false;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    print('🔌 Disconnecting from Gemini Live API...');
    await _forceCleanup();
    print('✅ Disconnected');
  }

  /// Force cleanup all WebSocket state (Safari-safe)
  Future<void> _forceCleanup() async {
    print('🧹 Force cleanup WebSocket state...');
    
    // Stop recording first
    try {
      await stopListening();
    } catch (e) {
      print('⚠️ Error stopping listening: $e');
    }

    // Stop barge-in monitoring
    try {
      _stopBargeInMonitoring();
    } catch (e) {
      print('⚠️ Error stopping barge-in monitoring: $e');
    }
    
    // Stop audio playback
    try {
      await _audioPlayer?.stop();
    } catch (e) {
      print('⚠️ Error stopping audio: $e');
    }
    
    _stopHeartbeat();
    
    try {
      await _audioChunkSubscription?.cancel();
    } catch (e) {
      print('⚠️ Error cancelling audio subscription: $e');
    }
    _audioChunkSubscription = null;
    
    try {
      await _wsSubscription?.cancel();
    } catch (e) {
      print('⚠️ Error cancelling WS subscription: $e');
    }
    _wsSubscription = null;
    
    try {
      if (_channel != null) {
        await _channel!.sink.close();
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print('⚠️ Error closing WS channel: $e');
    }
    _channel = null;
    
    _clearAudioBuffer();
    
    _sessionId = null;
    _lastPongTime = null;
    _isSpeaking = false;
    _isStreaming = false;
    _setState(LiveState.disconnected);
  }

  // =========================================================================
  // WEBSOCKET MESSAGE HANDLING
  // =========================================================================

  void _handleWebSocketMessage(dynamic message) async {
    try {
      final data = json.decode(message as String);
      final messageType = data['type'] as String;

      switch (messageType) {
        case 'connected':
          _sessionId = data['session_id'];
          _setState(LiveState.connected);
          print('✅ Session connected: $_sessionId');
          print('🔄 DEBUG: State after connection: ${_state.name}');
          break;

        case 'audio':
          // First audio chunk from Gemini → switch to processing/thinking state
          if (_state == LiveState.listening || _state == LiveState.connected) {
            _setState(LiveState.processing);
          }
          _handleAudioResponse(data);
          break;

        case 'ai_generating':
          // Gemini has started generating — show "Thinking..."
          if (_state != LiveState.speaking) {
            _setState(LiveState.processing);
          }
          break;

        case 'pong':
          _lastPongTime = DateTime.now();
          break;

        case 'transcript':
          final text = data['text'] as String;
          print('📝 Gemini: $text');
          onTranscriptReceived?.call(text);
          break;

        case 'function_executed':
          final functionName = data['function'] as String;
          final result = data['result'] as Map<String, dynamic>;
          print('⚙️ Function executed: $functionName');
          onFunctionExecuted?.call(functionName, result);
          break;

      case 'turn_complete':
        print('✅ Turn complete - playing buffered audio');
        await _playBufferedAudio();
        // State will be set to speaking by _playBufferedAudio.
        // Auto-start mic is triggered in onAudioPlaybackComplete() below.
        break;

      case 'interrupted':
        // Gemini's own barge-in signal — stop playback and clear buffer immediately
        print('⚡ Gemini interrupted — clearing audio buffer and resuming mic');
        await stopAudioPlayback();
        _isSpeaking = false;
        if (isConnected) {
          _setState(LiveState.connected);
          // Small delay so the audio subsystem fully drains before re-opening
          Future.delayed(const Duration(milliseconds: 120), () {
            if (isConnected && _state == LiveState.connected) startListening();
          });
        }
        break;

      case 'interrupt_ack':
        // Backend confirmed our barge-in signal — nothing extra needed
        print('⚡ Interrupt acknowledged by server');
        break;

        case 'vad_metrics':
          final metrics = data['metrics'] as Map<String, dynamic>;
          onVADMetrics?.call(metrics);
          break;

        case 'error':
          final error = data['error'] as String;
          print('❌ Server error: $error');
          _setState(LiveState.error);
          onError?.call(error);
          break;

        default:
          print('⚠️ Unknown message type: $messageType');
      }
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }

  void _handleWebSocketError(error) {
    print('❌ WebSocket error: $error');
    _wsSubscription = null;
    _channel = null;
    _setState(LiveState.error);
    onError?.call('WebSocket error: $error');
  }

  void _handleWebSocketClosed() {
    print('🔌 WebSocket closed');
    _stopHeartbeat();
    _clearAudioBuffer();
    _vadSilenceTimer?.cancel();
    _vadSilenceTimer = null;
    final wasConnected = _channel != null;
    _wsSubscription = null;
    _channel = null;
    _sessionId = null;
    _isSpeaking = false;
    _setState(LiveState.disconnected);
    // Auto-reconnect if we were previously connected (unexpected drop)
    if (wasConnected && _lastServerUrl != null) {
      print('🔄 Unexpected disconnect — auto-reconnecting...');
      Future.delayed(const Duration(seconds: 2), () {
        if (_state == LiveState.disconnected && _lastServerUrl != null) {
          connect(_lastServerUrl!);
        }
      });
    }
  }

  void _attemptReconnection() {
    if (_reconnectAttempts >= maxReconnectAttempts || _lastServerUrl == null) {
      print('❌ Max reconnection attempts reached or no server URL');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: 2 * _reconnectAttempts);
    
    print('🔄 Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$maxReconnectAttempts)...');
    
    Future.delayed(delay, () {
      if (_state == LiveState.disconnected && _lastServerUrl != null) {
        connect(_lastServerUrl!);
      }
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (isConnected) {
        _sendMessage({'type': 'ping'});
        if (_lastPongTime != null) {
          final timeSinceLastPong = DateTime.now().difference(_lastPongTime!).inSeconds;
          if (timeSinceLastPong > 30) {
            print('⚠️ No pong in ${timeSinceLastPong}s - connection may be stale');
          }
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && isConnected) {
      _channel!.sink.add(json.encode(message));
    }
  }

  void _handleAudioResponse(Map<String, dynamic> data) async {
    try {
      if (_lastAudioSentTime != null) {
        final latency = DateTime.now().difference(_lastAudioSentTime!).inMilliseconds.toDouble();
        _currentLatencyMs = (_currentLatencyMs * 0.8) + (latency * 0.2);
      }

      final audioBase64 = data['data'] as String?;
      final mimeType = data['mime_type'] as String? ?? 'audio/mpeg';
      final sampleRate = data['sample_rate'] as int? ?? 24000;

      if (audioBase64 == null) return;

      final audioBytes = base64Decode(audioBase64);
      if (audioBytes.isEmpty) return;

      if (mimeType.contains('pcm')) {
        _audioBuffer.add(audioBytes);
        _currentTurnSampleRate = sampleRate;
      }
    } catch (e) {
      print('❌ Error handling audio: $e');
    }
  }

  // =========================================================================
  // AUDIO PLAYBACK
  // =========================================================================

  /// Play buffered audio when turn is complete
  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) {
      print('⚠️ Audio buffer is empty, nothing to play — auto-starting mic');
      _setState(LiveState.connected);
      // No audio this turn — still auto-start listening
      if (isConnected) startListening();
      return;
    }

    if (_audioBuffer.length % 2 != 0) {
      final bytes = _audioBuffer.toBytes();
      _audioBuffer.clear();
      _audioBuffer.add(bytes.sublist(0, bytes.length - 1));
    }

    try {
      final pcmData = _audioBuffer.toBytes();
      final sampleRate = _currentTurnSampleRate ?? 24000;

      _setState(LiveState.speaking);
      _isSpeaking = true;

      // Start mic monitoring so user can barge-in while AI speaks
      _startBargeInMonitoring();

      // Convert PCM to WAV for all platforms
      final wavBytes = _convertPcmToWav(pcmData, sampleRate);

      // Notify UI thread to play audio (fixes threading issue)
      onAudioReadyToPlay?.call(wavBytes, sampleRate);

    } catch (e) {
      print('❌ Error preparing audio: $e');
      onError?.call('Audio preparation failed: $e');
      _setState(LiveState.connected);
      _isSpeaking = false;
    } finally {
      _audioBuffer.clear();
      _currentTurnSampleRate = null;
    }
  }

  /// Call this from UI thread after audio playback completes
  void onAudioPlaybackComplete() {
    print('🔄 DEBUG: onAudioPlaybackComplete() called');
    _stopBargeInMonitoring();
    _isSpeaking = false;
    if (_state == LiveState.speaking) {
      _setState(LiveState.connected);
      print('🔄 DEBUG: State changed to connected after audio playback');
    }

    // Brief "breath" pause before picking up the mic — feels more human and
    // avoids the mic catching the tail echo of the last AI audio frame.
    if (isConnected && _state == LiveState.connected) {
      print('🎤 Auto-starting mic in 300ms (natural breath pause)...');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (isConnected && _state == LiveState.connected) {
          startListening();
        }
      });
    }
  }
  
  Float32List _convertInt16ToFloat32(Uint8List int16Data) {
    final numSamples = int16Data.length ~/ 2;
    final float32List = Float32List(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
      final int16Value = (int16Data[i * 2 + 1] << 8) | int16Data[i * 2];
      final signedInt16 = int16Value > 32767 ? int16Value - 65536 : int16Value;
      float32List[i] = signedInt16 / 32768.0;
    }
    return float32List;
  }

  Uint8List _convertPcmToWav(Uint8List pcmData, int sampleRate) {
    final int numChannels = 1;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;
    
    final header = BytesBuilder();
    header.add('RIFF'.codeUnits);
    header.add(_int32ToBytes(fileSize));
    header.add('WAVE'.codeUnits);
    header.add('fmt '.codeUnits);
    header.add(_int32ToBytes(16));
    header.add(_int16ToBytes(1));
    header.add(_int16ToBytes(numChannels));
    header.add(_int32ToBytes(sampleRate));
    header.add(_int32ToBytes(byteRate));
    header.add(_int16ToBytes(blockAlign));
    header.add(_int16ToBytes(bitsPerSample));
    header.add('data'.codeUnits);
    header.add(_int32ToBytes(dataSize));
    header.add(pcmData);
    
    return Uint8List.fromList(header.toBytes());
  }
  
  Uint8List _int32ToBytes(int value) {
    return Uint8List(4)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF
      ..[2] = (value >> 16) & 0xFF
      ..[3] = (value >> 24) & 0xFF;
  }
  
  Uint8List _int16ToBytes(int value) {
    return Uint8List(2)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF;
  }

  // =========================================================================
  // AUDIO STREAMING
  // =========================================================================

  /// Start listening and streaming audio to Gemini
  Future<bool> startListening() async {
    print('🔍 DEBUG: startListening() called');
    print('🔍 DEBUG: isConnected = $isConnected');
    print('🔍 DEBUG: current state = ${_state.name}');
    print('🔍 DEBUG: recorder = ${_recorder != null ? "initialized" : "NULL"}');
    print('🔍 DEBUG: channel = ${_channel != null ? "exists" : "NULL"}');
    print('🔍 DEBUG: sessionId = $_sessionId');

    if (!isConnected) {
      print('❌ BLOCKED: Not connected to server');
      onError?.call('Not connected to server. Please wait for connection.');
      return false;
    }

    if (_state != LiveState.connected) {
      print('❌ BLOCKED: Invalid state: ${_state.name} (must be connected)');
      // Only allow start from connected state
      if (_state == LiveState.listening) {
        print('⚠️ Already listening');
        return true;
      }
      onError?.call('Assistant not ready. Current state: ${_state.name}');
      return false;
    }

    if (_recorder == null) {
      print('❌ BLOCKED: Recorder not initialized');
      onError?.call('Microphone not available');
      return false;
    }

    print('✅ All checks passed - starting recorder...');

    await _ensureRecorderStopped();

    try {
      _setState(LiveState.listening);
      print('🎤 Starting audio streaming...');

      final config = RecordingConfig(
        sampleRate: _sendSampleRate,
        numChannels: 1,
        maxDuration: const Duration(minutes: 5),
      );

      final started = await _recorder!.startRecording(config);
      if (!started) {
        print('❌ Failed to start recording — microphone may be blocked or unavailable');
        _setState(LiveState.connected);
        onError?.call('Microphone unavailable. Check Windows Settings → Privacy → Microphone.');
        return false;
      }

      _isStreaming = true;
      _streamAudioChunks();

      print('✅ Audio streaming started');
      return true;
    } catch (e) {
      print('❌ Error starting listening: $e');
      _setState(LiveState.connected);
      onError?.call('Failed to start microphone: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_state != LiveState.listening && _state != LiveState.processing) return;

    try {
      print('🛑 Stopping audio streaming...');

      // Cancel client-side VAD timer
      _vadSilenceTimer?.cancel();
      _vadSilenceTimer = null;
      _vadSpeechDetected = false;

      _isStreaming = false;
      _audioStreamTimer?.cancel();
      _audioStreamTimer = null;

      await _audioChunkSubscription?.cancel();
      _audioChunkSubscription = null;

      if (_recorder != null && _recorder!.isRecording()) {
        await _recorder!.stopRecording();
      }

      _sendEndOfTurn();

      _setState(LiveState.processing);
      print('✅ Audio streaming stopped, waiting for Gemini response');
    } catch (e) {
      print('❌ Error stopping listening: $e');
    }
  }

  void _streamAudioChunks() {
    if (_recorder == null) return;

    // Reset VAD state for the new listening turn
    _vadSpeechDetected = false;
    _vadLastSpeechTime = null;
    _vadSilenceTimer?.cancel();
    _vadSilenceTimer = null;
    // Reset adaptive noise floor estimate so each turn re-calibrates to the
    // current acoustic environment (e.g. user moved to a louder room).
    _adaptiveNoiseFloor = 0.003;

    _audioChunkSubscription = _recorder!.audioChunkStream?.listen((chunk) {
      if (!_isStreaming || !isConnected) return;

      // ── Client-side VAD ───────────────────────────────────────────────────
      final rms = _computeChunkRMS(chunk);
      // Effective threshold: the higher of the static floor or the adaptive one.
      final effectiveThreshold = math.max(
        _vadEnergyThreshold,
        _adaptiveNoiseFloor * _noiseFloorHeadroom,
      );

      // Update adaptive noise floor on quiet chunks (EMA)
      if (rms < effectiveThreshold) {
        _adaptiveNoiseFloor = _adaptiveNoiseFloor * (1 - _noiseFloorAlpha) +
            rms * _noiseFloorAlpha;
      }

      final isSpeech = rms > effectiveThreshold;

      if (isSpeech) {
        // Loud chunk — user is speaking
        _vadSpeechDetected = true;
        _vadLastSpeechTime = DateTime.now();
        // Cancel any pending silence timer so we don’t cut in mid-sentence
        _vadSilenceTimer?.cancel();
        _vadSilenceTimer = null;        // ── Auto barge-in: if AI is currently speaking, interrupt it ─────
        if (_state == LiveState.speaking) {
          sendInterrupt();
        }      } else if (_vadSpeechDetected) {
        // Quiet chunk after speech — start (or keep) the silence countdown
        _vadSilenceTimer ??= Timer(_vadSilenceDuration, () {
          print('🔇 Client VAD: ${_vadSilenceDuration.inMilliseconds}ms silence → end_of_turn');
          _vadSpeechDetected = false;
          _vadSilenceTimer = null;
          // Send end_of_turn signal; stopListening() will stop the mic
          if (_isStreaming && isConnected) {
            _sendEndOfTurn();
            stopListening();
          }
        });
      }
      // ─────────────────────────────────────────────────────────────────────

      onAmplitudeChanged?.call(rms.clamp(0.0, 1.0));

      _lastAudioSentTime = DateTime.now();
      _sendMessage({"type": "audio", "data": base64Encode(chunk)});
    });

    if (_recorder!.audioChunkStream == null) {
      print('⚠️ Audio chunk stream not available');
    }
  }

  /// Compute normalised RMS energy of a 16-bit little-endian PCM chunk.
  double _computeChunkRMS(Uint8List pcm) {
    final count = pcm.length ~/ 2;
    if (count == 0) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < count; i++) {
      final raw = pcm[i * 2] | (pcm[i * 2 + 1] << 8);
      final signed = raw > 32767 ? raw - 65536 : raw;
      final norm = signed / 32768.0;
      sum += norm * norm;
    }
    return math.sqrt(sum / count);
  }

  void _sendEndOfTurn() {
    // Explicit end-of-turn message so the backend always forwards it to Gemini
    _sendMessage({"type": "end_of_turn"});
  }
  
  void sendText(String text) {
    if (isConnected) {
      _sendMessage({
        "type": "text", 
        "text": text
      });
    }
  }

  // =========================================================================
  // BARGE-IN MONITORING (mic monitoring while AI speaks)
  // =========================================================================

  /// Start recording in a lightweight monitoring mode while the AI is speaking.
  /// When user voice is detected above the threshold the AI is interrupted
  /// automatically without needing any UI tap.
  void _startBargeInMonitoring() async {
    if (_recorder == null) return;
    if (_recorder!.isRecording()) return;  // recorder already active

    try {
      final config = RecordingConfig(
        sampleRate: _sendSampleRate,
        numChannels: 1,
        maxDuration: const Duration(minutes: 5),
      );

      final started = await _recorder!.startRecording(config);
      if (!started) {
        print('⚠️ Barge-in monitoring: could not start microphone');
        return;
      }

      print('🎤 Barge-in monitoring active');

      // Use a higher RMS threshold than normal VAD to avoid false triggers
      // from acoustic echo (AI's own speaker audio bleeding into the microphone).
      // 3.5× the effective threshold — low enough for comfortable interruption,
      // high enough to reject speaker bleed.
      final bargeInThreshold = math.max(
        _vadEnergyThreshold,
        _adaptiveNoiseFloor * _noiseFloorHeadroom,
      ) * 3.5;

      // Small startup delay: skip the first 400ms of chunks so the initial
      // burst of AI audio (which the mic picks up as echo) is not mis-detected
      // as user speech.
      final monitoringStart = DateTime.now();
      const startupDelay = Duration(milliseconds: 400);

      _bargeInSubscription = _recorder!.audioChunkStream?.listen((chunk) {
        if (_state != LiveState.speaking || !isConnected) {
          _stopBargeInMonitoring();
          return;
        }

        // Skip chunks during the startup delay window
        if (DateTime.now().difference(monitoringStart) < startupDelay) return;

        final rms = _computeChunkRMS(chunk);
        onAmplitudeChanged?.call(rms.clamp(0.0, 1.0));

        if (rms > bargeInThreshold) {
          print('⚡ Auto barge-in: user speech detected during AI speech (RMS: ${rms.toStringAsFixed(3)})');
          _stopBargeInMonitoring();
          sendInterrupt().then((_) {
            if (isConnected) startListening();
          });
        }
      });
    } catch (e) {
      print('⚠️ Error starting barge-in monitoring: $e');
    }
  }

  /// Stop the barge-in monitoring mic and cancel the subscription.
  void _stopBargeInMonitoring() async {
    await _bargeInSubscription?.cancel();
    _bargeInSubscription = null;
    // Only stop the recorder if it's running for barge-in (not in listening state)
    if (_recorder != null &&
        _recorder!.isRecording() &&
        _state != LiveState.listening) {
      await _recorder!.stopRecording();
      print('🛑 Barge-in monitoring stopped');
    }
  }

  /// Barge-in: immediately stop the AI's current audio output and let the user speak.
  /// Stops local playback, clears buffered audio, and tells the server to interrupt.
  Future<void> sendInterrupt() async {
    print('⚡ Barge-in: stopping AI speech and sending interrupt');
    _stopBargeInMonitoring();
    // 1. Stop current audio playback
    await stopAudioPlayback();
    // 2. Tell backend to drop Gemini audio chunks and signal native barge-in
    _sendMessage({'type': 'interrupt'});
    // 3. Transition to connected so startListening() will accept the call
    _isSpeaking = false;
    if (_state == LiveState.speaking || _state == LiveState.processing) {
      _setState(LiveState.connected);
    }
  }

  /// Stop the audio player and clear the pending audio buffer.
  Future<void> stopAudioPlayback() async {
    try {
      await _audioPlayer?.stop();
    } catch (e) {
      print('⚠️ Error stopping audio playback: $e');
    }
    _audioBuffer.clear();
    _currentTurnSampleRate = null;
    _isSpeaking = false;
  }

  void _clearAudioBuffer() {
    _audioBuffer.clear();
    _currentTurnSampleRate = null;
  }

  Future<void> _ensureRecorderStopped() async {
    if (_recorder != null && _recorder!.isRecording()) {
      await _recorder!.stopRecording();
    }
  }
  
  // Amplitude for UI
  Future<double> getAmplitude() async {
    if (_recorder == null) return -120.0;
    return await _recorder!.getAmplitude();
  }
}

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
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
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
  // Set to true by sendInterrupt(); prevents a queued _playBufferedAudio() from
  // restarting speech after an in-flight barge-in during the processing phase.
  bool _interruptPending = false;
  
  // Connection health
  Timer? _heartbeatTimer;

  // ── Client-side VAD (silence detection) ──────────────────────────────────
  // Runs on every outgoing PCM chunk; no server round-trip needed.
  bool _vadSpeechDetected = false;       // true once the user starts speaking
  DateTime? _vadLastSpeechTime;          // wall-clock of last loud chunk
  Timer? _vadSilenceTimer;               // fires end_of_turn after silence
  Timer? _maxListenTimer;                // auto-closes mic if no speech in 10 s
  // RMS energy threshold (0-1 normalised).
  // 0.015 is high enough to reject acoustic echo from speakers and
  // background hiss while still catching conversational speech.
  static const double _vadEnergyThreshold = 0.015;
  // How long silence must last (after speech detected) before we end the turn.
  // 1200 ms covers natural mid-sentence pauses and thinking gaps (200–900 ms)
  // without making the assistant feel sluggish. Below ~700 ms the user's
  // mid-thought pauses trigger premature EOT and cut off their sentence.
  static const Duration _vadSilenceDuration = Duration(milliseconds: 1200);

  // ── Adaptive noise floor ─────────────────────────────────────────────────
  // Tracks the ambient noise level and raises the effective VAD threshold so
  // background hiss / room noise doesn't count as speech.  Updated only on
  // *quiet* chunks (below current threshold) using a slow EMA (α = 0.02).
  double _adaptiveNoiseFloor = 0.003;
  static const double _noiseFloorAlpha = 0.02;   // EMA smoothing factor
  // 6× above ambient noise floor — prevents speaker echo / room noise from
  // being mistaken for user speech and causing false barge-ins.
  static const double _noiseFloorHeadroom = 6.0;
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

  // ── Real-time streaming (web) ──────────────────────────────────────────
  // Called for each raw PCM audio chunk as it arrives from Gemini.
  // On web, this streams chunks directly to the Web Audio API for gapless
  // playback without buffering, eliminating dead air and sentence cuts.
  Function(String base64Pcm, int sampleRate)? onStreamAudioChunk;
  // Called when turn_complete fires — signals all audio for this turn has been sent.
  VoidCallback? onTurnPlaybackDone;

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

    // Cancel VAD timers
    _vadSilenceTimer?.cancel();
    _vadSilenceTimer = null;
    _maxListenTimer?.cancel();
    _maxListenTimer = null;
    
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
    _interruptPending = false;  // Reset so stale interrupt from previous session doesn't drop first audio
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
          // Discard stale audio chunks that arrive after a barge-in.
          if (_interruptPending) break;
          // If mic is already open (after seamless barge-in), drop server audio
          // so state never flips back to speaking and breaks the transition.
          if (_state == LiveState.listening) break;

          if (onStreamAudioChunk != null) {
            // Streaming mode (web): enter speaking on the FIRST chunk.
            // Must also handle the processing state, which is set by
            // ai_generating BEFORE audio arrives — without this the state
            // never transitions to speaking and turn_complete is dropped.
            if (_state != LiveState.speaking) {
              _setState(LiveState.speaking);
              _isSpeaking = true;
              _startBargeInMonitoring();
            }
          } else {
            // Buffer mode (native): enter processing from idle states only.
            if (_state == LiveState.listening || _state == LiveState.connected) {
              _setState(LiveState.processing);
            }
          }
          _handleAudioResponse(data);
          break;

        case 'ai_generating':
          // Gemini has started generating a NEW response — allow audio through.
          // This is the only safe point to clear _interruptPending after a
          // seamless barge-in: the old interrupted turn is fully done and
          // Gemini is now responding to the user's new utterance.
          _interruptPending = false;
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
        if (onStreamAudioChunk != null) {
          // Streaming mode (web): all chunks were already sent to playback.
          // Only signal completion if we're actually speaking (not interrupted).
          if (_state == LiveState.speaking && !_interruptPending) {
            print('✅ Turn complete (streaming mode)');
            onTurnPlaybackDone?.call();
          } else if (_state == LiveState.processing && !_interruptPending) {
            // Silent turn: function call with no audio output.
            // The AI executed a tool but chose not to speak — reopen the mic.
            print('✅ Turn complete (silent turn — function call with no audio)');
            _setState(LiveState.connected);
            if (isConnected) {
              Future.delayed(const Duration(milliseconds: 400), () {
                if (isConnected && _state == LiveState.connected) startListening();
              });
            }
          } else if (_state == LiveState.connected && !_interruptPending) {
            // Edge case: state already moved to connected (e.g. very short
            // response that finished before turn_complete arrived). Reopen mic.
            print('✅ Turn complete (already connected — reopening mic)');
            Future.delayed(const Duration(milliseconds: 400), () {
              if (isConnected && _state == LiveState.connected) startListening();
            });
          } else {
            print('✅ Turn complete (skipped — state: ${_state.name}, interrupted: $_interruptPending)');
            // Do NOT clear _interruptPending while in listening state (barge-in
            // in progress).  The interrupted turn's turn_complete arrives here
            // while the user is still speaking; clearing early lets stale audio
            // from the old turn resume once state transitions to processing.
            // _interruptPending is cleared by 'ai_generating' on web, or by
            // _playBufferedAudio() on native when the old TC fires.
            if (_state != LiveState.listening) {
              _interruptPending = false;
            }
          }
        } else {
          // Buffer mode (native): play accumulated audio. Small delay for any
          // TCP-reordered chunks to arrive (WebSocket is ordered, so 100ms is
          // more than enough; the old 800ms caused noticeable dead air).
          print('✅ Turn complete - playing buffered audio');
          await Future.delayed(const Duration(milliseconds: 100));
          await _playBufferedAudio();
        }
        break;

      case 'interrupted':
        // Gemini's own barge-in signal — stop playback and clear buffer.
        // If the client already handled the interrupt (mic is already open and
        // streaming) do nothing: resetting state here would stop the active
        // recording mid-sentence and cause the user's words to be lost.
        if (_state == LiveState.listening) {
          print('⚡ Gemini interrupted — client already listening, skipping state reset');
          break;
        }
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
    _maxListenTimer?.cancel();
    _maxListenTimer = null;
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

  /// Send a live camera frame (JPEG, base64-encoded) to the AI session.
  /// Called every ~2 s while camera mode is active in the voice screen.
  void sendVideoFrame(String jpegBase64) {
    _sendMessage({'type': 'video_frame', 'data': jpegBase64});
  }

  /// Send user health/preference context as the first message so the backend
  /// can personalise the AI's greeting and subsequent responses.
  void sendUserContext({
    List<String> healthFilters = const [],
    List<String> allergies = const [],
    List<String> dislikedIngredients = const [],
    List<String> tastePreferences = const [],
    String cookingSkill = 'Intermediate',
    bool greetingDelivered = false,
  }) {
    _sendMessage({
      'type': 'user_context',
      'health_filters': healthFilters,
      'allergies': allergies,
      'disliked_ingredients': dislikedIngredients,
      'taste_preferences': tastePreferences,
      'cooking_skill': cookingSkill,
      'greeting_delivered': greetingDelivered,
    });
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
        if (onStreamAudioChunk != null) {
          // Streaming mode: send each chunk directly to playback
          onStreamAudioChunk!(audioBase64!, sampleRate);
        } else {
          // Buffer mode: accumulate for later playback
          _audioBuffer.add(audioBytes);
          _currentTurnSampleRate = sampleRate;
        }
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
    // Guard: a barge-in was requested while the audio was still buffering.
    // Skip playback entirely so the user's voice input is not stomped.
    if (_interruptPending) {
      _interruptPending = false;
      _audioBuffer.clear();
      print('⏩ Skipping buffered audio — barge-in was requested during buffering');
      return;
    }

    if (_audioBuffer.isEmpty) {
      print('⚠️ Audio buffer is empty, nothing to play — auto-starting mic');
      // Guard: do not change state if the user is already listening (e.g. after
      // a barge-in that called startListening() before this future fired).
      if (_state != LiveState.listening) {
        _setState(LiveState.connected);
        if (isConnected) startListening();
      }
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

    // Brief "breath" pause before picking up the mic — feels more human,
    // avoids the mic catching the tail echo/reverb of the last AI audio frame,
    // and gives the OS audio session time to flush its hardware buffer.
    // 800 ms covers typical room reverb tails (200–500 ms) with extra margin.
    if (isConnected && _state == LiveState.connected) {
      print('🎤 Auto-starting mic in 800ms (reverb drain pause)...');
      Future.delayed(const Duration(milliseconds: 800), () {
        // Guard: if a barge-in already activated the mic, don't double-start.
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
    _interruptPending = false;  // Clear stale interrupt flag for new turn

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

      // Any stale audio from an interrupted turn has already been drained
      // during the listening window (typically 2–10 s). It is now safe to
      // unblock the pipeline so the new Gemini response can play.
      // Only clear if we're in listening (not processing) to avoid clearing
      // a freshly-set interrupt from a race condition.
      if (_state == LiveState.listening) {
        _interruptPending = false;
      }

      // Cancel client-side VAD timer
      _vadSilenceTimer?.cancel();
      _vadSilenceTimer = null;
      _vadSpeechDetected = false;

      // Cancel max-listen safety timer
      _maxListenTimer?.cancel();
      _maxListenTimer = null;

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
    // Do NOT reset _adaptiveNoiseFloor — keep the calibrated ambient noise
    // estimate from the previous turn.  Resetting to 0.003 caused the tail
    // echo of the AI's just-finished speech to read above that floor and
    // be mistaken as user speech, triggering false EOT / echo loops.
    // The EMA will naturally track room-level changes within a few seconds.

    // ── Max-listen safety timer ──────────────────────────────────────────────
    // If the user opens the mic but never speaks (e.g. after a false barge-in
    // reset), the VAD silence timer never fires because it only starts AFTER
    // speech is first detected. This 10-second fallback moves the state back
    // to "connected" (ready) so the UI doesn't stay stuck in "Listening..."
    // indefinitely. No end_of_turn is sent so Gemini isn't disturbed.
    _maxListenTimer?.cancel();
    _maxListenTimer = Timer(const Duration(seconds: 10), () {
      if (_isStreaming && !_vadSpeechDetected && isConnected) {
        print('⏰ Max-listen timeout: no speech in 10 s — silently resetting to ready');
        _maxListenTimer = null;
        _isStreaming = false;
        _vadSilenceTimer?.cancel();
        _vadSilenceTimer = null;
        _audioChunkSubscription?.cancel();
        _audioChunkSubscription = null;
        _recorder?.stopRecording();
        _setState(LiveState.connected);
      }
    });

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
        // Loud chunk — user is speaking.
        _maxListenTimer?.cancel();
        _maxListenTimer = null;
        _vadSpeechDetected = true;
        _vadLastSpeechTime = DateTime.now();
        // Cancel any pending silence timer so we don't cut in mid-sentence
        _vadSilenceTimer?.cancel();
        _vadSilenceTimer = null;
        // NOTE: barge-in while AI is speaking is handled exclusively by
        // _startBargeInMonitoring() which requires consecutive loud chunks.
        // Do NOT call sendInterrupt() here — that has no echo protection and
        // is the primary cause of the AI cutting its own sentences on echo.
      } else if (_vadSpeechDetected) {
        // Quiet chunk after speech — start (or keep) the silence countdown
        _vadSilenceTimer ??= Timer(_vadSilenceDuration, () {
          print('🔇 Client VAD: ${_vadSilenceDuration.inMilliseconds}ms silence → end_of_turn');
          _vadSpeechDetected = false;
          _vadSilenceTimer = null;
          // stopListening() sends end_of_turn internally — do NOT call
          // _sendEndOfTurn() here too or two EOT messages are sent back-to-back.
          // The backend's dedup resets after the first, letting the second
          // through which causes Gemini to respond twice (repeat bug).
          if (_isStreaming && isConnected) {
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

  /// Start recording in a lightweight monitoring mode while the AI is speaking
  /// (or buffering audio in [processing] state).
  /// When user voice is detected above the threshold the AI is interrupted
  /// automatically without needing any UI tap.
  ///
  /// [isPrePlayback] — pass `true` when starting BEFORE audio begins playing
  /// (i.e. during the processing/buffering phase). This disables the startup
  /// delay that normally guards against speaker echo, because at that point
  /// the speakers are completely silent.
  void _startBargeInMonitoring({bool isPrePlayback = false}) async {
    if (_recorder == null) return;

    // KEY FIX: If the recorder is still active from the listening phase
    // (race window — AI response arrived before the 1200 ms VAD timer fired),
    // do NOT return early.  Instead, take ownership of the stream:
    //   • cancel the listening subscription (stops false-EOT detection)
    //   • keep the recorder running — no stop/start gap
    //   • subscribe the barge-in listener to the same stream
    final alreadyRecording = _recorder!.isRecording();
    if (alreadyRecording) {
      // Hand off: silence the listening pipeline, reuse the recorder.
      _isStreaming = false;        // prevents VAD timer from sending EOT
      _vadSpeechDetected = false;
      _vadSilenceTimer?.cancel();
      _vadSilenceTimer = null;
      _maxListenTimer?.cancel();
      _maxListenTimer = null;
      await _audioChunkSubscription?.cancel();
      _audioChunkSubscription = null;
      print('🎤 Barge-in: taking ownership of active recorder (race-window handoff)');
    } else {
      // Normal path: start a fresh recording session for barge-in.
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
      } catch (e) {
        print('⚠️ Error starting barge-in monitoring: $e');
        return;
      }
    }

    print('🎤 Barge-in monitoring active (prePlayback=$isPrePlayback)');

    // Barge-in threshold: 2.5× the effective noise floor.
    // Residual AEC echo is typically 0.02–0.05 RMS; human speech 0.08–0.40.
    // 2.5× ambient floor catches normal conversational speech while still
    // rejecting echo transients, which are typically below 2× the floor.
    final bargeInThreshold = math.max(
      _vadEnergyThreshold,
      _adaptiveNoiseFloor * _noiseFloorHeadroom,
    ) * 3.5;

    // Startup delay: skip chunks during AEC convergence.
    // • isPrePlayback=true  → 120 ms (speakers silent, hardware settling only)
    // • isPrePlayback=false → 200 ms (browser AEC converges within ~200 ms)
    // Keeping this short is critical for perceived interruptibility.
    final startupDelay = isPrePlayback
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 400);
    final monitoringStart = DateTime.now();

    // Require 2 consecutive loud chunks before triggering barge-in.
    // At ~80–130 ms/chunk → 160–260 ms to confirm speech — fast enough to feel
    // immediate while still rejecting single-chunk noise spikes.
    int consecutiveLoudChunks = 0;
    const requiredConsecutiveChunks = 3;

    // Rolling buffer of recent chunks — replayed to server after barge-in so
    // Gemini hears the words that triggered the interruption.  The listener
    // only measures RMS and does NOT forward chunks, so without this buffer
    // a short interruption word ("stop", "wait") would be entirely lost and
    // Gemini would respond to silence (or not respond at all).
    final List<Uint8List> recentChunkBuffer = [];
    const int maxBufferedChunks = 12; // ~1 second of audio coverage

    _bargeInSubscription = _recorder!.audioChunkStream?.listen((chunk) {
      // Allow interruption during both speaking AND processing (buffering) states.
      if ((_state != LiveState.speaking && _state != LiveState.processing) ||
          !isConnected) {
        _stopBargeInMonitoring();
        return;
      }

      // Skip chunks during the startup delay window
      if (DateTime.now().difference(monitoringStart) < startupDelay) return;

      // Keep a rolling window of the most recent chunks for post-barge-in replay
      recentChunkBuffer.add(chunk);
      if (recentChunkBuffer.length > maxBufferedChunks) {
        recentChunkBuffer.removeAt(0);
      }

      final rms = _computeChunkRMS(chunk);
      onAmplitudeChanged?.call(rms.clamp(0.0, 1.0));

      if (rms > bargeInThreshold) {
        consecutiveLoudChunks++;
        if (consecutiveLoudChunks >= requiredConsecutiveChunks) {
          print('⚡ Auto barge-in: $consecutiveLoudChunks consecutive loud chunks (RMS: ${rms.toStringAsFixed(3)}, floor: ${bargeInThreshold.toStringAsFixed(3)})');
          // cancel() has immediate sync effect on event delivery even though
          // it returns a Future — safe to call without await inside a listener.
          // We keep the recorder running (no stop) to avoid an audio gap.
          final capturedChunks = List<Uint8List>.from(recentChunkBuffer);
          _bargeInSubscription?.cancel();
          _bargeInSubscription = null;
          _seamlessBargeinTransition(capturedChunks: capturedChunks);
        }
      } else {
        // Reset counter on any quiet chunk — must be continuously loud
        consecutiveLoudChunks = 0;
      }
    });
  }

  /// Interrupts the current AI response and immediately re-enters listening
  /// mode WITHOUT stopping the microphone.  This avoids the ~200 ms audio
  /// gap caused by a stop + restart cycle and ensures the words that triggered
  /// the barge-in are forwarded to the server as part of the new user turn.
  ///
  /// [capturedChunks] — the rolling buffer of PCM chunks that triggered the
  /// barge-in.  These were consumed by the barge-in monitor without being
  /// sent to the server; replaying them ensures Gemini hears the trigger word.
  void _seamlessBargeinTransition({List<Uint8List> capturedChunks = const <Uint8List>[]}) async {
    _interruptPending = true;
    await stopAudioPlayback();
    _sendMessage({'type': 'interrupt'});
    _isSpeaking = false;
    // Transition to connected first — this fires onStateChanged which calls
    // _stopAllAudio() in the screen, silencing the web audio immediately.
    _setState(LiveState.connected);
    // Keep _interruptPending = true through listening AND processing states.
    // Stale audio chunks from the interrupted AI turn keep arriving in the
    // network buffer even after the listening guard drops them.  When the user
    // finishes speaking and state moves to processing, those chunks would
    // resume playback (old voice re-appears) unless _interruptPending is still
    // true.  Cleared exclusively by 'ai_generating' — the first signal that
    // Gemini is responding to the NEW user turn.
    // Enter listening mode directly — recorder is already running,
    // so skip _ensureRecorderStopped() and go straight to streaming.
    _isStreaming = true;
    _vadSpeechDetected = false;
    _vadLastSpeechTime = null;
    _vadSilenceTimer?.cancel();
    _vadSilenceTimer = null;
    _maxListenTimer?.cancel();
    _maxListenTimer = null;
    _setState(LiveState.listening);
    _streamAudioChunks();  // re-subscribe to the still-running recorder stream

    // Replay the buffered trigger chunks to the server AFTER subscribing.
    // The barge-in monitor only reads RMS and never forwards audio, so these
    // chunks represent actual user speech that Gemini would otherwise miss.
    for (final chunk in capturedChunks) {
      if (_isStreaming && isConnected) {
        _sendMessage({'type': 'audio', 'data': base64Encode(chunk)});
      }
    }

    // ── CRITICAL: Pre-seed VAD speech state ─────────────────────────────────
    // _streamAudioChunks() above resets _vadSpeechDetected to false.  Override
    // it here because we KNOW the user spoke (3 consecutive loud chunks just
    // confirmed it).  Without this seed:
    //  • _vadSpeechDetected stays false → VAD silence timer never starts
    //  • stopListening() is never called → end_of_turn never sent to Gemini
    //  • Gemini never responds → state stays at Listening then drops to Ready
    // With this seed the 1200 ms silence timer fires automatically, guaranteeing
    // Gemini always receives turn_complete and responds after an interruption.
    _vadSpeechDetected = true;
    _vadLastSpeechTime = DateTime.now();

    print('⚡ Seamless barge-in complete — mic kept alive, now streaming to server');
  }

  /// Stop the barge-in monitoring mic and cancel the subscription.
  /// Pass [keepRecorder: true] to cancel only the subscription without
  /// stopping the underlying recorder (used by _seamlessBargeinTransition).
  void _stopBargeInMonitoring({bool keepRecorder = false}) async {
    await _bargeInSubscription?.cancel();
    _bargeInSubscription = null;
    // Only stop the recorder if it's running for barge-in (not in listening state)
    if (!keepRecorder &&
        _recorder != null &&
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
    _interruptPending = true;  // Prevent any queued _playBufferedAudio() from firing
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

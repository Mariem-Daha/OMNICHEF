
// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/widgets/ai_wave_overlay.dart';
import '../services/gemini_live_service.dart';
import '../../../core/services/api_service.dart';
import '../../vision/screens/ingredient_scanner_screen.dart';
import '../../vision/screens/dish_identifier_screen.dart';

class VoiceAssistantMode extends StatefulWidget {
  final VoidCallback onClose;
  final bool startWithCamera;

  const VoiceAssistantMode({
    super.key,
    required this.onClose,
    this.startWithCamera = false,
  });

  @override
  State<VoiceAssistantMode> createState() => _VoiceAssistantModeState();
}

class _VoiceAssistantModeState extends State<VoiceAssistantMode> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _rotationController;
  late AnimationController _waveController;   // drives horizontal wave motion
  
  final GeminiLiveService _geminiService = GeminiLiveService();

  // Audio player for UI thread playback
  AudioPlayer? _uiAudioPlayer;
  // Separate player for short UI earcons (entry/exit chimes) so it never
  // conflicts with the main speech-audio pipeline.
  AudioPlayer? _earconPlayer;
  // Completer that resolves when audio playback finishes OR is cancelled by barge-in.
  // Using a Completer lets stop() unblock the waiting future (onPlayerComplete.first
  // never fires on stop, which caused the service to get stuck after barge-in).
  Completer<void>? _audioCompleter;
  // Web-only: subscription to window.postMessage for CuisineeAudio speak_end.
  StreamSubscription? _webSpeakEndSub;

  // State
  String _aiState = "Initializing...";
  bool _isConnecting = true;
  bool _isSpeaking = false;

  // Greeting shown from the very first frame (no post-frame-callback delay).
  static const String _greetingText =
      "Welcome back, Chef! I\u2019m Cuisin\u00e9e \u2014 your AI kitchen companion. "
      "Ask me for a recipe, say \u2018what can I make with chicken\u2019, or just tell me what you\u2019re craving!";

  // Phrase cycling removed â€” simple labels kept

  // Siri wave visualizer
  double _micAmplitude = 0.0;          // live mic RMS fed by onAmplitudeChanged

  // Error debounce â€” prevents snackbar spam on repeated errors
  DateTime? _lastErrorShownAt;

  Widget? _activeContent;
  String _currentResponseText = "";
  // True when _activeContent was set by a function call (timer / recipe).
  // Prevents incoming transcripts from overwriting it.
  bool _functionContentActive = false;
  // True when a GuidedCookingView is the active content (suppresses greeting text).
  bool _isCookingMode = false;

  // GlobalKey to the active guided cooking session.
  // Lets the parent inject AI-issued timers straight into the current step.
  final GlobalKey<_GuidedCookingViewState> _cookingViewKey = GlobalKey();

  // ── Camera / video mode ─────────────────────────────────────────────────
  bool _cameraOn = false;
  CameraController? _cameraController;
  Timer? _frameTimer;
  bool _isSendingFrame = false;
  /// Periodic timer for automatic vision probing (step validation / ingredient ID).
  Timer? _visionProbeTimer;
  /// True once the AI has confirmed it can see an ingredient in the frame.
  /// Recipes and overlays must NOT appear before this flag is set.
  bool _ingredientDetected = false;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Initialize UI audio player
    _uiAudioPlayer = AudioPlayer();
    // Initialize earcon player and play entry chime immediately
    _earconPlayer = AudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _earconPlayer?.play(AssetSource('audio/chime_open.wav')).catchError((_) {});
    });

    _initGeminiLive();
    
    // Auto-start camera if requested by the hackathon home screen
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startCamera();
      });
    }
  }

  void _initGeminiLive() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _aiState = "Ready";
      });
    });

    // Setup callbacks
    _geminiService.onStateChanged = (state) {
      // Non-UI side-effects that don't need a frame boundary.
      // Stop audio on any state change AWAY from speaking. This correctly
      // handles barge-ins (speaking→connected), disconnections, and errors.
      // It is a safe no-op on normal transitions (processing, listening) because
      // the audio player is already idle by the time those states are reached.
      if (state != LiveState.speaking) {
        _stopAllAudio();
      }
      _updateRingSpeed(state);

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
           switch (state) {
              case LiveState.connecting:
                _aiState = "Connecting...";
                _isConnecting = true;
                break;
              case LiveState.connected:
                _aiState = "Ready";
                _isConnecting = false;
                break;
              case LiveState.listening:
                _aiState = "Listening...";
                _isConnecting = false;
                break;
              case LiveState.processing:
                _aiState = "Thinking...";
                _isConnecting = false;
                // A new AI turn is starting — clear the previous response text
                // (which may be the initial greeting or last AI reply) so the
                // upcoming transcript and audio land on a clean slate. Only
                // cleared when no recipe/timer function widget is displayed.
                if (!_functionContentActive) {
                  _currentResponseText = "";
                  _activeContent = null;
                }
                break;
              case LiveState.speaking:
                _aiState = "Speaking...";
                _isSpeaking = true;
                _isConnecting = false;
                break;
              case LiveState.error:
                _aiState = "Error";
                _isConnecting = false;
                break;
              default:
                _aiState = "Disconnected";
                _isConnecting = false;
           }

           if (state != LiveState.speaking) {
             _isSpeaking = false;
           }
        });
      });
    };

    _geminiService.onTranscriptReceived = (text) {
       if (!mounted) return;
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (!mounted) return;
         setState(() {
            // Always accumulate — Gemini streams transcript in fragments
            // (e.g. word-by-word) during the processing phase before audio
            // plays. Replacing instead of appending caused only the last
            // fragment to show, effectively making subtitles blank.
            _currentResponseText += text;

            // Detect ingredient confirmation from vision probe
            if (_cameraOn && !_ingredientDetected &&
                _currentResponseText.contains('INGREDIENT_DETECTED:')) {
              _ingredientDetected = true;
              // Now safe to start periodic probing for recipe suggestions
              _startVisionProbing();
            }

            // Show AI text response when no function widget is active.
            // In camera mode, suppress text until ingredient detected
            // (avoids showing "I can't see anything" as a big overlay).
            if (!_functionContentActive) {
              if (!_cameraOn || _ingredientDetected ||
                  _currentResponseText.contains("can't clearly see") ||
                  _currentResponseText.contains("can\u2019t clearly see")) {
                _activeContent = _buildTextResponse(_currentResponseText);
              }
            }
         });
       });
    };

    _geminiService.onFunctionExecuted = (name, result) {
       if (!mounted) return;
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (!mounted) return;
         setState(() {
            print("Function executed: $name, Result: $result");

            if (name == 'find_recipe' ||
                name == 'get_popular_recipes' ||
                name == 'get_recipes_by_category') {
               final recipes = result['recipes'] as List?;
               if (recipes != null && recipes.isNotEmpty) {
                  _activeContent = _GuidedCookingView(
                    key: _cookingViewKey,
                    recipes: recipes.cast<Map<String, dynamic>>(),
                  );
                  _functionContentActive = true;
                  _isCookingMode = true;
                  if (_cameraOn) _startVisionProbing();
               } else {
                  // No results: clear content and let the AI voice handle it gracefully
                  _activeContent = null;
                  _functionContentActive = false;
                  _isCookingMode = false;
               }
            } else if (name == 'advance_cooking_step') {
               // AI-driven step advancement — move the on-screen guide forward
               _cookingViewKey.currentState?.nextStep();
            } else if (name == 'get_recipe_details') {
               final recipeData = result['recipe'] as Map<String, dynamic>?;
               if (recipeData != null) {
                  _activeContent = _GuidedCookingView(
                    key: _cookingViewKey,
                    recipes: [recipeData],
                  );
                  _functionContentActive = true;
                  _isCookingMode = true;
                  if (_cameraOn) _startVisionProbing();
               }
            } else if (name == 'set_timer') {
               final timerData = result['timer'] as Map<String, dynamic>?;
               final minutes = ((timerData?['minutes'] as num?) ?? 1).toInt();
               // If a guided cooking session is on screen, inject into the active step.
               // Otherwise show a standalone countdown timer.
               if (_cookingViewKey.currentState != null) {
                 _cookingViewKey.currentState!.startTimerForCurrentStep(minutes);
               } else {
                 _activeContent = _buildTimerCard(minutes);
                 _functionContentActive = true;
               }
            } else if (name == 'start_step_timer') {
               // Voice-activated step timer — targets the active step card exclusively
               final timerData = result['timer'] as Map<String, dynamic>?;
               final minutes = ((timerData?['minutes'] as num?) ?? 1).toInt();
               if (_cookingViewKey.currentState != null) {
                 _cookingViewKey.currentState!.startTimerForCurrentStep(minutes);
               } else {
                 _activeContent = _buildTimerCard(minutes);
                 _functionContentActive = true;
               }
            }
         });
       });
    };
    
    _geminiService.onError = (error) {
       if (!mounted) return;
       // Debounce â€” only show one snackbar every 4 s to avoid spamming the user.
       final now = DateTime.now();
       if (_lastErrorShownAt != null &&
           now.difference(_lastErrorShownAt!).inSeconds < 4) return;
       _lastErrorShownAt = now;

       // Simplify technical error messages for end-users
       final friendly = _friendlyError(error);
       ScaffoldMessenger.of(context).clearSnackBars();
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(friendly),
           backgroundColor: Colors.red.shade800,
           behavior: SnackBarBehavior.floating,
           duration: const Duration(seconds: 3),
           action: SnackBarAction(
             label: 'OK',
             textColor: Colors.white,
             onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
           ),
         ),
       );
    };

    // Handle audio playback on UI thread
    _geminiService.onAudioReadyToPlay = (wavBytes, sampleRate) async {
      if (!mounted) return;

      // Cancel any dangling completer/sub from a previous turn.
      _stopAllAudio();

      _audioCompleter = Completer<void>();
      final completer = _audioCompleter!;

      try {
        if (kIsWeb) {
          // ── Web Audio API path (iOS Safari + all mobile browsers) ─────────
          // audioplayers_web uses HTML <audio>.play() which iOS Safari blocks
          // unless called synchronously inside a user-gesture handler.
          // CuisineeAudio.playPcmChunk (Web Audio API) stays unlocked for the
          // whole session once our first-tap unlock script fires.

          // Strip the 44-byte WAV header — what remains is raw Int16 PCM.
          final pcmBytes = wavBytes.sublist(44);
          final b64 = base64Encode(pcmBytes);

          // Subscribe BEFORE playing so we never miss a very short clip.
          _webSpeakEndSub?.cancel();
          _webSpeakEndSub = html.window.onMessage.listen((html.MessageEvent event) {
            try {
              final raw = event.data;
              if (raw == null) return;
              final source = (raw as dynamic)['source'] as String?;
              final type   = (raw as dynamic)['type']   as String?;
              if (source == 'CuisineeAudio' && type == 'speak_end') {
                if (!completer.isCompleted) completer.complete();
              }
            } catch (_) {}
          });

          // Resume AudioContext — iOS suspends it between interactions.
          try { js.context['CuisineeAudio']?.callMethod('resumePlayback', []); } catch (_) {}

          // Hand raw PCM to the Web Audio scheduler.
          try {
            js.context['CuisineeAudio']?.callMethod('playPcmChunk', [b64]);
          } catch (e) {
            if (!completer.isCompleted) completer.complete();
          }

          // Wait for speak_end or barge-in cancellation.
          await completer.future;
          _webSpeakEndSub?.cancel();
          _webSpeakEndSub = null;

        } else {
          // ── Native path (iOS app / Android) ───────────────────────────────
          await _uiAudioPlayer?.stop();
          await _uiAudioPlayer?.dispose();
          _uiAudioPlayer = AudioPlayer();
          await _uiAudioPlayer?.setReleaseMode(ReleaseMode.stop);

          _uiAudioPlayer!.onPlayerComplete.listen((_) {
            if (!completer.isCompleted) completer.complete();
          });
          _uiAudioPlayer!.onPlayerStateChanged.listen((state) {
            if (state == PlayerState.stopped || state == PlayerState.completed) {
              if (!completer.isCompleted) completer.complete();
            }
          });

          await _uiAudioPlayer?.play(BytesSource(wavBytes));
          await completer.future;
        }

        // Notify service — triggers auto-start mic after 300 ms breath pause.
        _geminiService.onAudioPlaybackComplete();

      } catch (e) {
        if (!completer.isCompleted) completer.complete();
        _geminiService.onAudioPlaybackComplete();
      }
    };

    // Connect real-time mic amplitude â†’ wave visualizer
    _geminiService.onAmplitudeChanged = (rms) {
      if (!mounted) return;
      // Use addPostFrameCallback to avoid setState during pointer/device update phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _micAmplitude = rms);
      });
    };

    // Connect — in the background while greeting is already showing
    final voiceWsUrl = ApiService.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    await _geminiService.connect('$voiceWsUrl/ws');

    // BUG FIX: Send greetingDelivered:true because the local hardcoded greeting
    // is already visible.  Sending false caused the server to trigger a second
    // Gemini greeting which (a) wasted a full turn before the user could speak,
    // (b) inflated the server-side adaptive noise floor while the speakers were
    // playing, making subsequent user speech harder to detect, and (c) produced
    // a confusing double-greeting experience.
    if (mounted) {
      final user = context.read<UserProvider>().user;
      if (user != null) {
        _geminiService.sendUserContext(
          healthFilters: user.healthFilters,
          allergies: user.allergies,
          dislikedIngredients: user.dislikedIngredients,
          tastePreferences: user.tastePreferences,
          cookingSkill: user.cookingSkill,
          greetingDelivered: true,
        );
      } else {
        _geminiService.sendUserContext(greetingDelivered: true);
      }
    }
  }
  
  void _toggleListening() async {
    // ── Ensure microphone permission on iOS/Android ────────────────────────
    if (!kIsWeb) {
      final micStatus = await Permission.microphone.status;
      if (micStatus.isPermanentlyDenied) {
        if (mounted) _showPermissionDeniedDialog('Microphone');
        return;
      }
      if (micStatus.isDenied) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          if (mounted) _showMicPermissionDenied();
          return;
        }
      }
    }

    // ── Barge-in: if AI is speaking, interrupt and start listening ─────────
    if (_geminiService.isSpeaking ||
        _geminiService.state == LiveState.speaking ||
        _geminiService.state == LiveState.processing) {
      _stopAllAudio();
      await _geminiService.sendInterrupt();
      setState(() {
        _isSpeaking = false;
        _aiState = "Listening...";
        _currentResponseText = "";
        // Do NOT wipe _activeContent — avoids the context-wipe bug after barge-in.
      });
      final started = await _geminiService.startListening();
      if (!started && mounted) _showMicPermissionDenied();
      return;
    }

    if (_geminiService.state == LiveState.listening) {
      await _geminiService.stopListening();
    } else {
      setState(() {
        _currentResponseText = "";
        if (!_functionContentActive) _activeContent = null;
      });
      final started = await _geminiService.startListening();
      if (!started && mounted) _showMicPermissionDenied();
    }
  }


  // ── Permission helpers ────────────────────────────────────────────────────
  void _showPermissionDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$permissionName Access Required'),
        content: Text(
          'Cuisinée needs $permissionName access to work properly. '
          'Please go to Settings and allow access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showMicPermissionDenied() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('Microphone access denied — tap to open Settings.'),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: openAppSettings,
        ),
      ));
  }

  // â”€â”€ Error helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Maps technical error strings to user-friendly one-liners.
  String _friendlyError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('microphone') || r.contains('mic') || r.contains('permission') ||
        r.contains('cameraaccess') || r.contains('camera_access')) {
      return kIsWeb
          ? 'Access needed — please allow microphone/camera in your browser.'
          : 'Access denied — please enable it in Settings > Cuisinée.';
    }
    if (r.contains('camera')) {
      return 'Could not start camera. Please check Settings > Cuisinée.';
    }
    if (r.contains('not connected') || r.contains('websocket') || r.contains('connection')) {
      return "Connection lost — tap the orb to reconnect.";
    }
    if (r.contains('timeout') || r.contains('timed out')) {
      return "Taking too long — please try again.";
    }
    final firstLine = raw.split('\n').first;
    return firstLine.length > 80 ? '\${firstLine.substring(0, 80)}…' : firstLine;
  }

  /// Adjust ring rotation speed to match the current assistant state.
  void _updateRingSpeed(LiveState state) {
    // Slow â†’ Fast: idle 20 s, speaking 12 s, thinking 9 s, listening 6 s
    final duration = switch (state) {
      LiveState.listening   => const Duration(seconds: 6),
      LiveState.processing  => const Duration(seconds: 9),
      LiveState.speaking    => const Duration(seconds: 12),
      _                     => const Duration(seconds: 20),
    };
    if (_rotationController.duration != duration) {
      _rotationController.stop();
      _rotationController.duration = duration;
      _rotationController.repeat();
    }
  }

  void _sendTextRequest(String text) {
    setState(() {
      _currentResponseText = "";
      _activeContent = null;
      _isCookingMode = false;
      _aiState = "Thinking...";
    });
    _geminiService.sendText(text);
  }

  // ── Camera / video mode helpers ──────────────────────────────────────────

  Future<void> _startCamera() async {
    // ── Step 1: Request camera permission (iOS / Android) ─────────────────
    if (!kIsWeb) {
      final camStatus = await Permission.camera.status;
      if (camStatus.isPermanentlyDenied) {
        if (mounted) _showPermissionDeniedDialog('Camera');
        return;
      }
      if (camStatus.isDenied) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          if (mounted) _showPermissionDeniedDialog('Camera');
          return;
        }
      }
    }

    // ── Step 2: Open the camera ────────────────────────────────────────────
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No camera found on this device.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      // Prefer back camera for cooking use
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = ctrl;
        _cameraOn = true;
        _ingredientDetected = false;
        // Clear any previous response text so camera view starts clean
        _currentResponseText = "";
        _activeContent = null;
        _functionContentActive = false;
        _isCookingMode = false;
      });
      _startFrameTimer();
      // Send camera-specific greeting; DO NOT fire vision probe yet —
      // wait until the AI detects an ingredient before suggesting recipes.
      _geminiService.sendText(
        "CAMERA_STARTED: The user just opened the camera. "
        "Greet them naturally and tell them to show you an ingredient.",
      );
    } on CameraException catch (e) {
      debugPrint('Camera start error: ${e.code} — ${e.description}');
      if (!mounted) return;
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted') {
        _showPermissionDeniedDialog('Camera');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start camera: ${e.description ?? e.code}'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Camera start error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start camera. Please try again.'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _startFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _captureAndSendFrame(),
    );
  }

  Future<void> _captureAndSendFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isSendingFrame) return;
    _isSendingFrame = true;
    try {
      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      _geminiService.sendVideoFrame(base64Encode(bytes));
    } catch (e) {
      debugPrint('Frame capture error: $e');
    } finally {
      _isSendingFrame = false;
    }
  }

  Future<void> _stopCamera() async {
    _frameTimer?.cancel();
    _frameTimer = null;
    _visionProbeTimer?.cancel();
    _visionProbeTimer = null;
    await _cameraController?.dispose();
    if (mounted) setState(() {
      _cameraController = null;
      _cameraOn = false;
      _ingredientDetected = false;
    });
  }

  // ── Automatic vision probing ──────────────────────────────────────────────

  /// Schedules periodic step-validation or ingredient-detection probes.
  /// Does NOT fire immediately — the camera greeting handles the first turn.
  /// Call after a recipe is loaded (cooking mode) or after the user explicitly
  /// asks the AI to look at an ingredient.
  void _startVisionProbing() {
    _visionProbeTimer?.cancel();
    _visionProbeTimer = null;
    if (_isCookingMode) {
      // Fire immediately for step validation in cooking mode
      _sendVisionProbe();
      _visionProbeTimer = Timer.periodic(
        const Duration(seconds: 12),
        (_) => _sendVisionProbe(),
      );
    } else {
      // Ingredient-ID mode: delay first probe by 3 s so the user has time
      // to point the camera before we start analysing.
      _visionProbeTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _sendVisionProbe(),
      );
    }
  }

  /// Sends one context-aware vision probe to the AI.
  /// In cooking mode: checks whether the current step is visually complete.
  /// Otherwise: identifies visible ingredients — only if confident.
  Future<void> _sendVisionProbe() async {
    if (!_cameraOn || _cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isCookingMode) {
      final stepText = _cookingViewKey.currentState?.getCurrentStepText();
      if (stepText == null || stepText.isEmpty) return;
      _geminiService.sendText(
        "VISION WATCH: Current step is '$stepText'. "
        "Look at the camera and tell me if this step is done.",
      );
    } else {
      // Ingredient-ID mode: strict confidence rules to prevent hallucination.
      _geminiService.sendText(
        "FRIDGE FORAGE: Look carefully at the camera frame. "
        "Only name ingredients you can clearly and confidently see. "
        "If nothing is clearly visible or confidence is low, say exactly: "
        "'I can\u2019t clearly see any ingredients yet \u2014 show me something and I\u2019ll help you cook with it!' "
        "Do NOT invent or guess ingredients. "
        "If you do see ingredients confidently, say 'INGREDIENT_DETECTED:' then name them, then suggest a recipe.",
      );
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await _captureAndSendFrame();
  }

  /// Stops the Web Audio API engine (web) AND the native audioplayer, then
  /// resolves any pending completer so no futures hang.
  // Stops any in-flight audio.
  // IMPORTANT: CuisineeAudio.interrupt() is only called when audio is actually
  // playing (completer is pending). Calling interrupt() unconditionally sets
  // _interrupted=true for 400 ms in JS, which would silently block the NEXT
  // turn's audio if the state-change callback fires after normal completion.
  void _stopAllAudio() {
    final bool inFlight = _audioCompleter != null && !_audioCompleter!.isCompleted;
    if (inFlight) {
      if (kIsWeb) {
        try { js.context['CuisineeAudio']?.callMethod('interrupt', []); } catch (_) {}
        _webSpeakEndSub?.cancel();
        _webSpeakEndSub = null;
      }
      _audioCompleter!.complete();
    }
    _uiAudioPlayer?.stop();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _visionProbeTimer?.cancel();
    _cameraController?.dispose();
    _geminiService.disconnect(); // idempotent — safe if already called by _closeWithChime
    _webSpeakEndSub?.cancel();
    // Explicitly stop before dispose so the native audio layer halts immediately
    // even if the above async disconnect hasn't finished yet.
    _stopAllAudio();
    _uiAudioPlayer?.dispose();
    _earconPlayer?.dispose();
    _breathingController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  /// Stops any ongoing AI speech, plays the exit chime, then calls widget.onClose.
  Future<void> _closeWithChime() async {
    // ── Shut down AI immediately so audio stops the moment the user taps close ──
    _stopAllAudio();
    // Disconnect service (stops mic, barge-in monitoring, WebSocket, audio buffer).
    // dispose() will call disconnect() again — that is safe/idempotent.
    await _geminiService.disconnect();

    try {
      await _earconPlayer?.play(AssetSource('audio/chime_close.wav'));
      await Future.delayed(const Duration(milliseconds: 850));
    } catch (_) {}
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final cameraReady = _cameraOn && _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraReady
          ? _buildCameraScreen()
          : Stack(
              children: [
                // Background ambient glow (audio-only mode)
                Positioned(
                  right: -100, top: -100,
                  child: Container(
                    width: 500, height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 100,
                          spreadRadius: 50,
                        ),
                      ],
                    ),
                  ),
                ),
                // Siri wave overlay
                Positioned.fill(
                  child: AiWaveOverlay(
                    waveController: _waveController,
                    micAmplitude: _micAmplitude,
                    voiceState: _geminiService.state,
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(cameraActive: false),
                      Expanded(
                        child: isLandscape
                            ? Row(
                                children: [
                                  Expanded(flex: 3, child: _buildLeftContentArea()),
                                  Expanded(flex: 2, child: _buildRightAvatarArea()),
                                ],
                              )
                            : Column(
                                children: [
                                  Expanded(flex: 4, child: _buildRightAvatarArea()),
                                  Expanded(flex: 6, child: _buildLeftContentArea()),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Full-screen camera view: edge-to-edge preview with a minimal floating HUD.
  /// No recipe overlays appear until an ingredient is detected.
  Widget _buildCameraScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Edge-to-edge camera preview — fills the entire screen
        _buildEdgeToEdgeCameraPreview(),

        // 2. Gradient scrim at the top so HUD buttons are readable
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 140,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),

        // 3. Gradient scrim at the bottom for subtitle area
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // 4. Floating HUD — state badge + stop-camera + close buttons
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildHeader(cameraActive: true),
          ),
        ),

        // 5. AI response subtitle — shown only after ingredient detected
        //    OR for "I can't see anything" messages (always show those briefly)
        if (_activeContent != null && _ingredientDetected)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _activeContent,
                ),
              ),
            ),
          )
        else if (_currentResponseText.isNotEmpty && !_ingredientDetected &&
                 (_currentResponseText.contains("can't clearly") ||
                  _currentResponseText.contains("can\u2019t clearly") ||
                  _currentResponseText.contains("Show me")))
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildCameraSubtitle(_currentResponseText),
              ),
            ),
          ),

        // 6. "Waiting for ingredient" hint shown while no ingredient detected yet
        if (!_ingredientDetected && _currentResponseText.isEmpty)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _buildCameraHint(),
              ),
            ),
          ),
      ],
    );
  }

  /// Properly scaled camera preview for all platforms including iPhone Safari.
  Widget _buildEdgeToEdgeCameraPreview() {
    if (!kIsWeb) {
      // Native: CameraPreview handles aspect ratio internally.
      // Wrap in FittedBox to avoid stretching on devices with odd aspect ratios.
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1920,
            height: _cameraController!.value.previewSize?.width ?? 1080,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }
    // Web (iPhone Safari / Chrome): use raw HTML video element via CameraPreview.
    // Flutter Web renders CameraPreview as a <video> tag; we need to ensure it
    // fills the screen and maintains aspect ratio without stretching.
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  /// Compact subtitle shown in camera mode for AI responses.
  Widget _buildCameraSubtitle(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text.replaceAll('INGREDIENT_DETECTED:', '').trim(),
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  /// "Point camera at an ingredient" hint shown before any detection.
  Widget _buildCameraHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Text(
          'Point camera at an ingredient',
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Shared header row: state badge + camera toggle + close button.
  Widget _buildHeader({required bool cameraActive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // State badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(cameraActive ? 0.55 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: cameraActive
                  ? Border.all(color: Colors.white.withOpacity(0.18))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSpeaking ? Icons.volume_up : Icons.mic,
                  color: _isSpeaking ? AppColors.secondary : AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _aiState.toUpperCase(),
                    key: ValueKey(_aiState),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cameraActive) ...[
                IconButton(
                  tooltip: 'Stop Camera',
                  onPressed: _stopCamera,
                  icon: const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.6)),
                ),
                const SizedBox(width: 6),
              ] else ...[
                IconButton(
                  tooltip: 'Switch to Camera Mode',
                  onPressed: _startCamera,
                  icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.12)),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: _closeWithChime,
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(cameraActive ? 0.5 : 0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftContentArea() {
    return Container(
      padding: _isCookingMode
          ? const EdgeInsets.fromLTRB(0, 12, 0, 0)
          : const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              // Priority: explicit widget > greeting/response text > idle chips.
              // Showing _currentResponseText as a fallback lets the greeting
              // appear in the very first frame (before _activeContent is set
              // by the post-frame callback) and survive rapid state changes.
              child: _activeContent
                  ?? (_currentResponseText.isNotEmpty
                      ? _buildTextResponse(_currentResponseText)
                      : (_cameraOn ? const SizedBox.shrink() : _buildIdleSuggestionList())),
            ),
          ),
          if (!_isCookingMode && _functionContentActive && _currentResponseText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _currentResponseText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdleSuggestionList() {
    return Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Try asking for...",
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 18,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 20),
        _buildVoiceCommandChip("Show me Thieboudienne recipe"),
        const SizedBox(height: 12),
        _buildVoiceCommandChip("Set a timer for 20 minutes"),
        const SizedBox(height: 12),
        _buildVoiceCommandChip("What can I cook with Carrots?"),
      ],
    );
  }

  Widget _buildVoiceCommandChip(String label) {
    return GestureDetector(
      onTap: () => _sendTextRequest(label),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTextResponse(String text) {
      if (text.isEmpty) return const SizedBox.shrink();
      
      return Container(
          key: ValueKey('text_response_${text.length}'), 
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: SingleChildScrollView(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.5,
              ),
            ),
          ),
      );
  }

  Widget _buildTimerCard(int minutes) {
    return _CountdownTimerWidget(
      key: ValueKey('timer_${minutes}_${DateTime.now().millisecondsSinceEpoch}'),
      totalSeconds: minutes * 60,
    );
  }

  // --- RIGHT SIDE: AVATAR ---
  Widget _buildRightAvatarArea() {
    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: GestureDetector(
          onTap: _toggleListening, // Tap to toggle listening
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating Rings
              _buildRotatingRings(),
              
              // Central Logo
              Hero(
                tag: 'app_logo',
                child: AnimatedBuilder(
                  animation: _breathingController,
                  builder: (context, child) {
                    final state = _geminiService.state;
                    // Orb size breathes with state energy
                    final baseSize = state == LiveState.speaking
                        ? 140.0   // slightly larger while AI talks
                        : 130.0;
                    final orbSize = baseSize + (_breathingController.value * 12);

                    // Glow: green=listening, gold=speaking/processing, dim=idle
                    final Color glowColor = state == LiveState.listening
                        ? AppColors.secondary
                        : (state == LiveState.speaking || state == LiveState.processing)
                            ? AppColors.primary
                            : Colors.white.withOpacity(0.3);
                    final glowOpacity = state == LiveState.connected ? 0.25 : 0.55;

                    return Container(
                      width: orbSize,
                      height: orbSize,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withOpacity(glowOpacity),
                            blurRadius: 45 + (_breathingController.value * 25),
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/gemini_logo.png',
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
              ),
              
              // Mic ripple effect to show listening state
               if (_geminiService.isListening) 
                 Positioned.fill(
                   child: _buildMicRipple(),
                 ),

              // Speaker pulse while AI is talking
              if (_geminiService.state == LiveState.speaking)
                Positioned.fill(
                  child: _buildSpeakerPulse(),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMicRipple() {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        // Scale the ripple with live mic amplitude for a reactive feel.
        // When the user is loud the ring pulses outward.
        final amplitudeBoost = (_micAmplitude * 4.0).clamp(0.0, 1.0);
        final opacity = (0.3 + amplitudeBoost * 0.5) *
            (1 - _breathingController.value * 0.5);
        final strokeWidth = 3.0 + amplitudeBoost * 5.0;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.secondary.withOpacity(opacity.clamp(0.0, 1.0)),
              width: strokeWidth,
            ),
          ),
        );
      },
    );
  }

  /// Soft golden pulse ring shown while the AI is speaking.
  Widget _buildSpeakerPulse() {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        final pulse = _breathingController.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity((0.4 * (1 - pulse)).clamp(0.0, 1.0)),
              width: 3.0 + pulse * 4.0,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRotatingRings() {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ring 1
            Transform.rotate(
              angle: _rotationController.value * 2 * math.pi,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                ),
              ),
            ),
             // Ring 2 (Counter-rotate)
            Transform.rotate(
              angle: -_rotationController.value * 2 * math.pi * 1.5,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.4),
                    width: 2,
                    style: BorderStyle.solid
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 216,
                    height: 216,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.transparent, // Dash effect could go here
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Ring 3 (Inner Orbit)
             Transform.rotate(
              angle: _rotationController.value * 2 * math.pi * 0.8,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                 child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}

// =============================================================================
// GUIDED COOKING SESSION
// Full sous-chef experience: recipe browser, step-by-step guide, per-step
// timers, ingredient checklist. Parent holds a GlobalKey so it can call
// startTimerForCurrentStep() when the AI issues a set_timer function call.
// =============================================================================

class _GuidedCookingView extends StatefulWidget {
  final List<Map<String, dynamic>> recipes;
  const _GuidedCookingView({super.key, required this.recipes});

  @override
  State<_GuidedCookingView> createState() => _GuidedCookingViewState();
}

class _GuidedCookingViewState extends State<_GuidedCookingView> {
  int _recipeIdx = 0;
  int _stepIdx = 0;
  bool _guidedMode = true; // auto Cook mode — no hands needed

  // Slide direction for step transitions: +1 = forward (right-in), -1 = backward (left-in)
  int _stepDirection = 1;

  // Earcon player for timer tick/done sounds
  final AudioPlayer _earconPlayer = AudioPlayer();

  // Per-step timers: stepIndex → controller
  final Map<int, _StepTimerController> _timers = {};
  // Ingredient check-off — auto-updated as steps advance
  final Set<int> _checked = {};

  Map<String, dynamic> get _recipe =>
      widget.recipes[_recipeIdx.clamp(0, widget.recipes.length - 1)];
  List<dynamic> get _steps => (_recipe['steps'] as List?) ?? [];
  List<dynamic> get _ingredients => (_recipe['ingredients'] as List?) ?? [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onStepChanged(0);
    });
  }

  @override
  void dispose() {
    for (final t in _timers.values) t.cancel();
    _earconPlayer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_GuidedCookingView old) {
    super.didUpdateWidget(old);
    if (old.recipes != widget.recipes) {
      _recipeIdx = 0;
      _stepIdx = 0;
      _timers.clear();
      _checked.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onStepChanged(0);
      });
    }
  }

  /// Called whenever the active step changes. Auto-checks proportional
  /// ingredients relative to cooking progress.
  void _onStepChanged(int step) {
    if (!mounted) return;
    setState(() => _stepIdx = step);

    // Auto-check ingredients proportional to progress
    final total = _ingredients.length;
    if (total > 0) {
      final fraction = (step + 1) / _steps.length.clamp(1, _steps.length);
      final upTo = (fraction * total).ceil();
      for (int i = 0; i < upTo; i++) {
        _checked.add(i);
      }
    }
    // Timer is voice-activated — Gemini calls start_step_timer(minutes)
    // after narrating each step. No auto-start here.
  }

  void _launchTimer(int minutes) {
    if (!mounted) return;
    // Cancel any existing timer for this step before creating a new one
    _timers[_stepIdx]?.cancel();
    final ctrl = _StepTimerController(minutes * 60);
    _timers[_stepIdx] = ctrl;
    ctrl.start(() {
      if (mounted) {
        // Play soft tick for each second in the last 10 seconds
        if (ctrl.remaining > 0 && ctrl.remaining <= 10) {
          _earconPlayer.play(AssetSource('audio/timer_tick.wav')).catchError((_) {});
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
      if (ctrl.isDone) {
        _earconPlayer.play(AssetSource('audio/timer_done.wav')).catchError((_) {});
        _tryAutoAdvance();
      }
    });
    if (mounted) setState(() {});
  }

  void _attachTimerSeconds(int stepIdx, int totalSecs) {
    if (!mounted) return;
    _timers[stepIdx]?.cancel();
    final ctrl = _StepTimerController(totalSecs);
    _timers[stepIdx] = ctrl;
    ctrl.start(() {
      if (mounted) {
        // Play soft tick for each second in the last 10 seconds
        if (ctrl.remaining > 0 && ctrl.remaining <= 10) {
          _earconPlayer.play(AssetSource('audio/timer_tick.wav')).catchError((_) {});
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
      if (ctrl.isDone) {
        _earconPlayer.play(AssetSource('audio/timer_done.wav')).catchError((_) {});
        _tryAutoAdvance();
      }
    });
    if (mounted) setState(() {});
  }

  void _removeTimer(int stepIdx) {
    _timers[stepIdx]?.cancel();
    _timers.remove(stepIdx);
    if (mounted) setState(() {});
  }

  void _tryAutoAdvance() {
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_stepIdx < _steps.length - 1) {
        _onStepChanged(_stepIdx + 1);
      }
    });
  }

  /// Called by the parent's GlobalKey when AI issues a set_timer function call.
  void startTimerForCurrentStep(int minutes) => _launchTimer(minutes);

  /// Called by the parent when AI issues an advance_cooking_step function call.
  void nextStep() {
    if (!mounted) return;
    if (_stepIdx < _steps.length - 1) {
      _stepDirection = 1;
      setState(() => _stepIdx++);
      _onStepChanged(_stepIdx);
    }
  }

  /// Returns the current step's instruction text for Vision Watch probes.
  String? getCurrentStepText() {
    if (_steps.isEmpty || _stepIdx >= _steps.length) return null;
    final step = _steps[_stepIdx];
    if (step is Map) return (step['instruction'] ?? step['text'] ?? '').toString();
    return step.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recipe selector row (only when multiple recipes present)
        if (widget.recipes.length > 1) ...[
          SizedBox(
            height: 36,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.06, 0.94, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: widget.recipes.length,
              itemBuilder: (_, i) {
                final sel = i == _recipeIdx;
                return GestureDetector(
                  onTap: () {
                    for (final t in _timers.values) t.cancel();
                    setState(() {
                      _recipeIdx = i; _stepIdx = 0;
                      _guidedMode = true;
                      _timers.clear(); _checked.clear();
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _onStepChanged(0);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.recipes[i]['name'] ?? 'Recipe ${i + 1}',
                      style: TextStyle(
                        color: sel ? Colors.black : Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        Expanded(
          child: Builder(builder: (ctx) {
            final heroUrl = _guidedMode
                ? (_recipe['image_url'] ?? _recipe['imageUrl'] ?? '').toString()
                : '';
            return Stack(
              children: [
                // Fallback dark gradient — shows when image unavailable/loading
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F1F18), Color(0xFF090F0C)],
                      ),
                    ),
                  ),
                ),
                if (heroUrl.isNotEmpty) ...[
                  Positioned.fill(
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Image.network(
                          heroUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(color: Colors.black.withOpacity(0.60)),
                  ),
                ],
                // Folder tabs — anchored flush to top of the card
                Positioned(
                  top: 0, left: 12, right: 0,
                  child: Row(
                    children: [
                      _modeTab('Recipe', !_guidedMode,
                          () => setState(() => _guidedMode = false)),
                      const SizedBox(width: 6),
                      _modeTab('Cook', _guidedMode,
                          () { setState(() { _guidedMode = true; _stepIdx = 0; }); _onStepChanged(0); }),
                    ],
                  ),
                ),
                Positioned.fill(
                  top: 36,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _guidedMode
                        ? _buildGuidedView(key: const ValueKey('guided'))
                        : _buildBrowseView(key: const ValueKey('browse')),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // â”€â”€ Mode tab pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _modeTab(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? AppColors.primary : Colors.white.withOpacity(0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.primary : Colors.white.withOpacity(0.45),
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

  // â”€â”€ BROWSE MODE: ingredient checklist + step overview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBrowseView({Key? key}) {
    final r = _recipe;
    final cookTime = (r['cook_time'] ?? r['cookTime'] ?? 0) as num;
    final prepTime = (r['prep_time'] ?? r['prepTime'] ?? 0) as num;
    final servings = r['servings'] ?? 0;
    final calories = r['calories'] ?? 0;
    final difficulty = r['difficulty'] ?? '';
    final imageUrl = r['image_url'] ?? r['imageUrl'] ?? '';

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero image
              if (imageUrl.toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl.toString(),
                    height: 110, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (imageUrl.toString().isNotEmpty) const SizedBox(height: 10),

              Text(r['name'] ?? '',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              if ((r['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r['description'].toString(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),
              ],

              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 5, children: [
                if (prepTime > 0) _badge(Icons.hourglass_top, 'Prep ${prepTime}m'),
                if (cookTime > 0) _badge(Icons.timer, 'Cook ${cookTime}m'),
                if (servings > 0) _badge(Icons.people_outline, '$servings serv.'),
                if (calories > 0) _badge(Icons.local_fire_department, '$calories kcal'),
                if (difficulty.isNotEmpty) _badge(Icons.bar_chart, difficulty),
              ]),

              // Ingredient checklist
              if (_ingredients.isNotEmpty) ...[
                const SizedBox(height: 14),
                _sectionHeader(Icons.local_grocery_store, 'INGREDIENTS', AppColors.primary),
                const SizedBox(height: 8),
                ..._ingredients.asMap().entries.map((e) {
                  final i = e.key;
                  final ing = e.value;
                  final name = ing is Map
                      ? (ing['name'] ?? ing.toString())
                      : ing.toString();
                  final amount = ing is Map
                      ? ('${ing['amount'] ?? ''} ${ing['unit'] ?? ''}'.trim())
                      : '';
                  final checked = _checked.contains(i);
                  return GestureDetector(
                    onTap: () => setState(() =>
                        checked ? _checked.remove(i) : _checked.add(i)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: checked
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: checked
                                      ? AppColors.primary
                                      : Colors.white.withOpacity(0.3)),
                            ),
                            child: checked
                                ? const Icon(Icons.check,
                                    color: Colors.black, size: 12)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          if (amount.isNotEmpty)
                            Text('$amount ',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: checked
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.white,
                                fontSize: 13,
                                decoration: checked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor:
                                    Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              // Steps overview (numbered, no timers in browse mode)
              if (_steps.isNotEmpty) ...[
                const SizedBox(height: 14),
                _sectionHeader(Icons.format_list_numbered,
                    'STEPS (${_steps.length})', AppColors.secondary),
                const SizedBox(height: 8),
                ..._steps.asMap().entries.map((e) {
                  final step = e.value;
                  final instr = step is Map
                      ? (step['instruction'] ?? step['description'] ?? step.toString())
                      : step.toString();
                  final dur = step is Map
                      ? ((step['duration_minutes'] ?? step['duration'] ?? 0) as num).toInt()
                      : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stepCircle(e.key + 1, false),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(instr.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.45)),
                              if (dur > 0)
                                Text('â± ${dur}m',
                                    style: TextStyle(
                                        color: AppColors.primary.withOpacity(0.8),
                                        fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Start Cooking CTA
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                setState(() { _guidedMode = true; _stepIdx = 0; });
                _onStepChanged(0);
              },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.outdoor_grill_rounded, size: 18, color: Colors.black),
                      SizedBox(width: 8),
                      Text('Start Cooking',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ GUIDED MODE: one step at a time with inline timer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildGuidedView({Key? key}) {
    final total = _steps.length;
    if (total == 0) return _buildBrowseView(key: key);

    final step = _steps[_stepIdx];
    final instr = step is Map
        ? (step['instruction'] ?? step['description'] ?? step.toString())
        : step.toString();
    final recipeDur = step is Map
        ? ((step['duration_minutes'] ?? step['duration'] ?? 0) as num).toInt()
        : 0;
    final timer = _timers[_stepIdx];

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active step card — wrapped in AnimatedSwitcher for directional slide
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            transitionBuilder: (child, animation) {
              // Determine slide direction: incoming vs outgoing child
              final isIncoming = child.key == ValueKey(_stepIdx);
              final begin = isIncoming
                  ? Offset(_stepDirection.toDouble(), 0.0)
                  : Offset(-_stepDirection.toDouble(), 0.0);
              return SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero)
                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
                  child: child,
                ),
              );
            },
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.center,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: _ActiveStepCard(
              key: ValueKey(_stepIdx),
              stepIdx: _stepIdx,
              totalSteps: total,
              instruction: instr.toString(),
              recipeDuration: recipeDur,
              timer: timer,
              onStartTimer: (secs) => _attachTimerSeconds(_stepIdx, secs),
              onCancelTimer: () => _removeTimer(_stepIdx),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Navigation
        Row(children: [
          Expanded(
            child: _navButton(
              label: 'Previous',
              icon: Icons.arrow_back_ios,
              iconFirst: true,
              enabled: _stepIdx > 0,
              filled: false,
              onTap: () {
                _stepDirection = -1;
                setState(() => _stepIdx--);
                _onStepChanged(_stepIdx);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _stepIdx < total - 1
                ? _navButton(
                    label: 'Next Step',
                    icon: Icons.arrow_forward_ios,
                    iconFirst: false,
                    enabled: true,
                    filled: true,
                    onTap: () {
                      _stepDirection = 1;
                      setState(() => _stepIdx++);
                      _onStepChanged(_stepIdx);
                    },
                  )
                : GestureDetector(
                    onTap: () => setState(() => _guidedMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.green.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('🎉', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 6),
                          Text('All Done!',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
          ),
        ]),

        // Next step preview
        if (_stepIdx < total - 1) ...[
          const SizedBox(height: 8),
          _buildNextPreview(_stepIdx + 1),
        ],
      ],
    );
  }

  Widget _navButton({
    required String label,
    required IconData icon,
    required bool iconFirst,
    required bool enabled,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled && enabled
              ? AppColors.primary
              : (!filled && enabled
                  ? Colors.white.withOpacity(0.07)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: !filled
              ? Border.all(
                  color: enabled
                      ? Colors.white.withOpacity(0.15)
                      : Colors.transparent)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconFirst)
              Icon(icon,
                  size: 12,
                  color: enabled
                      ? (filled ? Colors.black : Colors.white)
                      : Colors.white.withOpacity(0.2)),
            if (iconFirst) const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  color: enabled
                      ? (filled ? Colors.black : Colors.white)
                      : Colors.white.withOpacity(0.2),
                  fontSize: 13,
                  fontWeight: filled ? FontWeight.bold : FontWeight.normal,
                )),
            if (!iconFirst) const SizedBox(width: 4),
            if (!iconFirst)
              Icon(icon,
                  size: 12,
                  color: enabled
                      ? (filled ? Colors.black : Colors.white)
                      : Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildNextPreview(int idx) {
    final step = _steps[idx];
    final instr = step is Map
        ? (step['instruction'] ?? step['description'] ?? step.toString())
        : step.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Text('Next: ',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(instr.toString(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                    height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _sectionHeader(IconData icon, String label, Color color) => Row(
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3)),
        ],
      );

  Widget _stepCircle(int num, bool active) => Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          color: active
              ? AppColors.secondary
              : AppColors.secondary.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.secondary, width: 1),
        ),
        child: Center(
          child: Text('$num',
              style: TextStyle(
                  color: active ? Colors.white : AppColors.secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ),
      );

  Widget _badge(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 10),
            const SizedBox(width: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

// =============================================================================
// ACTIVE STEP CARD â€” large prominent card for the current cooking step.
// Self-contained so it can run its own local setState for timer display.
// =============================================================================

class _ActiveStepCard extends StatelessWidget {
  final int stepIdx;
  final int totalSteps;
  final String instruction;
  final int recipeDuration;        // minutes from recipe data (0 = no built-in timer)
  final _StepTimerController? timer;
  final void Function(int totalSecs) onStartTimer;
  final VoidCallback onCancelTimer;

  const _ActiveStepCard({
    super.key,
    required this.stepIdx,
    required this.totalSteps,
    required this.instruction,
    required this.recipeDuration,
    required this.timer,
    required this.onStartTimer,
    required this.onCancelTimer,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 36,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thin progress bar — flush with top edge of card
              LinearProgressIndicator(
                value: totalSteps > 0 ? (stepIdx + 1) / totalSteps : 0.0,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 3,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.secondary, Color(0xFF0D5C40)],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withOpacity(0.55),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              'STEP ${stepIdx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${stepIdx + 1} / $totalSteps',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.40),
                              fontSize: 12,
                            ),
                          ),
                          if (recipeDuration > 0 && timer == null) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Text(
                                '\u23F1 ${recipeDuration}m',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.60),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildBulletInstructions(instruction),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildTimerSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Splits a cooking instruction into scannable bullet-point sentences.
  Widget _buildBulletInstructions(String text) {
    final rawParts = text.trim().split(RegExp(r'\.\s+(?=[A-Z0-9“‘”\u0022])'));
    final parts = rawParts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length <= 1) {
      return Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.75));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((s) {
        final sentence =
            (s.endsWith('.') || s.endsWith('!') || s.endsWith('?')) ? s : '$s.';
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 9.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sentence,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.75,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimerSection() {
    // Timer is voice-activated (start_step_timer tool) — not shown until triggered
    if (timer == null) return const SizedBox.shrink();
    final t = timer!;
    final mins = t.remaining ~/ 60;
    final secs = t.remaining % 60;
    final display =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final ringColor = t.isDone ? Colors.greenAccent : AppColors.primary;

    // Compact circular ring — sits inline at the bottom of the card.
    // Looks like an Apple Watch ring, not a web-form box.
    return Row(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              SizedBox(
                width: 72, height: 72,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation(
                      Colors.white.withOpacity(0.07)),
                ),
              ),
              // Progress arc
              SizedBox(
                width: 72, height: 72,
                child: CircularProgressIndicator(
                  value: t.isDone ? 1.0 : (1.0 - t.progress),
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(ringColor),
                ),
              ),
              // Centre label
              t.isDone
                  ? Icon(Icons.check_rounded, color: Colors.greenAccent, size: 22)
                  : Text(
                      display,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.isDone ? "Time's up!" : 'Timer running',
                style: TextStyle(
                  color: ringColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.isDone ? 'Check your dish!' : 'Tap × to cancel',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 11),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onCancelTimer,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close,
                color: Colors.white.withOpacity(0.45), size: 14),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// STEP TIMER CONTROLLER â€” lightweight per-step countdown.
// =============================================================================

class _StepTimerController {
  final int totalSeconds;
  int remaining;
  bool isDone = false;
  bool isRunning = false;
  Timer? _ticker;

  _StepTimerController(this.totalSeconds) : remaining = totalSeconds;

  void start(void Function() onTick) {
    isRunning = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining > 0) {
        remaining--;
        onTick();
      } else {
        isDone = true;
        isRunning = false;
        _ticker?.cancel();
        onTick();
      }
    });
  }

  void cancel() {
    _ticker?.cancel();
    isRunning = false;
  }

  double get progress =>
      totalSeconds > 0 ? remaining / totalSeconds : 0.0;
}

// =============================================================================
// Live Countdown Timer Widget (standalone â€” used when no recipe is loaded)
// =============================================================================

class _CountdownTimerWidget extends StatefulWidget {
  final int totalSeconds;
  const _CountdownTimerWidget({super.key, required this.totalSeconds});

  @override
  State<_CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<_CountdownTimerWidget> {
  late int _remaining;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((__) {
        if (!mounted) return;
        setState(() {
          if (_remaining > 0) {
            _remaining--;
          } else {
            _done = true;
            _timer?.cancel();
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = _remaining ~/ 60;
    final secs = _remaining % 60;
    final display =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final total = widget.totalSeconds;
    final progress = total > 0 ? _remaining / total : 0.0;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _done
              ? [Colors.green.shade900, Colors.black]
              : [AppColors.surfaceDark, Colors.black],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: _done
              ? Colors.greenAccent.withOpacity(0.5)
              : AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress ring
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              valueColor: AlwaysStoppedAnimation(
                _done ? Colors.greenAccent : AppColors.primary,
              ),
              backgroundColor: Colors.white.withOpacity(0.08),
            ),
          ),
          // Time display
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _done ? 'âœ“ Done!' : display,
                style: TextStyle(
                  color: _done ? Colors.greenAccent : Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _done
                    ? 'Timer finished!'
                    : '${widget.totalSeconds ~/ 60} min timer',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


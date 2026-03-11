// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/providers/user_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Full-screen AI Sous Chef — streams camera + mic to Gemini Live on the backend.
///
/// Audio pipeline (Web / Chrome):
///   Mic  → Web Audio ScriptProcessorNode (JS) → 16 kHz PCM → base64 → WS
///   WS   → base64 → 24 kHz PCM → Web Audio scheduled playback (JS)
///
/// Video pipeline:
///   CameraController.takePicture() every 1.5 s → base64 JPEG → WS
// ─────────────────────────────────────────────────────────────────────────────
class CookingCompanionScreen extends StatefulWidget {
  const CookingCompanionScreen({super.key});

  @override
  State<CookingCompanionScreen> createState() =>
      _CookingCompanionScreenState();
}

class _CookingCompanionScreenState extends State<CookingCompanionScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── Camera ──────────────────────────────────────────────────────────────────
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraFailed = false;
  int _selectedCameraIndex = 0;

  // ── WebSocket ────────────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _sessionId;

  // ── Frame streaming ────────────────────────────────────────────────────────
  Timer? _frameTimer;
  bool _isSendingFrame = false;

  // ── Mic state ────────────────────────────────────────────────────────────────
  bool _micActive = false;
  bool _isUserSpeaking = false;
  StreamSubscription? _msgSub;   // dart:html window.onMessage subscription

  // ── AI speaking state ─────────────────────────────────────────────────────
  bool _isAiSpeaking = false;

  // ── Conversation ─────────────────────────────────────────────────────────
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollCtrl = ScrollController();

  // ── Recipe overlay ────────────────────────────────────────────────────────
  Map<String, dynamic>? _recipeCard;

  // ── Text input fallback ────────────────────────────────────────────────────
  final TextEditingController _textCtrl = TextEditingController();
  bool _showText = false;

  // ── Cooking timer overlay ──────────────────────────────────────────────────
  Timer? _cookingTimer;
  int _timerSecondsLeft = 0;
  bool _timerRunning = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ─── Camera ────────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) setState(() => _cameraFailed = true);
        _connect();
        return;
      }
      await _setupCamera(_selectedCameraIndex);
    } catch (e) {
      debugPrint('Camera init: $e');
      if (mounted) setState(() => _cameraFailed = true);
      _connect();
    }
  }

  Future<void> _setupCamera(int index) async {
    await _cameraController?.dispose();
    final ctrl = CameraController(
      _cameras![index],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = ctrl;
        _cameraReady = true;
      });
      _connect();
    } catch (e) {
      debugPrint('Camera setup: $e');
      if (mounted) setState(() => _cameraFailed = true);
      _connect();
    }
  }

  // ─── WebSocket ─────────────────────────────────────────────────────────────
  Future<void> _connect() async {
    if (_isConnecting || _isConnected) return;
    if (mounted) setState(() => _isConnecting = true);

    final wsUrl = ApiService().visionCompanionWsUrl;
    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _wsSub = _channel!.stream.listen(
        _onServerMessage,
        onError: (e) { debugPrint('WS error: $e'); _onDisconnect(); },
        onDone: _onDisconnect,
        cancelOnError: false,
      );
      // Send user context immediately (before waiting for "connected" reply)
      final user = context.read<UserProvider>().user;
      _send({
        'type': 'user_context',
        if (user != null) ...{
          'health_filters':       user.healthFilters       ?? [],
          'allergies':            user.allergies           ?? [],
          'disliked_ingredients': user.dislikedIngredients ?? [],
          'cooking_skill':        user.cookingSkill,
          'taste_preferences':    user.tastePreferences    ?? [],
        },
      });
    } catch (e) {
      debugPrint('WS connect: $e');
      setState(() { _isConnecting = false; _isConnected = false; });
      _addMsg('Could not connect to AI. Please check your connection.', isError: true);
    }
  }

  void _send(Map<String, dynamic> payload) {
    try { _channel?.sink.add(jsonEncode(payload)); } catch (_) {}
  }

  // ─── Server messages ────────────────────────────────────────────────────────
  void _onServerMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';
      switch (type) {
        case 'connected':
          _startFrameTimer();
          _startMic();
          if (!mounted) break;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _isConnecting = false;
              _isConnected = true;
              _sessionId = data['session_id'] as String?;
            });
          });
          break;
        case 'audio':
          final b64 = data['data'] as String?;
          if (b64 != null && b64.isNotEmpty) _playChunk(b64);
          break;
        case 'turn_complete':
          if (!mounted) break;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isAiSpeaking = false);
          });
          break;
        case 'ai_generating':
          if (!_isAiSpeaking && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isAiSpeaking = true);
            });
          }
          break;
        case 'interrupted':
          _jsInterrupt();
          if (!mounted) break;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isAiSpeaking = false);
          });
          break;
        case 'interrupt_ack':
          _jsInterrupt();
          if (!mounted) break;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isAiSpeaking = false);
          });
          break;
        case 'transcript':
          final text = data['text'] as String? ?? '';
          if (text.isNotEmpty) _addMsg(text, isAi: true);
          break;
        case 'function_executed':
          _handleFunctionResult(data);
          break;
        case 'error':
          _addMsg('⚠ ${data['error'] ?? 'Unknown error'}', isError: true);
          break;
      }
    } catch (e) {
      debugPrint('Message parse: $e');
    }
  }

  void _onDisconnect() {
    _frameTimer?.cancel();
    _stopMic();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() { _isConnected = false; _isConnecting = false; });
    });
  }

  // ─── Function results ───────────────────────────────────────────────────────
  void _handleFunctionResult(Map<String, dynamic> data) {
    final fn     = data['function'] as String? ?? '';
    final result = data['result']   as Map<String, dynamic>? ?? {};
    if (fn == 'set_timer') {
      final minutes = (data['args']?['minutes'] as num?)?.toInt() ?? 0;
      _startCookingTimer(minutes);
      return;
    }
    final recipe = _extractFirstRecipe(result);
    if (recipe != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _recipeCard = recipe);
      });
    }
  }

  Map<String, dynamic>? _extractFirstRecipe(Map<String, dynamic> r) {
    if (r.containsKey('recipes')) {
      final list = r['recipes'];
      if (list is List && list.isNotEmpty) return Map<String, dynamic>.from(list.first as Map);
    }
    if (r.containsKey('recipe')) return Map<String, dynamic>.from(r['recipe'] as Map);
    if (r.containsKey('name'))   return r;
    return null;
  }

  // ─── Frame streaming ────────────────────────────────────────────────────────
  void _startFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _captureFrame());
  }

  Future<void> _captureFrame() async {
    if (!_isConnected || _isSendingFrame) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    _isSendingFrame = true;
    try {
      final file  = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      if (_isConnected) _send({'type': 'video_frame', 'data': base64Encode(bytes)});
    } catch (e) {
      debugPrint('Frame: $e');
    } finally {
      _isSendingFrame = false;
    }
  }

  // ─── Microphone (JS bridge via window.postMessage) ─────────────────────────
  void _startMic() {
    if (!kIsWeb) return;
    try {
      // Subscribe to window messages from CuisineeAudio (JS)
      _msgSub?.cancel();
      _msgSub = html.window.onMessage.listen((html.MessageEvent event) {
        try {
          final raw = event.data;
          if (raw == null) return;
          // raw is a JS object; read properties via js.context
          // Dart html wraps JS objects as JsObject
          final source = (raw as dynamic)['source'] as String?;
          if (source != 'CuisineeAudio') return;
          final type = (raw as dynamic)['type'] as String?;
          if (type == 'mic_chunk') {
            final b64 = (raw as dynamic)['data'] as String?;
            if (b64 != null && _isConnected && _micActive) {
              // Barge-in: interrupt AI if it's talking
              if (_isAiSpeaking) {
                _send({'type': 'interrupt'});
                _jsInterrupt();
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _isAiSpeaking = false);
                  });
                }
              }
              _send({'type': 'audio', 'data': b64});
            }
          } else if (type == 'vad') {
            final speaking = (raw as dynamic)['speaking'] as bool?;
            if (speaking != null && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isUserSpeaking = speaking);
              });
            }
          } else if (type == 'speak_end') {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isAiSpeaking = false);
              });
            }
          }
        } catch (_) {}
      });

      // Tell JS audio engine to start mic
      js.context['CuisineeAudio'].callMethod('startMic', []);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _micActive = true);
        });
      }

    } catch (e) {
      debugPrint('Mic start: $e');
    }
  }

  void _stopMic() {
    if (!kIsWeb) return;
    try { js.context['CuisineeAudio']?.callMethod('stopMic', []); } catch (_) {}
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _micActive = false; _isUserSpeaking = false; });
      });
    }
  }

  void _toggleMic() {
    if (_micActive) _stopMic(); else _startMic();
  }

  // ─── Playback (JS bridge) ───────────────────────────────────────────────────
  void _playChunk(String b64) {
    if (!kIsWeb) return;
    try {
      js.context['CuisineeAudio']?.callMethod('playPcmChunk', [b64]);
      if (!_isAiSpeaking && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isAiSpeaking = true);
        });
      }
    } catch (e) {
      debugPrint('Playback: $e');
    }
  }

  void _jsInterrupt() {
    if (!kIsWeb) return;
    try { js.context['CuisineeAudio']?.callMethod('interrupt', []); } catch (_) {}
  }

  // ─── Cooking timer ─────────────────────────────────────────────────────────
  void _startCookingTimer(int minutes) {
    _cookingTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() { _timerSecondsLeft = minutes * 60; _timerRunning = true; });
    });
    _cookingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _timerSecondsLeft--;
          if (_timerSecondsLeft <= 0) {
            t.cancel();
            _timerRunning = false;
            _addMsg('⏰ Timer done! Time to check your food.', isAi: true);
          }
        });
      });
    });
  }

  // ─── Text input ─────────────────────────────────────────────────────────────
  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || !_isConnected) return;
    _send({'type': 'text', 'text': text});
    _addMsg(text, isUser: true);
    _textCtrl.clear();
  }

  // ─── Message helpers ────────────────────────────────────────────────────────
  void _addMsg(String text, {bool isAi = false, bool isUser = false, bool isError = false}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: text, isAi: isAi, isUser: isUser, isError: isError));
        if (_messages.length > 40) _messages.removeAt(0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _setupCamera(_selectedCameraIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameTimer?.cancel();
    _cookingTimer?.cancel();
    _wsSub?.cancel();
    _msgSub?.cancel();
    _channel?.sink.close();
    _cameraController?.dispose();
    _stopMic();
    _jsInterrupt();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // UI
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          // Top gradient vignette
          Positioned(
            top: 0, left: 0, right: 0, height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
            ),
          ),
          // Status badge
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _buildStatusBadge(),
          ),
          // Timer
          if (_timerRunning)
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: _buildTimerBadge(),
            ),
          // Recipe card
          if (_recipeCard != null)
            Positioned(
              left: 16, right: 16,
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 64,
              child: _RecipeCard(
                recipe: _recipeCard!,
                onDismiss: () => setState(() => _recipeCard = null),
              ),
            ),
          // Voice indicator
          if (_isAiSpeaking || _isUserSpeaking)
            Positioned(
              bottom: _showText ? 215 : 150,
              left: 0, right: 0,
              child: Center(child: _buildVoiceIndicator()),
            ),
          // Bottom panel
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: AppColors.warmGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          const Text('AI Sous Chef',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
        ],
      ),
      actions: [
        if (_cameras != null && _cameras!.length > 1)
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            onPressed: _switchCamera,
          ),
        IconButton(
          icon: Icon(
            _showText ? Icons.keyboard_hide_rounded : Icons.chat_bubble_outline_rounded,
            color: Colors.white70,
          ),
          onPressed: () => setState(() => _showText = !_showText),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraFailed || !_cameraReady || _cameraController == null) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0D1F1A), Color(0xFF0A1510)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (r) => AppColors.warmGradient.createShader(r),
                child: const Icon(Icons.soup_kitchen_rounded, size: 72, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                _cameraFailed ? 'Audio-only mode' : 'Initialising camera…',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width:  _cameraController!.value.previewSize?.height ?? 1,
          height: _cameraController!.value.previewSize?.width  ?? 1,
          child:  CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final Color    color;
    final String   label;
    final IconData icon;
    if (_isConnecting) {
      color = Colors.orange; label = 'Connecting…'; icon = Icons.hourglass_top_rounded;
    } else if (_isConnected) {
      color = const Color(0xFF4CAF50);
      label = _micActive ? 'Listening · Live' : 'Connected';
      icon  = _micActive ? Icons.mic_rounded : Icons.link_rounded;
    } else {
      color = AppColors.error; label = 'Disconnected'; icon = Icons.wifi_off_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTimerBadge() {
    final m = _timerSecondsLeft ~/ 60;
    final s = _timerSecondsLeft % 60;
    final isWarning = _timerSecondsLeft <= 30;
    final color = isWarning ? Colors.orange : const Color(0xFF4CAF50);
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) => Transform.scale(
        scale: isWarning ? _pulseScale.value : 1.0, child: child!,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Text('$m:${s.toString().padLeft(2, '0')}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceIndicator() {
    if (_isUserSpeaking) {
      return _GlowBadge(
        color: const Color(0xFF4CAF50),
        icon: Icons.mic_rounded,
        label: 'Listening…',
        pulseCtrl: _pulseCtrl,
        pulseScale: _pulseScale,
      );
    }
    return _GlowBadge(
      color: AppColors.primary,
      icon: Icons.volume_up_rounded,
      label: 'AI speaking…',
      pulseCtrl: _pulseCtrl,
      pulseScale: _pulseScale,
    );
  }

  Widget _buildBottomPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_messages.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
              ),
            ),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _BubbleWidget(msg: _messages[i]),
            ),
          ),
        Container(
          color: Colors.black.withOpacity(0.7),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showText)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Type a message…',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _sendText,
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(gradient: AppColors.warmGradient, shape: BoxShape.circle),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isConnected
                                ? (_micActive ? '🎤  Speak freely…' : '🔇  Mic off — tap to enable')
                                : 'Not connected',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          const Text('Ask about dishes, ingredients, timers…',
                              style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                      // Big mic button
                      GestureDetector(
                        onTap: _isConnected ? _toggleMic : null,
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, child) => Transform.scale(
                            scale: (_micActive && _isUserSpeaking) ? _pulseScale.value : 1.0,
                            child: child!,
                          ),
                          child: Container(
                            width: 62, height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _micActive ? AppColors.warmGradient : null,
                              color: _micActive ? null : Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: _micActive ? Colors.transparent : Colors.white24,
                                width: 1.5,
                              ),
                              boxShadow: _micActive
                                  ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)]
                                  : [],
                            ),
                            child: Icon(
                              _micActive ? Icons.mic_rounded : Icons.mic_off_rounded,
                              color: Colors.white, size: 26,
                            ),
                          ),
                        ),
                      ),
                      if (!_isConnected && !_isConnecting)
                        TextButton(
                          onPressed: _connect,
                          child: const Text('Reconnect', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        )
                      else
                        const SizedBox(width: 62),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting types & widgets
// ─────────────────────────────────────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isAi, isUser, isError;
  const _ChatMessage({required this.text, this.isAi = false, this.isUser = false, this.isError = false});
}

class _BubbleWidget extends StatelessWidget {
  const _BubbleWidget({required this.msg});
  final _ChatMessage msg;
  @override
  Widget build(BuildContext context) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.8),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14), topRight: Radius.circular(4),
              bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14),
            ),
          ),
          child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: msg.isError ? Colors.red.withOpacity(0.6) : Colors.white.withOpacity(0.11),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4), topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isAi) ...[
              Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 12),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(msg.text,
                  style: TextStyle(
                      color: msg.isError ? Colors.white : Colors.white.withOpacity(0.9),
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBadge extends StatelessWidget {
  const _GlowBadge({
    required this.color, required this.icon, required this.label,
    required this.pulseCtrl, required this.pulseScale,
  });
  final Color color; final IconData icon; final String label;
  final AnimationController pulseCtrl; final Animation<double> pulseScale;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, child) => Transform.scale(scale: pulseScale.value, child: child!),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.55), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 14)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onDismiss});
  final Map<String, dynamic> recipe;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) {
    final name = recipe['name']        as String? ?? 'Recipe';
    final desc = recipe['description'] as String? ?? '';
    final img  = recipe['image_url']   as String?;
    final time = ((recipe['prep_time'] as int? ?? 0) + (recipe['cook_time'] as int? ?? 0));
    final cals = recipe['calories']    as int?;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xE6111C18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.35)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (img != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Image.network(img, height: 120, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      GestureDetector(
                        onTap: onDismiss,
                        child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (time > 0) ...[
                        _Chip(icon: Icons.timer_outlined, label: '${time}min'),
                        const SizedBox(width: 8),
                      ],
                      if (cals != null) _Chip(icon: Icons.local_fire_department_outlined, label: '${cals}kcal'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 11),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

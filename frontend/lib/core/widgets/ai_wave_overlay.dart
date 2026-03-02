// ============================================================================
// AiWaveOverlay — iOS Siri-style full-screen envelope glow
//
// Place as Positioned.fill inside a Stack above your content:
//   Positioned.fill(child: AiWaveOverlay(
//     waveController: _waveController,
//     micAmplitude: _micAmplitude,
//     voiceState: _service.state,
//   ))
// ============================================================================

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../features/chat/services/gemini_live_service.dart' show LiveState;

/// Full-screen "Siri envelope" glow.
/// Four corner radial blobs (BlendMode.screen) + animated border ring.
/// Fully IgnorePointer — content underneath remains tappable.
class AiWaveOverlay extends StatelessWidget {
  final AnimationController waveController;
  final double micAmplitude; // 0.0–1.0 live from mic
  final LiveState voiceState;

  const AiWaveOverlay({
    super.key,
    required this.waveController,
    required this.micAmplitude,
    required this.voiceState,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = voiceState == LiveState.listening ||
        voiceState == LiveState.processing ||
        voiceState == LiveState.speaking;

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: isActive ? 1.0 : 0.0,
        child: AnimatedBuilder(
          animation: waveController,
          builder: (context, _) {
            final t = waveController.value;
            double intensity;
            List<Color> cols;

            switch (voiceState) {
              case LiveState.listening:
                // Mic-reactive orange — warm & energetic
                intensity = (0.25 + micAmplitude * 0.75).clamp(0.1, 1.0);
                cols = const [
                  Color(0xFFFF6B00), // deep orange      — top-left
                  Color(0xFFFF9F0A), // bright amber      — top-right
                  Color(0xFFFF3D00), // red-orange        — bottom-left
                  Color(0xFFFFCC00), // golden yellow     — bottom-right
                ];
                break;
              case LiveState.processing:
                // Thinking: orange fades into a warm purple
                intensity = 0.35 + 0.15 * math.sin(t * 2 * math.pi);
                cols = const [
                  Color(0xFFBF5AF2), // purple
                  Color(0xFFFF6B00), // orange
                  Color(0xFFFF2D55), // magenta-red
                  Color(0xFFFF9F0A), // amber
                ];
                break;
              case LiveState.speaking:
                // AI speaking: cooler orange-to-blue (Gemini palette)
                intensity = 0.45 + 0.15 * math.sin(t * 4 * math.pi);
                cols = const [
                  Color(0xFFFF6B00), // orange            — top-left
                  Color(0xFF32ADE6), // cyan              — top-right
                  Color(0xFFFF9F0A), // amber             — bottom-left
                  Color(0xFF007AFF), // blue              — bottom-right
                ];
                break;
              default:
                intensity = 0.0;
                cols = const [
                  Colors.transparent, Colors.transparent,
                  Colors.transparent, Colors.transparent,
                ];
            }

            return CustomPaint(
              size: Size.infinite,
              painter: _EnvelopePainter(
                phase: t,
                intensity: intensity,
                colors: cols,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  final double phase;
  final double intensity;
  final List<Color> colors; // [topLeft, topRight, bottomLeft, bottomRight]

  const _EnvelopePainter({
    required this.phase,
    required this.intensity,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.01) return;
    final w = size.width;
    final h = size.height;

    // Corner anchor points
    final corners = [
      Offset(0, 0),      // top-left
      Offset(w, 0),      // top-right
      Offset(0, h),      // bottom-left
      Offset(w, h),      // bottom-right
    ];

    // Blob radius: ~28% of diagonal — stays near corners, doesn't flood center
    final baseR = math.sqrt(w * w + h * h) * 0.28;

    // ── Corner blobs (additive BlendMode.screen) ──────────────────────────
    final layerRect = Rect.fromLTWH(0, 0, w, h);
    canvas.saveLayer(layerRect, Paint()..blendMode = BlendMode.screen);

    for (int i = 0; i < 4; i++) {
      // Stagger each corner by 0.25 of the animation cycle for rolling effect
      final stagger = i * 0.25;
      final pulse = 0.65 + 0.35 * math.sin((phase + stagger) * 2 * math.pi);
      final r = baseR * intensity * pulse;
      if (r <= 0) continue;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withOpacity(0.95 * intensity * pulse), // vivid at edge
            colors[i].withOpacity(0.45 * intensity * pulse), // still visible mid
            colors[i].withOpacity(0.0),                      // fades out
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: corners[i], radius: r));

      canvas.drawCircle(corners[i], r, paint);
    }

    canvas.restore();

    // ── Glowing border ring ───────────────────────────────────────────────
    final borderPulse = 0.55 + 0.45 * math.sin(phase * 2 * math.pi);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(0),
    );

    // 4 layers: tight bright core + wide soft halo
    const layerData = [
      // [strokeWidth, opacity, blurSigma]
      [2.0,  0.95, 0.0],   // sharp bright edge
      [5.0,  0.80, 3.0],   // inner glow
      [12.0, 0.55, 9.0],   // mid halo
      [22.0, 0.30, 18.0],  // outer soft bloom
    ];

    for (int li = 0; li < layerData.length; li++) {
      final sw    = layerData[li][0] * (0.5 + 0.5 * intensity * borderPulse);
      final op    = layerData[li][1] * intensity;
      final sigma = layerData[li][2];
      if (op <= 0.01) continue;

      final c = li.isEven ? colors[0] : colors[1];

      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..blendMode = BlendMode.screen
          ..color = c.withOpacity(op)
          ..maskFilter = sigma > 0 ? MaskFilter.blur(BlurStyle.normal, sigma) : null,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EnvelopePainter old) =>
      old.phase != phase ||
      old.intensity != intensity ||
      old.colors != colors;
}

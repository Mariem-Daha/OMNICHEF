import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/recipe_model.dart';
import '../../../core/utils/animations.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;

  const CookingModeScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isQuietMode = false;
  bool _isListening = false;
  bool _isTimerRunning = false;
  int _timerSeconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Keep screen on during cooking
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.recipe.steps.length - 1) {
      setState(() {
        _currentStep++;
        _stopTimer();
      });
      HapticFeedback.mediumImpact();
    } else {
      _showCompletionDialog();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _stopTimer();
      });
      HapticFeedback.lightImpact();
    }
  }

  void _repeatStep() {
    HapticFeedback.selectionClick();
    // TODO: Add text-to-speech here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🔊 Reading step aloud...'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _startTimer(int minutes) {
    setState(() {
      _timerSeconds = minutes * 60;
      _isTimerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _stopTimer();
        _showTimerAlert();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _timerSeconds = 0;
    });
  }

  void _showTimerAlert() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.timer_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Text('Timer Done!'),
          ],
        ),
        content: const Text('Your timer has finished. Ready for the next step?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _nextStep();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Next Step'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.warmGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '🎉 Congratulations!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve completed ${widget.recipe.name}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      // TODO: Navigate to rate/save screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Rate Recipe'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleVoiceMode() {
    setState(() => _isListening = !_isListening);
    HapticFeedback.mediumImpact();
    
    if (_isListening) {
      // Simulate voice recognition
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isListening) {
          setState(() => _isListening = false);
          // Simulated voice command
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🎤 Heard: "Next step"'),
              backgroundColor: AppColors.accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          _nextStep();
        }
      });
    }
  }

  void _askAI() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AIQuickHelpSheet(
        currentStep: widget.recipe.steps[_currentStep].instruction,
        onSuggestion: (text) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💡 $text'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStepData = widget.recipe.steps[_currentStep];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFDF6F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),
            
            // Progress indicator
            _buildProgressBar(),
            
            // Main step content
            Expanded(
              child: _buildStepContent(isDark, currentStepData),
            ),
            
            // Timer display (if running)
            if (_isTimerRunning) _buildTimerDisplay(isDark),
            
            // Control buttons
            _buildControlBar(isDark),
          ],
        ),
      ),
      
      // Floating mic button
      floatingActionButton: _buildMicButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          TapScale(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.close_rounded, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cooking Mode',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.recipe.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Quiet mode toggle
          TapScale(
            child: GestureDetector(
              onTap: () => setState(() => _isQuietMode = !_isQuietMode),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isQuietMode 
                      ? AppColors.primary.withOpacity(0.1) 
                      : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: _isQuietMode 
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isQuietMode ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 22,
                  color: _isQuietMode ? AppColors.primary : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of ${widget.recipe.steps.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              Text(
                '${((_currentStep + 1) / widget.recipe.steps.length * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / widget.recipe.steps.length,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isDark, RecipeStep stepData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Step number badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.warmGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${_currentStep + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          
          // Step text - large and readable
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              stepData.instruction,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                height: 1.6,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Quick timer buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildTimerChip('1 min', 1),
              _buildTimerChip('3 min', 3),
              _buildTimerChip('5 min', 5),
              _buildTimerChip('10 min', 10),
              _buildTimerChip('15 min', 15),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerChip(String label, int minutes) {
    return TapScale(
      child: GestureDetector(
        onTap: () => _startTimer(minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.warmGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            _formatTime(_timerSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _stopTimer,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          Expanded(
            child: TapScale(
              child: GestureDetector(
                onTap: _currentStep > 0 ? _previousStep : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _currentStep > 0
                        ? (isDark ? AppColors.cardDark : const Color(0xFFF5F5F5))
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: _currentStep > 0 
                            ? AppColors.textPrimaryLight 
                            : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _currentStep > 0 
                              ? AppColors.textPrimaryLight 
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Repeat button
          TapScale(
            child: GestureDetector(
              onTap: _repeatStep,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.replay_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Ask AI button
          TapScale(
            child: GestureDetector(
              onTap: _askAI,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Next button
          Expanded(
            child: TapScale(
              child: GestureDetector(
                onTap: _nextStep,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.warmGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentStep < widget.recipe.steps.length - 1 
                            ? 'Next' 
                            : 'Finish',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _currentStep < widget.recipe.steps.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isListening ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: _toggleVoiceMode,
            onLongPress: _toggleVoiceMode,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: _isListening 
                    ? const LinearGradient(
                        colors: [Color(0xFF81B29A), Color(0xFF3498DB)],
                      )
                    : AppColors.warmGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? AppColors.accent : AppColors.primary)
                        .withOpacity(0.4),
                    blurRadius: _isListening ? 24 : 16,
                    offset: const Offset(0, 6),
                    spreadRadius: _isListening ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }
}

// AI Quick Help Bottom Sheet
class _AIQuickHelpSheet extends StatelessWidget {
  final String currentStep;
  final Function(String) onSuggestion;

  const _AIQuickHelpSheet({
    required this.currentStep,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.warmGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Assistant',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'How can I help with this step?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          _buildSuggestionChip(
            context,
            '🔄 Show substitutions',
            'You can substitute with similar ingredients',
          ),
          _buildSuggestionChip(
            context,
            '💚 Healthier option?',
            'Try using less oil or a lighter alternative',
          ),
          _buildSuggestionChip(
            context,
            '⏱️ How long should this take?',
            'This step typically takes about 5-7 minutes',
          ),
          _buildSuggestionChip(
            context,
            '❓ Explain this technique',
            'This cooking technique helps seal in the flavors',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, String label, String response) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TapScale(
        child: GestureDetector(
          onTap: () => onSuggestion(response),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.15),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

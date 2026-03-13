import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../core/theme/app_colors.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/animations.dart';
import '../../../core/widgets/voice_language_selector.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_input_button.dart';
import '../widgets/cooking_step_card.dart';
import '../widgets/ai_reaction_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isListening = false;
  bool _isCookingMode = false;
  int _currentCookingStep = 0;
  String _voiceLanguage = 'en';
  
  // Active timers for quick timer widget
  final List<_ActiveTimer> _activeTimers = [];
  Timer? _timerUpdateTimer;
  
  // Context-aware suggestions based on conversation
  List<String> _contextSuggestions = [];
  String _lastContext = '';
  
  // Voice waveform animation
  late AnimationController _waveformController;
  late Animation<double> _waveformAnimation;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    
    // Initialize waveform animation
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _waveformAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveformController, curve: Curves.easeInOut),
    );
    
    // Timer update loop
    _timerUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeTimers.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((__) {
          if (!mounted) return;
          setState(() {
            _activeTimers.removeWhere((timer) {
              if (timer.remainingSeconds <= 0) {
                _showTimerCompleteNotification(timer.label);
                return true;
              }
              timer.remainingSeconds--;
              return false;
            });
          });
        });
      }
    });
  }
  
  @override
  void dispose() {
    _timerUpdateTimer?.cancel();
    _waveformController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      id: '1',
      content:
          "Assalamu alaikum!  I'm your OMNICHEF cooking assistant. How can I help you today?\n\n Ask me for recipe suggestions\n Tell me what ingredients you have\n Get cooking tips and substitutions\n Start a step-by-step cooking session",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _handleSuggestionTap(String suggestion) {
    switch (suggestion) {
      case 'Set a timer':
        _sendMessage("Set a timer for 10 minutes");
        break;
      case 'Healthier option?':
        _sendMessage("Can you suggest a healthier version?");
        break;
      case 'Show substitutes':
        _sendMessage("What substitutes can I use?");
        break;
      case 'Reduce salt':
        _sendMessage("How can I reduce salt in this recipe?");
        break;
      case 'Adjust servings':
        _sendMessage("Can you adjust servings for 6 people?");
        break;
      case 'Nutrition info':
        _sendMessage("What's the nutrition information?");
        break;
      case 'Voice guide':
        _sendMessage("Start voice guided cooking");
        break;
      case 'Save recipe':
        _sendMessage("Save this recipe to my collection");
        break;
      case 'Print recipe':
        _sendMessage("Generate a printable version");
        break;
      default:
        _sendMessage(suggestion);
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Check for timer commands
    final timerMatch = RegExp(r'timer.*?(\d+)\s*min').firstMatch(text.toLowerCase());
    if (timerMatch != null) {
      final minutes = int.tryParse(timerMatch.group(1) ?? '10') ?? 10;
      _addTimer(minutes, 'Cooking Timer');
    }

    // Update context suggestions based on message
    _updateContextSuggestions(text);

    // BUG FIX: Build conversation history BEFORE adding the current user
    // message to _messages, and skip the initial AI welcome message (id='1')
    // so the history sent to Gemini is valid (starts with user, no duplicates).
    final conversationHistory = _messages
        .where((m) => m.id != '1') // exclude hardcoded welcome message
        .map((m) => <String, dynamic>{
          'content': m.content,
          'is_user': m.isUser,
        })
        .toList();

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // Call AI API
    try {
      final response = await _apiService.chat(text, conversationHistory: conversationHistory);
      
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: response,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Fallback to local response on error
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_generateResponse(text));
        });
        _scrollToBottom();
      }
    }
  }

  ChatMessage _generateResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('thieb') || lowerMessage.contains('fish')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            "Great choice! Thieboudienne is our national dish! \n\nWould you like me to:\n\n1. Show you the full recipe\n2. Start a step-by-step cooking session\n3. Suggest a diabetes-friendly version\n\nJust let me know!",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    if (lowerMessage.contains('step') ||
        lowerMessage.contains('cook') ||
        lowerMessage.contains('start')) {
      _isCookingMode = true;
      _currentCookingStep = 0;
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            "Perfect! Let's start cooking! \n\nI'll guide you through each step. Say 'next' when you're ready for the next step, or ask me any questions along the way.",
        isUser: false,
        timestamp: DateTime.now(),
        type: MessageType.cookingStep,
      );
    }

    if (lowerMessage.contains('next') && _isCookingMode) {
      _currentCookingStep++;
      if (_currentCookingStep >= 5) {
        _isCookingMode = false;
        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content:
              " Congratulations! You've completed the recipe!\n\nYour dish is ready to serve. Enjoy your meal!\n\nWould you like to:\n Save this recipe\n Rate your cooking experience\n Try another recipe",
          isUser: false,
          timestamp: DateTime.now(),
        );
      }
    }

    if (lowerMessage.contains('timer')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            " Timer set for 10 minutes!\n\nI'll notify you when it's done. In the meantime, you can continue with the next step or ask me anything.",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    if (lowerMessage.contains('healthier') ||
        lowerMessage.contains('healthy')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            " Great choice! Here are some healthier options:\n\n Use olive oil instead of vegetable oil\n Add more vegetables\n Reduce salt by 50%\n Use brown rice instead of white\n\nWould you like me to modify the recipe with these changes?",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    if (lowerMessage.contains('substitute')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            " Here are some substitution ideas:\n\n **No fish?** Try chicken or tofu\n **No tomato paste?** Use fresh tomatoes\n **Low sodium?** Use herbs for flavor\n **Allergies?** Let me know!\n\nWhich ingredient do you need to substitute?",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    if (lowerMessage.contains('leftover') ||
        lowerMessage.contains('fridge')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            "I'd love to help you use those leftovers! \n\nTell me what ingredients you have, and I'll suggest some delicious recipes. For example:\n\n\"I have chicken, rice, and some vegetables\"",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    if (lowerMessage.contains('diabetes')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            "I understand! Here are some diabetes-friendly options:\n\n **Lebanese Fattoush** - Low glycemic, lots of fiber\n **Grilled Fish with Chermoula** - High protein, low carb\n **Shakshuka** - Protein-rich, minimal carbs\n\nWould you like the full recipe for any of these?",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    // Default response
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content:
          "I can help you with that! Here are some ideas:\n\n **Today's Suggestions:**\n Thieboudienne (Classic fish & rice)\n Chicken Yassa (Lemon-onion chicken)\n Shakshuka (Quick & healthy)\n\nWhat sounds good to you?",
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startVoiceInput() {
    setState(() {
      _isListening = true;
      _waveformController.repeat(reverse: true);
    });

    // Simulate voice recognition
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _waveformController.stop();
          });
          _sendMessage("What can I cook with chicken and rice?");
        });
      }
    });
  }
  
  void _showTimerCompleteNotification(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.timer_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text('Timer "$label" is done!'),
          ],
        ),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }
  
  void _addTimer(int minutes, String label) {
    setState(() {
      _activeTimers.add(_ActiveTimer(
        label: label,
        totalSeconds: minutes * 60,
        remainingSeconds: minutes * 60,
      ));
    });
  }
  
  void _updateContextSuggestions(String message) {
    final lower = message.toLowerCase();
    
    setState(() {
      if (lower.contains('chicken')) {
        _lastContext = 'chicken';
        _contextSuggestions = [
          'Start recipe with chicken?',
          'Healthy chicken options',
          'Chicken prep tips',
        ];
      } else if (lower.contains('fish') || lower.contains('thieb')) {
        _lastContext = 'fish';
        _contextSuggestions = [
          'How to clean fish?',
          'Best fish for grilling',
          'Fish cooking times',
        ];
      } else if (lower.contains('rice')) {
        _lastContext = 'rice';
        _contextSuggestions = [
          'Perfect rice tips',
          'Brown rice alternative',
          'Rice to water ratio',
        ];
      } else if (lower.contains('vegetable') || lower.contains('veggie')) {
        _lastContext = 'vegetables';
        _contextSuggestions = [
          'Vegetarian recipes',
          'Roasted veggie ideas',
          'Seasonal vegetables',
        ];
      } else if (lower.contains('diabetes') || lower.contains('sugar')) {
        _lastContext = 'diabetes';
        _contextSuggestions = [
          'Low-carb alternatives',
          'Sugar-free desserts',
          'Diabetic meal plan',
        ];
      } else {
        _contextSuggestions = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.warmGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OMNICHEF Assistant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _isTyping ? 'typing...' : 'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isTyping ? AppColors.primary : AppColors.success,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Voice Language Toggle
          VoiceLanguageToggle(
            currentLanguage: _voiceLanguage,
            onLanguageChanged: (lang) {
              setState(() => _voiceLanguage = lang);
              final langName = lang == 'en' ? 'English' : (lang == 'ar' ? 'Arabic' : 'French');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Voice language set to $langName'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Subtle background pattern
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
              ),
              child: CustomPaint(
                painter: _ChatBackgroundPainter(
                  color: AppColors.primary.withOpacity(isDark ? 0.03 : 0.02),
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Chat messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: _messages.length +
                      (_isTyping ? 1 : 0) +
                      (_isCookingMode ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isCookingMode && index == _messages.length) {
                      return CookingStepCard(
                        stepNumber: _currentCookingStep + 1,
                        totalSteps: 5,
                        instruction:
                            _getCookingStepInstruction(_currentCookingStep),
                        tip: _currentCookingStep == 2
                            ? "Don't rush the onions - they're the star of the dish."
                            : null,
                        onNext: () => _sendMessage('next'),
                        onPrevious: _currentCookingStep > 0
                            ? () => setState(() => _currentCookingStep--)
                            : null,
                      );
                    }

                    if (_isTyping &&
                        index == _messages.length + (_isCookingMode ? 1 : 0)) {
                      return const TypingIndicator();
                    }

                    return ChatBubble(message: _messages[index]);
                  },
                ),
              ),

              // Quick suggestions
              if (_messages.length == 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Text(
                          'Quick suggestions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildQuickSuggestion(' Recipe ideas'),
                          _buildQuickSuggestion(' Healthy options'),
                          _buildQuickSuggestion(' Quick meals'),
                          _buildQuickSuggestion(' Use leftovers'),
                        ],
                      ),
                    ],
                  ),
                ),

              // AI Reaction Bar - Show after conversation starts
              if (_messages.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AIReactionBar(
                    onSuggestionTap: _handleSuggestionTap,
                  ),
                ),
              
              // Context-aware suggestions
              if (_contextSuggestions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggestions for $_lastContext',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _contextSuggestions.map((suggestion) {
                          return GestureDetector(
                            onTap: () => _sendMessage(suggestion),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.secondary.withOpacity(0.15),
                                    AppColors.primary.withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                suggestion,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              
              // Active timers widget
              if (_activeTimers.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.1),
                        AppColors.secondary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timer_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _activeTimers.map((timer) {
                            final minutes = timer.remainingSeconds ~/ 60;
                            final seconds = timer.remainingSeconds % 60;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Text(
                                    timer.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: timer.remainingSeconds < 60 
                                          ? Colors.red 
                                          : AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[600]),
                        onPressed: () => setState(() => _activeTimers.clear()),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),

              // Voice listening indicator with waveform
              if (_isListening)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.secondary.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Waveform visualization
                      AnimatedBuilder(
                        animation: _waveformAnimation,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(12, (index) {
                              final delay = (index * 0.1) % 1.0;
                              final phase = (_waveformAnimation.value + delay) % 1.0;
                              final height = 8 + (24 * _sineWave(phase));
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: 4,
                                height: height,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primary, AppColors.secondary],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final langName = _voiceLanguage == 'en' ? 'English' : (_voiceLanguage == 'ar' ? 'Arabic' : 'French');
                          return Text(
                            'Listening in $langName...',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Input area
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), // Extra bottom padding for nav bar
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
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
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Ask me anything about cooking...',
                                  hintStyle: TextStyle(
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withOpacity(0.4),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  prefixIcon: Padding(
                                    padding:
                                        const EdgeInsets.only(left: 12, right: 4),
                                    child: Icon(
                                      Icons.restaurant_menu_rounded,
                                      color: AppColors.primary.withOpacity(0.5),
                                      size: 20,
                                    ),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                                onSubmitted: _sendMessage,
                              ),
                            ),
                            TapScale(
                              child: GestureDetector(
                                onTap: () =>
                                    _sendMessage(_messageController.text),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.warmGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    VoiceInputButton(
                      isListening: _isListening,
                      onPressed: _startVoiceInput,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestion(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TapScale(
      child: GestureDetector(
        onTap: () => _sendMessage(text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(isDark ? 0.12 : 0.08),
                AppColors.secondary.withOpacity(isDark ? 0.08 : 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primary.withOpacity(isDark ? 0.3 : 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _getCookingStepInstruction(int step) {
    final steps = [
      'Marinate chicken in lemon juice, mustard, and garlic for 2 hours. This is essential for the authentic Yassa flavor.',
      'Grill or pan-sear chicken until golden and cooked through. Set aside and keep warm.',
      'Caramelize onions in olive oil over medium-low heat for about 25 minutes. They should be soft and golden.',
      'Add remaining marinade to onions and simmer for 10 minutes until the flavors meld together.',
      'Add chicken to the sauce and simmer together for 10 more minutes. Serve hot with rice!',
    ];
    return steps[step.clamp(0, steps.length - 1)];
  }
  
  double _sineWave(double phase) {
    return (1 + math.sin(2 * math.pi * phase)) / 2;
  }
}

// Timer model for active cooking timers
class _ActiveTimer {
  final String label;
  final int totalSeconds;
  int remainingSeconds;
  
  _ActiveTimer({
    required this.label,
    required this.totalSeconds,
    required this.remainingSeconds,
  });
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.cardDark
              : AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final delay = index * 0.2;
                final value = ((_controller.value + delay) % 1.0);
                final opacity = (value < 0.5 ? value * 2 : 2 - value * 2);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.3 + opacity * 0.7),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

/// Background painter for subtle pattern
class _ChatBackgroundPainter extends CustomPainter {
  final Color color;

  _ChatBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 30.0;

    // Draw subtle dots pattern
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

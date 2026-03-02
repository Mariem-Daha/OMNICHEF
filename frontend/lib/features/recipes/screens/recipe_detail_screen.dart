import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ai_wave_overlay.dart';
import '../../chat/services/gemini_live_service.dart' show GeminiLiveService, LiveState;
import '../../../core/models/recipe_model.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/utils/animations.dart';
import '../../cooking/screens/cooking_mode_screen.dart';
import '../widgets/ingredient_list.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/step_list.dart';
import '../../chat/screens/voice_assistant_mode.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final bool fromAI;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.fromAI = false,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaved = false;
  int _servings = 4;
  double _scrollOffset = 0.0;

  // AI wave overlay fields
  AnimationController? _waveController;
  double _micAmplitude = 0.0;
  LiveState _voiceState = LiveState.disconnected;
  Function(double)? _savedAmplitudeCallback;
  Function(LiveState)? _savedStateCallback;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isSaved = widget.recipe.isSaved;
    _servings = widget.recipe.servings;
    if (widget.fromAI) {
      _waveController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
      final svc = GeminiLiveService();
      _savedAmplitudeCallback = svc.onAmplitudeChanged;
      _savedStateCallback    = svc.onStateChanged;
      svc.onAmplitudeChanged = (rms) {
        if (mounted) setState(() { _micAmplitude = rms; _voiceState = svc.state; });
      };
      // Catches disconnect/connect even when mic is silent
      svc.onStateChanged = (state) {
        if (mounted) setState(() => _voiceState = state);
      };
    }
  }

  @override
  void dispose() {
    if (widget.fromAI) {
      final svc = GeminiLiveService();
      svc.onAmplitudeChanged = _savedAmplitudeCallback;
      svc.onStateChanged    = _savedStateCallback;
      _waveController?.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final scaffold = Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            setState(() {
              _scrollOffset = notification.metrics.pixels;
            });
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            // Hero Image with enhanced styling
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
              elevation: _scrollOffset > 200 ? 4 : 0,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TapScale(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
              actions: [
                TapScale(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _isSaved = !_isSaved);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isSaved ? AppColors.primary : Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Icon(
                        _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                TapScale(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondaryLight,
                            AppColors.primary.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Image.network(
                        widget.recipe.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            size: 80,
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                      ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.25, 0.6, 1.0],
                        colors: [
                          Colors.black.withOpacity(0.45),
                          Colors.black.withOpacity(0.1),
                          Colors.transparent,
                          Colors.black.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.warmGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.recipe.cuisine,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.recipe.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.recipe.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildInfoPill(Icons.schedule_rounded, '${widget.recipe.totalTime} min'),
                            const SizedBox(width: 12),
                            _buildInfoPill(Icons.local_fire_department_rounded, '${widget.recipe.calories} cal'),
                            const SizedBox(width: 12),
                            _buildInfoPill(Icons.people_rounded, '${widget.recipe.servings} servings'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Health Tags with Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Health Labels',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _showHealthLabelInfo(context, isDark),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.recipe.tags.map((tag) {
                            return _buildHealthTagWithTooltip(tag, isDark);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Step Preview
                  _buildStepPreview(context, isDark),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      widget.recipe.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                          ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Chef info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.warmGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.recipe.chefName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              'Recipe Creator',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const Spacer(),
                        _buildDifficultyBadge(widget.recipe.difficulty),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                            (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.2, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // Sticky Glass Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                unselectedLabelColor: isDark 
                    ? AppColors.textSecondaryDark 
                    : AppColors.textSecondaryLight,
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                indicator: BoxDecoration(
                  gradient: AppColors.warmGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(12),
                tabs: const [
                  Tab(text: 'Ingredients'),
                  Tab(text: 'Steps'),
                  Tab(text: 'Nutrition'),
                ],
              ),
              isDark,
            ),
          ),
          
          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Ingredients Tab
                IngredientList(
                  ingredients: widget.recipe.ingredients,
                  servings: _servings,
                  originalServings: widget.recipe.servings,
                  substitutions: widget.recipe.substitutions,
                  onServingsChanged: (value) {
                    setState(() => _servings = value);
                  },
                ),
                
                // Steps Tab
                StepList(steps: widget.recipe.steps),
                
                // Nutrition Tab
                NutritionCard(nutrition: widget.recipe.nutrition),
              ],
            ),
          ),
        ],
      ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90), // Above the bottom bar
        child: FloatingActionButton(
          onPressed: () {
             Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => 
                    VoiceAssistantMode(onClose: () => Navigator.pop(context)),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  fullscreenDialog: true,
                  opaque: false, // Allow transparency
                ),
              );
          },
          backgroundColor: AppColors.primary,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TapScale(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to cooking mode
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CookingModeScreen(recipe: widget.recipe),
                        ),
                      );
                    },
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE07A5F), Color(0xFFF4A582)], // Warm cooking colors
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE07A5F).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Start Cooking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!widget.fromAI || _waveController == null) return scaffold;
    return Stack(
      children: [
        scaffold,
        Positioned.fill(
          child: AiWaveOverlay(
            waveController: _waveController!,
            micAmplitude: _micAmplitude,
            voiceState: _voiceState,
          ),
        ),
        // Floating "stop AI" pill — only visible when session is active
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _waveController!,
              builder: (context, _) {
                final isActive = _voiceState == LiveState.listening ||
                    _voiceState == LiveState.processing ||
                    _voiceState == LiveState.speaking;
                final glowColor = _voiceState == LiveState.speaking
                    ? const Color(0xFF32ADE6)   // cyan when AI speaks
                    : _voiceState == LiveState.processing
                        ? const Color(0xFFBF5AF2) // purple when thinking
                        : const Color(0xFFFF6B00); // orange when listening
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: isActive ? 1.0 : 0.0,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 16),
                      child: IgnorePointer(
                        ignoring: !isActive,
                        child: GestureDetector(
                          onTap: () async {
                            await GeminiLiveService().disconnect();
                            if (mounted) setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: glowColor.withOpacity(0.85),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor.withOpacity(0.50),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stop_circle_outlined,
                                    size: 15, color: glowColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Stop AI',
                                  style: TextStyle(
                                    color: glowColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'beginner':
        badgeColor = const Color(0xFF4CAF50); // Green
        badgeIcon = Icons.sentiment_satisfied_rounded;
        badgeLabel = 'Beginner';
        break;
      case 'medium':
      case 'intermediate':
        badgeColor = const Color(0xFFFFA726); // Orange
        badgeIcon = Icons.trending_up_rounded;
        badgeLabel = 'Intermediate';
        break;
      case 'hard':
      case 'advanced':
        badgeColor = const Color(0xFFE53935); // Red
        badgeIcon = Icons.whatshot_rounded;
        badgeLabel = 'Advanced';
        break;
      default:
        badgeColor = AppColors.accent;
        badgeIcon = Icons.restaurant_rounded;
        badgeLabel = difficulty;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [badgeColor, badgeColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            badgeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTagWithTooltip(String tag, bool isDark) {
    final explanation = _getHealthLabelExplanation(tag);
    
    return GestureDetector(
      onLongPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(explanation),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: HealthTag(label: tag),
    );
  }

  String _getHealthLabelExplanation(String label) {
    switch (label.toLowerCase()) {
      case 'diabetes-friendly':
        return 'Low glycemic index, under 45g carbs per serving';
      case 'low salt':
      case 'low-salt':
        return 'Contains less than 400mg sodium per serving';
      case 'heart healthy':
        return 'Low in saturated fat, high in fiber and omega-3';
      case 'weight loss':
        return 'Under 350 calories with high protein/fiber ratio';
      case 'allergy-free':
      case 'allergen-free':
        return 'Free from top 8 common allergens';
      case 'quick meal':
        return 'Ready in 30 minutes or less';
      case 'vegetarian':
        return 'Contains no meat or fish products';
      case 'vegan':
        return 'Contains no animal products or by-products';
      case 'iron-rich':
        return 'Contains at least 3.5mg of iron per serving';
      case 'protein-rich':
        return 'Contains at least 20g of protein per serving';
      default:
        return 'Tap for more info about this label';
    }
  }

  void _showHealthLabelInfo(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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
            Text(
              'Health Label Guide',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildLabelInfoRow(Icons.bloodtype_rounded, 'Diabetes-Friendly', 
                'Under 45g carbs, low glycemic index', AppColors.diabetesFriendly),
            _buildLabelInfoRow(Icons.water_drop_rounded, 'Low Salt', 
                '≤400mg sodium per serving', AppColors.lowSalt),
            _buildLabelInfoRow(Icons.favorite_rounded, 'Heart Healthy', 
                'Low saturated fat, high fiber', AppColors.heartHealthy),
            _buildLabelInfoRow(Icons.fitness_center_rounded, 'Weight Loss', 
                '<350 cal, high protein', AppColors.weightLoss),
            _buildLabelInfoRow(Icons.shield_rounded, 'Allergen-Free', 
                'No top 8 allergens', AppColors.allergyFree),
            const SizedBox(height: 8),
            Text(
              'Long-press any label for more details',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelInfoRow(IconData icon, String label, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPreview(BuildContext context, bool isDark) {
    final steps = widget.recipe.steps;
    final previewSteps = steps.take(3).toList();
    
    if (previewSteps.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.surfaceDark.withOpacity(0.6)
            : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.warmGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.preview_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Quick Preview',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${steps.length} steps total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...previewSteps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == previewSteps.length - 1;
            
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${step.stepNumber}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (step.durationMinutes != null && step.durationMinutes! > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${step.durationMinutes}m',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          if (steps.length > 3) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '+ ${steps.length - 3} more steps...',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar child;
  final bool isDark;

  _StickyTabBarDelegate(this.child, this.isDark);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight).withOpacity(0.85),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          alignment: Alignment.center,
          child: Container(
             padding: const EdgeInsets.all(4),
             decoration: BoxDecoration(
               color: isDark ? AppColors.surfaceDark.withOpacity(0.5) : Colors.grey.withOpacity(0.1),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(
                 color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
               ),
             ),
             child: child,
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 70; // Height of container (4+4 padding + ~46 tabbar + 8+8 vertical padding) - rough estimate

  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return child != oldDelegate.child || isDark != oldDelegate.isDark;
  }
}

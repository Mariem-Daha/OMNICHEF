import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/recipe_model.dart';
import '../../../core/widgets/recipe_cards.dart';
import '../../recipes/screens/recipe_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class DishIdentifierScreen extends StatefulWidget {
  const DishIdentifierScreen({super.key});

  @override
  State<DishIdentifierScreen> createState() => _DishIdentifierScreenState();
}

class _DishIdentifierScreenState extends State<DishIdentifierScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;
  DishIdentifyResult? _result;

  Future<void> _pickImage(ImageSource source) async {
    // ── Request permission on iOS/Android before accessing camera/photos ───
    if (!kIsWeb) {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.status;
        if (status.isPermanentlyDenied) {
          if (mounted) _showPermissionDenied('Camera');
          return;
        }
        if (status.isDenied) {
          final result = await Permission.camera.request();
          if (!result.isGranted) {
            if (mounted) _showPermissionDenied('Camera');
            return;
          }
        }
      } else {
        // Gallery — needs photo library permission
        final status = await Permission.photos.status;
        if (status.isPermanentlyDenied) {
          if (mounted) _showPermissionDenied('Photo Library');
          return;
        }
        if (status.isDenied) {
          await Permission.photos.request();
          // image_picker shows its own UI; we let it proceed even if isDenied
          // (Android doesn't need this at all; iOS grants partial access)
        }
      }
    }

    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _result = null;
        _error = null;
      });

      await _analyze(bytes);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open camera/gallery. Please try again.');
    }
  }

  void _showPermissionDenied(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name Access Required'),
        content: Text(
          'Cuisinée needs $name access. '
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

  Future<void> _analyze(Uint8List bytes) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _api.identifyDish(bytes);
      setState(() => _result = result);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Analysis failed. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Dish Identifier'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Instruction banner ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Photograph any dish — even MENA / Mauritanian dishes — and Cuisinee will identify it and find the recipe.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Image preview ─────────────────────────────────────────────
            GestureDetector(
              onTap: () => _showSourcePicker(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 260,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _imageBytes != null
                        ? AppColors.primary.withOpacity(0.5)
                        : AppColors.dividerLight,
                    width: 2,
                  ),
                  boxShadow: AppColors.softShadow,
                ),
                clipBehavior: Clip.hardEdge,
                child: _imageBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_imageBytes!, fit: BoxFit.cover),
                          if (_isLoading)
                            Container(
                              color: Colors.black.withOpacity(0.45),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                      color: Colors.white),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Identifying dish...',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Retake button
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _showSourcePicker(context),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.restaurant_rounded,
                                size: 40, color: AppColors.primary),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Photograph a dish',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'AI will identify it and find the recipe for you',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textTertiaryLight),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Action buttons ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.photo_camera_rounded,
                    label: 'Take Photo',
                    onTap: () => _pickImage(ImageSource.camera),
                    primary: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                    primary: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),

            // ── Results ───────────────────────────────────────────────────
            if (_result != null) ...[
              // Dish identity card
              _DishResultCard(result: _result!),

              const SizedBox(height: 24),

              // Matching recipes
              if (_result!.recipes.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Matching Recipes',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _result!.recipes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final recipe = _result!.recipes[i];
                      return SizedBox(
                        width: 200,
                        child: RecipeCard(
                          recipe: recipe,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RecipeDetailScreen(recipe: recipe),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                        'No matching recipes found in our library for this dish.',
                        textAlign: TextAlign.center),
                  ),
                ),
              ],

              const SizedBox(height: 80),
            ],
          ],
        ),
      ),
    );
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? AppColors.primary : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _DishResultCard extends StatelessWidget {
  const _DishResultCard({required this.result});
  final DishIdentifyResult result;

  @override
  Widget build(BuildContext context) {
    final confidence = (result.confidence * 100).round();
    Color confColor;
    if (confidence >= 80) {
      confColor = AppColors.success;
    } else if (confidence >= 50) {
      confColor = AppColors.warning;
    } else {
      confColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.12), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.dishName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (result.cuisine.isNotEmpty)
                      Text(
                        result.cuisine,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.primary),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: confColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: confColor.withOpacity(0.3)),
                ),
                child: Text(
                  '$confidence% match',
                  style: TextStyle(
                    color: confColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (result.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              result.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (result.healthTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: result.healthTags
                  .map(
                    (tag) => Chip(
                      label: Text(tag,
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor:
                          AppColors.diabetesFriendly.withOpacity(0.12),
                      side: BorderSide(
                          color:
                              AppColors.diabetesFriendly.withOpacity(0.3)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

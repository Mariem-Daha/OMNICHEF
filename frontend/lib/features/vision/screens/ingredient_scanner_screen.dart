import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/recipe_model.dart';
import '../../../core/widgets/recipe_cards.dart';
import '../../recipes/screens/recipe_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class IngredientScannerScreen extends StatefulWidget {
  const IngredientScannerScreen({super.key});

  @override
  State<IngredientScannerScreen> createState() =>
      _IngredientScannerScreenState();
}

class _IngredientScannerScreenState extends State<IngredientScannerScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;
  IngredientScanResult? _result;

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
      final result = await _api.scanIngredients(bytes);
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
        title: const Text('Ingredient Scanner'),
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
            // ── Image preview / placeholder ───────────────────────────────
            GestureDetector(
              onTap: () => _showSourcePicker(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 240,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _imageBytes != null
                        ? AppColors.primary.withOpacity(0.4)
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
                              color: Colors.black.withOpacity(0.4),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 36,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tap to scan your ingredients',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Point camera at your fridge, pantry, or table',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.textTertiaryLight,
                                ),
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
                  child: _ActionButton(
                    icon: Icons.photo_camera_rounded,
                    label: 'Take Photo',
                    onTap: () => _pickImage(ImageSource.camera),
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Results ───────────────────────────────────────────────────
            if (_result != null) ...[
              // Identified ingredients
              _SectionHeader(
                icon: Icons.eco_rounded,
                title: 'Detected Ingredients',
                count: _result!.ingredients.length,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _result!.ingredients
                    .asMap()
                    .entries
                    .map((entry) {
                      final qty = entry.key < _result!.quantities.length
                          ? _result!.quantities[entry.key]
                          : null;
                      return _IngredientChip(
                        label: entry.value,
                        quantity: qty,
                      );
                    })
                    .toList(),
              ),

              // Health notes
              if (_result!.healthNotes.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionHeader(
                  icon: Icons.health_and_safety_rounded,
                  title: 'Health Notes',
                  color: AppColors.success,
                ),
                const SizedBox(height: 10),
                ..._result!.healthNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(note,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Matching recipes
              if (_result!.recipes.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.menu_book_rounded,
                  title: 'You Can Make',
                  count: _result!.recipes.length,
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
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 36, color: AppColors.textTertiaryLight),
                      const SizedBox(height: 8),
                      Text(
                        'No matching recipes found for these ingredients',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
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
                title: const Text('Take a Photo'),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.count,
    this.color,
  });

  final IconData icon;
  final String title;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.accent;
    return Row(
      children: [
        Icon(icon, color: effectiveColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label, this.quantity});

  final String label;
  final String? quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          if (quantity != null && quantity!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              '($quantity)',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.accent.withOpacity(0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

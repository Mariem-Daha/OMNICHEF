import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/animations.dart';

class VoiceLanguageSelector extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;

  const VoiceLanguageSelector({
    super.key,
    this.currentLanguage = 'en',
    this.onLanguageChanged,
  });

  @override
  State<VoiceLanguageSelector> createState() => _VoiceLanguageSelectorState();
}

class _VoiceLanguageSelectorState extends State<VoiceLanguageSelector> {
  late String _selectedLanguage;

  final List<Map<String, dynamic>> _languages = [
    {
      'code': 'en',
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇺🇸',
    },
    {
      'code': 'ar',
      'name': 'Arabic',
      'nativeName': 'العربية',
      'flag': '🇸🇦',
    },
    {
      'code': 'fr',
      'name': 'French',
      'nativeName': 'Français',
      'flag': '🇫🇷',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.record_voice_over_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voice Language',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Choose assistant voice language',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._languages.map((lang) => _buildLanguageOption(lang, isDark)),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(Map<String, dynamic> lang, bool isDark) {
    final isSelected = _selectedLanguage == lang['code'];

    return TapScale(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedLanguage = lang['code']);
          widget.onLanguageChanged?.call(lang['code']);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : (isDark ? AppColors.surfaceDark : const Color(0xFFF8F4F0)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                lang['flag'],
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    Text(
                      lang['nativeName'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.7)
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textTertiaryLight,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Compact inline version for use in headers
class VoiceLanguageToggle extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;

  const VoiceLanguageToggle({
    super.key,
    this.currentLanguage = 'en',
    this.onLanguageChanged,
  });

  @override
  State<VoiceLanguageToggle> createState() => _VoiceLanguageToggleState();
}

class _VoiceLanguageToggleState extends State<VoiceLanguageToggle> {
  late String _selectedLanguage;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'flag': '🇺🇸'},
    {'code': 'ar', 'flag': '🇸🇦'},
    {'code': 'fr', 'flag': '🇫🇷'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
  }

  void _cycleLanguage() {
    final currentIndex =
        _languages.indexWhere((l) => l['code'] == _selectedLanguage);
    final nextIndex = (currentIndex + 1) % _languages.length;
    setState(() => _selectedLanguage = _languages[nextIndex]['code']!);
    widget.onLanguageChanged?.call(_selectedLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang =
        _languages.firstWhere((l) => l['code'] == _selectedLanguage);

    return TapScale(
      child: GestureDetector(
        onTap: _cycleLanguage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentLang['flag']!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.mic_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

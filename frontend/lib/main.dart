import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/recipe_provider.dart';
import 'core/services/api_service.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/onboarding/screens/preference_quiz_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture full stack for _debugDuringDeviceUpdate assertion
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.toString().contains('_debugDuringDeviceUpdate')) {
      debugPrint('=== _debugDuringDeviceUpdate STACK ===');
      debugPrint(details.stack.toString());
      debugPrint('======================================');
    }
    originalOnError?.call(details);
  };

  // Initialize API service
  await ApiService().init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const OmniChefApp());
}

class OmniChefApp extends StatelessWidget {
  const OmniChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()..init()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'OMNICHEF',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const OnboardingScreen(),
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/login': (context) => const LoginScreen(),
              '/preferences': (context) => const PreferenceQuizScreen(),
              '/home': (context) => const MainNavigation(),
            },
          );
        },
      ),
    );
  }
}

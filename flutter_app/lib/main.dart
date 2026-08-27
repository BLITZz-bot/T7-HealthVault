import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/language_setup_screen.dart';
import 'services/language_service.dart';
import 'services/on_device_llm_service.dart';
// Conditional import: stub (no-op) for Android/iOS, FFI init for Windows/Linux/macOS
import 'db_init_stub.dart'
    if (dart.library.ffi) 'db_init_desktop.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabase(); // no-op on mobile, FFI init on desktop
  await LanguageService.init();
  await OnDeviceLLMService.initialize();
  final isFirstRun = await LanguageService.isFirstRun();
  runApp(HealthVaultApp(showFirstRunLanguageSetup: isFirstRun));
}

class HealthVaultApp extends StatefulWidget {
  final bool showFirstRunLanguageSetup;

  const HealthVaultApp({
    super.key,
    required this.showFirstRunLanguageSetup,
  });

  @override
  State<HealthVaultApp> createState() => _HealthVaultAppState();
}

class _HealthVaultAppState extends State<HealthVaultApp> {
  late bool _showLanguageSetup;

  @override
  void initState() {
    super.initState();
    _showLanguageSetup = widget.showFirstRunLanguageSetup;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        return MaterialApp(
          key: ValueKey('app_lang_$currentLang'),
          title: LanguageService.tr('app_title'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00796B),
              primary: const Color(0xFF00796B),
              secondary: const Color(0xFF004D40),
              tertiary: const Color(0xFF00E5FF),
              surface: Colors.white,
              surfaceContainerLowest: const Color(0xFFF4F7F9),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F8FA),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.teal.shade50.withAlpha(200), width: 1.2),
              ),
              color: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              backgroundColor: Color(0xFF004D40),
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                elevation: 3,
                shadowColor: const Color(0xFF00796B).withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.3),
              ),
            ),
          ),
          home: _showLanguageSetup
              ? LanguageSetupScreen(
                  onSetupComplete: () {
                    setState(() {
                      _showLanguageSetup = false;
                    });
                  },
                )
              : const LoginScreen(),
        );
      },
    );
  }
}

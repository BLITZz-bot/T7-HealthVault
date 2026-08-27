import 'package:flutter/material.dart';
import '../services/language_service.dart';

/// First-run onboarding screen for language selection
class LanguageSetupScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const LanguageSetupScreen({
    super.key,
    required this.onSetupComplete,
  });

  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends State<LanguageSetupScreen> {
  String _selectedCode = 'en';

  @override
  void initState() {
    super.initState();
    _selectedCode = LanguageService.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF004D40), Color(0xFF00796B), Color(0xFF009688)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.health_and_safety, size: 64, color: Colors.white),
              const SizedBox(height: 12),
              const Text(
                'T7 HealthVault',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select Your Language / अपनी भाषा चुनें',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(40),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    itemCount: LanguageService.supportedLanguages.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final lang = LanguageService.supportedLanguages[i];
                      final isSelected = lang['code'] == _selectedCode;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF00796B).withAlpha(20),
                        leading: Text(
                          lang['flag'] ?? '🌐',
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(
                          lang['native']!,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? const Color(0xFF00796B) : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          lang['name']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? const Color(0xFF00796B) : Colors.grey[600],
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF00796B), size: 26)
                            : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        onTap: () {
                          setState(() {
                            _selectedCode = lang['code']!;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF004D40),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: () async {
                      await LanguageService.setLanguage(_selectedCode);
                      await LanguageService.completeFirstRun();
                      widget.onSetupComplete();
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue / आगे बढ़ें',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

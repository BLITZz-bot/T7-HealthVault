import 'package:flutter/material.dart';
import '../services/language_service.dart';

/// Language switcher — built-in languages switch instantly,
/// downloadable packs show a download button with progress indicator.
class LanguageSwitcherWidget extends StatelessWidget {
  final bool showLabel;

  const LanguageSwitcherWidget({
    super.key,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        final info = LanguageService.getLanguageInfo(currentLang);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => showLanguageModal(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(120), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.translate, size: 16, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      info['native'] ?? info['name'] ?? 'Lang',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void showLanguageModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _LanguagePickerSheet(parentContext: context),
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  final BuildContext parentContext;
  const _LanguagePickerSheet({required this.parentContext});

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  static const Color _teal = Color(0xFF00796B);
  static const Color _tealLight = Color(0xFFE0F2F1);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, currentLang, child) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: LanguageService.downloadedLanguagesNotifier,
          builder: (context, downloaded, child) {
            return ValueListenableBuilder<String?>(
              valueListenable: LanguageService.downloadingLanguageNotifier,
              builder: (context, downloading, child) {
                return ValueListenableBuilder<double>(
                  valueListenable: LanguageService.langDownloadProgressNotifier,
                  builder: (context, progress, child) {
                    return Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(context),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionLabel('✓  Available Languages (11)', Colors.green[700]!),
                                  const SizedBox(height: 6),
                                  _buildBuiltInList(currentLang, context),
                                  const SizedBox(height: 20),
                                  _sectionLabel('⬇  Downloadable Language Packs (11)', _teal),
                                  const SizedBox(height: 4),
                                  Text(
                                    'All 22 official Scheduled Languages of India. Tap download — works offline after download.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildDownloadableList(
                                    currentLang: currentLang,
                                    downloaded: downloaded,
                                    downloading: downloading,
                                    progress: progress,
                                    context: context,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00796B), Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.translate, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language Pack',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '22 Scheduled Languages of India',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
    );
  }

  Widget _buildBuiltInList(String currentLang, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: LanguageService.supportedLanguages.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, i) {
          final lang = LanguageService.supportedLanguages[i];
          final isSelected = lang['code'] == currentLang;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isSelected ? const Color(0xFF00796B) : Colors.grey.shade100,
              child: Text(lang['flag'] ?? '🌐', style: const TextStyle(fontSize: 16)),
            ),
            title: Text(
              lang['native']!,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF00796B) : Colors.black87,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              lang['name']!,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00796B) : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: isSelected
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 11)),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () async {
              await LanguageService.setLanguage(lang['code']!);
              if (context.mounted) Navigator.pop(context);
              if (widget.parentContext.mounted) {
                ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                  SnackBar(
                    content: Text('Language: ${lang['name']} (${lang['native']})'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF00796B),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildDownloadableList({
    required String currentLang,
    required Set<String> downloaded,
    required String? downloading,
    required double progress,
    required BuildContext context,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: LanguageService.downloadableLanguages.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, i) {
          final lang = LanguageService.downloadableLanguages[i];
          final code = lang['code']!;
          final isDownloaded = downloaded.contains(code);
          final isActive = code == currentLang;
          final isThisDownloading = downloading == code;
          final isAnyDownloading = downloading != null;

          return ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isActive
                  ? const Color(0xFF00796B)
                  : isDownloaded
                      ? _tealLight
                      : Colors.grey.shade100,
              child: Text(lang['flag'] ?? '🇮🇳', style: const TextStyle(fontSize: 16)),
            ),
            title: Text(
              lang['native']!,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF00796B) : Colors.black87,
                fontSize: 15,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang['name']!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (isThisDownloading) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
                      minHeight: 5,
                    ),
                  ),
                  Text(
                    'Installing... ${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF00796B)),
                  ),
                ],
              ],
            ),
            trailing: isActive
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 11)),
                  )
                : isThisDownloading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
                        ),
                      )
                    : isDownloaded
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  await LanguageService.setLanguage(code);
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _tealLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF00796B)),
                                  ),
                                  child: const Text(
                                    'Use',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF00796B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _confirmDelete(context, code, lang['native']!),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                ),
                              ),
                            ],
                          )
                        : GestureDetector(
                            onTap: isAnyDownloading
                                ? null
                                : () => _startDownload(context, code, lang['native']!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAnyDownloading ? Colors.grey[100] : _tealLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isAnyDownloading ? Colors.grey : const Color(0xFF00796B),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.download_rounded,
                                    size: 14,
                                    color: isAnyDownloading ? Colors.grey : const Color(0xFF00796B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    lang['size'] ?? '~2 MB',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isAnyDownloading ? Colors.grey : const Color(0xFF00796B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
          );
        },
      ),
    );
  }

  void _startDownload(BuildContext context, String code, String native) {
    LanguageService.downloadLanguagePack(code).then((success) {
      if (!mounted) return;
      final msg = success
          ? '$native language pack installed. Tap "Use" to activate.'
          : 'Download failed. Please try again.';
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: success ? const Color(0xFF00796B) : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _confirmDelete(BuildContext context, String code, String native) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Language Pack'),
        content: Text('Remove $native language pack? You can re-download it anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dctx);
              await LanguageService.deleteLanguagePack(code);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

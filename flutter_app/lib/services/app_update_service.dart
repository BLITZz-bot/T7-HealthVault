import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String htmlUrl;
  final String publishedAt;
  final bool hasUpdate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.htmlUrl,
    required this.publishedAt,
    required this.hasUpdate,
  });
}

class AppUpdateService {
  static const String currentVersion = '1.0.0';
  static const String githubOwner = 'BLITZz-bot';
  static const String githubRepo = 'T7-HealthVault';

  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  static const String fallbackApkDownloadUrl =
      'https://github.com/$githubOwner/$githubRepo/releases/latest/download/app-release.apk';

  /// Compare two semantic version strings (e.g. "1.0.1" vs "1.0.0")
  static bool isNewerVersion(String latest, String current) {
    try {
      final cleanLatest = latest.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');

      final latestParts = cleanLatest.split('.').map(int.parse).toList();
      final currentParts = cleanCurrent.split('.').map(int.parse).toList();

      final length = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (int i = 0; i < length; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return latest.trim() != current.trim();
    }
  }

  /// Check GitHub Releases for updates
  static Future<AppUpdateInfo?> checkLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(latestReleaseApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawTag = (data['tag_name'] ?? '').toString();
        final releaseNotes = (data['body'] ?? 'No release notes provided.').toString();
        final htmlUrl = (data['html_url'] ?? '').toString();
        final publishedAt = (data['published_at'] ?? '').toString();

        String downloadUrl = fallbackApkDownloadUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          for (var asset in assets) {
            final name = (asset['name'] ?? '').toString().toLowerCase();
            if (name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] ?? downloadUrl;
              break;
            }
          }
        }

        final hasUpdate = isNewerVersion(rawTag, currentVersion);

        return AppUpdateInfo(
          latestVersion: rawTag.isNotEmpty ? rawTag : 'v$currentVersion',
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
          htmlUrl: htmlUrl,
          publishedAt: publishedAt,
          hasUpdate: hasUpdate,
        );
      }
      return null;
    } catch (e) {
      debugPrint('AppUpdateService error: $e');
      return null;
    }
  }

  /// Check and prompt user with UI dialog
  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool showUpToDateFeedback = true,
  }) async {
    // Show quick checking indicator if manually requested
    if (showUpToDateFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Checking for updates on GitHub...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final info = await checkLatestRelease();

    if (!context.mounted) return;

    if (info == null) {
      if (showUpToDateFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect to GitHub releases. Please check your internet connection.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (info.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.system_update_rounded, color: Color(0xFF00796B), size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Update Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('New version ready to download', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Installed: v$currentVersion',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                      Text(
                        'Latest: ${info.latestVersion}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Release Notes:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    info.releaseNotes.isNotEmpty ? info.releaseNotes : 'Performance improvements and bug fixes.',
                    style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(info.downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  final htmlUri = Uri.parse(info.htmlUrl);
                  await launchUrl(htmlUri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download APK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      if (showUpToDateFeedback) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
                SizedBox(width: 10),
                Text('App is Up to Date'),
              ],
            ),
            content: Text(
              'You are on the latest version (v$currentVersion).\nNo updates available at this time.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}

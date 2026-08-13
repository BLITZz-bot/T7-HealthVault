import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static final ImagePicker _picker = ImagePicker();

  /// Prompts the user with a BottomSheet to choose either Camera or Gallery / Device Storage,
  /// accepts any standard image format, validates <= 5MB, automatically compresses to an avatar thumbnail,
  /// and returns Base64 string.
  static Future<String?> pickAndCompressImage(BuildContext context) async {
    try {
      // 1. Show modal bottom sheet to select Camera or Gallery / Storage
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Select Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004D40),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Color(0xFF00796B)),
                  ),
                  title: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Take a new photo with device camera (Auto-compressed)'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library, color: Color(0xFF00796B)),
                  ),
                  title: const Text('Device Storage / Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Choose from photos or files (Max 5MB)'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) {
        return null; // User dismissed bottom sheet
      }

      // 2. Pick image from selected source (accepts any image format)
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return null; // User cancelled capture/selection
      }

      final Uint8List rawBytes = await pickedFile.readAsBytes();
      if (rawBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected image file.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      // 3. For gallery picks, check if raw file > 5MB and warn user
      if (source == ImageSource.gallery && rawBytes.length > maxFileSizeBytes) {
        final double sizeInMb = rawBytes.length / (1024 * 1024);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Image too large (${sizeInMb.toStringAsFixed(1)} MB). Maximum allowed size is 5 MB.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return null;
      }

      // 4. Compress to optimized thumbnail Base64 (~20-40 KB)
      final compressedBase64 = await compressToThumbnail(rawBytes, targetSize: 300);
      return compressedBase64;
    } catch (e) {
      debugPrint('Error picking or compressing image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Compress raw image bytes to an avatar thumbnail base64 string using dart:ui
  static Future<String?> compressToThumbnail(Uint8List imageBytes, {int targetSize = 300}) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: targetSize,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error in compressToThumbnail: $e');
      return null;
    }
  }

  /// Safely decode Base64 string to MemoryImage, returns null if invalid
  static MemoryImage? safeBase64Image(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    try {
      final bytes = base64Decode(base64String.trim());
      return MemoryImage(bytes);
    } catch (e) {
      debugPrint('Invalid base64 image: $e');
      return null;
    }
  }
}

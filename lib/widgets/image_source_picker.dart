import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Shows a small bottom sheet letting the user choose "Kameradan Çek" or
/// "Galeriden Seç", then immediately launches the corresponding picker.
/// Returns the picked file, or `null` if the sheet was dismissed or no
/// image was picked.
Future<XFile?> pickImageSource(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kameradan Çek'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
  if (source == null) return null;
  return ImagePicker().pickImage(source: source, imageQuality: 85);
}

/// Best-effort MIME type for a picked image, based on its extension —
/// good enough for Gemini's inline image data since pickers only return
/// common photo formats.
String imageMimeTypeFor(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}

/// Lets the user pick a photo (camera or gallery), then rotate/crop it
/// before sending — the standard "take photo → crop → send" flow. When
/// the user cancels either step, this returns `null`. The result is
/// always re-encoded as JPEG bytes by the cropper.
Future<Uint8List?> pickAndCropImage(BuildContext context) async {
  final file = await pickImageSource(context);
  if (file == null) return null;
  if (!context.mounted) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: file.path,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Fotoğrafı Düzenle',
        lockAspectRatio: false,
        hideBottomControls: false,
      ),
      IOSUiSettings(title: 'Fotoğrafı Düzenle'),
    ],
  );
  if (cropped == null) return null;
  return cropped.readAsBytes();
}

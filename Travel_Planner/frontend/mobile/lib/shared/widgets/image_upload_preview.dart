import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ImageUploadPreview extends StatelessWidget {
  final Uint8List? selectedBytes;
  final String? imageUrl;
  final bool circular;
  final String buttonLabel;
  final double height;
  final VoidCallback? onPick;

  const ImageUploadPreview({
    super.key,
    required this.selectedBytes,
    required this.imageUrl,
    required this.onPick,
    this.circular = false,
    this.buttonLabel = 'Chọn ảnh',
    this.height = 168,
  });

  Widget _placeholder() => Container(
    color: AppColors.surfaceSoft,
    alignment: Alignment.center,
    child: const Icon(
      Icons.add_photo_alternate_outlined,
      size: 36,
      color: AppColors.textSecondary,
    ),
  );

  Widget _image() {
    if (selectedBytes != null) {
      return Image.memory(
        selectedBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  @override
  Widget build(BuildContext context) {
    final preview = circular
        ? SizedBox(width: 96, height: 96, child: ClipOval(child: _image()))
        : SizedBox(
            width: double.infinity,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _image(),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (circular) Center(child: preview) else preview,
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(buttonLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

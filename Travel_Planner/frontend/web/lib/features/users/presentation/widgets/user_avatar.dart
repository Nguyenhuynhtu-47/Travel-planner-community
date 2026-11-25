import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double size;
  final double fontSize;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.size = 34,
    this.fontSize = 12,
  });

  /// Resolves an HTTP(S) or root-relative `/...` avatar path into a validated URL,
  /// returning `null` when absent or malformed so the UI falls back to initials.
  static String? resolveValidUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;

    String candidate;
    if (trimmed.startsWith('/')) {
      if (trimmed.startsWith('//')) return null;
      candidate = '${ApiConstants.baseUrl}$trimmed';
    } else {
      candidate = trimmed;
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.trim().isEmpty) {
      return null;
    }
    return uri.toString();
  }

  Widget _buildFallbackLetter() {
    final trimmedName = displayName.trim();
    final letter = trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : 'U';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveValidUrl(avatarUrl);
    if (resolvedUrl == null) {
      return _buildFallbackLetter();
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          resolvedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildFallbackLetter();
          },
          errorBuilder: (_, _, _) => _buildFallbackLetter(),
        ),
      ),
    );
  }
}

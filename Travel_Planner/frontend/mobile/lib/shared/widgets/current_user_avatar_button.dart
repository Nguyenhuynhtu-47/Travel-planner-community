import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CurrentUserAvatarButton extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onPressed;

  const CurrentUserAvatarButton({
    super.key,
    required this.avatarUrl,
    required this.onPressed,
  });

  Widget _fallback() => const ColoredBox(
    color: AppColors.surfaceStrong,
    child: Center(
      child: Icon(Icons.person, size: 20, color: AppColors.textSecondary),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    return IconButton(
      tooltip: 'Hồ sơ cá nhân',
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: SizedBox(
        width: 32,
        height: 32,
        child: ClipOval(
          child: url.startsWith('http')
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }
}

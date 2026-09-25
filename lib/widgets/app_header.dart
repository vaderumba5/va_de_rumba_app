import 'package:flutter/material.dart';

import 'user_avatar.dart';
import '../core/app_theme.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onMenuPressed,
    this.action,
    this.onNotificationsPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onMenuPressed;
  final Widget? action;

  /// Reserved for the future notifications module. Without a callback, the
  /// control is intentionally absent.
  final VoidCallback? onNotificationsPressed;

  @override
  Size get preferredSize => const Size.fromHeight(82);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.topBarBackground,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: EdgeInsets.only(
            left: onMenuPressed == null ? 32 : 12,
            right: 16,
          ),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: LayoutBuilder(builder: (context, constraints) {
            final showSearch = constraints.maxWidth >= 760;
            return Row(
              children: [
                if (onMenuPressed != null) ...[
                  IconButton(
                    tooltip: 'Abrir menú',
                    onPressed: onMenuPressed,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(),
                    ).copyWith(
                      overlayColor:
                          const WidgetStatePropertyAll(Color(0x14000000)),
                    ),
                    icon: const Icon(Icons.menu, color: Colors.black, size: 21),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (showSearch) ...[
                  const SizedBox(width: 24),
                  const SizedBox(width: 260, child: _SearchField()),
                ],
                const SizedBox(width: 12),
                if (onNotificationsPressed != null)
                  IconButton(
                    tooltip: 'Notificaciones',
                    onPressed: onNotificationsPressed,
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: AppColors.textPrimary),
                  ),
                if (action != null) action!,
                const SizedBox(width: 14),
                const UserAvatar(),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar…',
            hintStyle:
                const TextStyle(fontSize: 13, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding: EdgeInsets.zero,
            fillColor: AppColors.surfaceSoft,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      );
}

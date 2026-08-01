import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onMenuPressed,
    this.action,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onMenuPressed;
  final Widget? action;

  @override
  Size get preferredSize => const Size.fromHeight(82);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFCFCFE),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE9E8F0)))),
          child: LayoutBuilder(builder: (context, constraints) {
            final showSearch = constraints.maxWidth >= 760;
            return Row(
              children: [
                if (onMenuPressed != null) ...[
                  IconButton.filledTonal(
                      onPressed: onMenuPressed,
                      icon: const Icon(Icons.menu_rounded, size: 21)),
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
                              color: Color(0xFF29252E))),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF77727D))),
                    ],
                  ),
                ),
                if (showSearch) ...[
                  const SizedBox(width: 24),
                  const SizedBox(width: 260, child: _SearchField()),
                ],
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () {},
                  icon: const Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: Color(0xFF575360)),
                      Positioned(
                          right: 0,
                          top: 0,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: Color(0xFF6255E7),
                                  shape: BoxShape.circle),
                              child: SizedBox(width: 7, height: 7))),
                    ],
                  ),
                ),
                if (action != null) action!,
                const SizedBox(width: 14),
                const _HeaderAvatar(),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF9288FF), Color(0xFF5E52DC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x335E52DC), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: const Center(
          child: Text('VR',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar…',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9A96A2)),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding: EdgeInsets.zero,
            fillColor: const Color(0xFFF6F5F9),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFE9E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFF6255E7))),
          ),
        ),
      );
}

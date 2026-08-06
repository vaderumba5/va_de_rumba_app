import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'logo.dart';
import 'user_avatar.dart';
import '../core/app_theme.dart';

enum AppSection {
  dashboard,
  calendar,
  concerts,
  webPublishing,
  repertoire,
  finances,
  documents,
  settings,
  users,
}

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.currentSection,
    required this.onSectionSelected,
    this.compact = false,
    required this.allowedSections,
  });

  final AppSection currentSection;
  final ValueChanged<AppSection> onSectionSelected;
  final bool compact;
  final List<AppSection> allowedSections;

  static const double width = 276;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : width,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 34),
              child: Row(
                children: [
                  Logo(width: 42, compact: true, borderRadius: 13),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VA DE RUMBA',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1)),
                        SizedBox(height: 2),
                        Text('Gestión interna',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _MenuLabel('GENERAL'),
            const _MenuItem(
                AppSection.dashboard, Icons.home_outlined, 'Inicio'),
            const _MenuItem(AppSection.calendar, Icons.calendar_month_outlined,
                'Calendario'),
            const _MenuItem(
                AppSection.concerts, Icons.mic_none_rounded, 'Conciertos'),
            const _MenuItem(AppSection.webPublishing, Icons.public_rounded,
                'Publicación web'),
            const _MenuItem(
                AppSection.repertoire, Icons.queue_music_rounded, 'Repertorio'),
            const SizedBox(height: 22),
            const _MenuLabel('GESTIÓN'),
            const _MenuItem(
                AppSection.finances, Icons.savings_outlined, 'Fondo'),
            const _MenuItem(
                AppSection.documents, Icons.description_outlined, 'Documentos'),
            const _MenuItem(AppSection.users,
                Icons.admin_panel_settings_outlined, 'Administración'),
            const Spacer(),
            const _UserSummary(),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Divider(height: 1, color: AppColors.border),
            ),
            const _MenuItem(
                AppSection.settings, Icons.settings_outlined, 'Ajustes'),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: _ConnectionFooter(),
            ),
          ].map((child) {
            if (child is _MenuItem) {
              if (!allowedSections.contains(child.section)) {
                return const SizedBox.shrink();
              }
              return _menuButton(context, child);
            }
            return child;
          }).toList(),
        ),
      ),
    );
  }

  Widget _menuButton(BuildContext context, _MenuItem item) {
    final selected = item.section == currentSection;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? AppColors.menuItemSelected
            : AppColors.menuItemBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSectionSelected(item.section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 21,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.iconSecondary),
                const SizedBox(width: 12),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.navigationText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserSummary extends StatelessWidget {
  const _UserSummary();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?.displayName?.trim();
          final email = user?.email ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const UserAvatar(size: 36, borderRadius: 11, showShadow: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null || name.isEmpty ? 'Mi cuenta' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _ConnectionFooter extends StatelessWidget {
  const _ConnectionFooter();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.successText,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x9957D6A5), blurRadius: 7)],
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Firebase conectado',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          const Text('v1.0.0',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted)),
        ],
      );
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textMuted)),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.section, this.icon, this.label);
  final AppSection section;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

import 'package:flutter/material.dart';

import 'logo.dart';

enum AppSection {
  dashboard,
  calendar,
  concerts,
  clients,
  finances,
  documents,
  settings,
}

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.currentSection,
    required this.onSectionSelected,
    this.compact = false,
  });

  final AppSection currentSection;
  final ValueChanged<AppSection> onSectionSelected;
  final bool compact;

  static const double width = 276;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : width,
      decoration: const BoxDecoration(
        color: Color(0xFF171621),
        border: Border(right: BorderSide(color: Color(0xFF2A2937))),
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
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1)),
                        SizedBox(height: 2),
                        Text('Gestión interna',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFA6A4B5))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _MenuLabel('GENERAL'),
            const _MenuItem(
                AppSection.dashboard, Icons.home_outlined, 'Dashboard'),
            const _MenuItem(AppSection.calendar, Icons.calendar_month_outlined,
                'Calendario'),
            const _MenuItem(
                AppSection.concerts, Icons.mic_none_rounded, 'Conciertos'),
            const SizedBox(height: 22),
            const _MenuLabel('GESTIÓN'),
            const _MenuItem(
                AppSection.clients, Icons.groups_outlined, 'Clientes'),
            const _MenuItem(AppSection.finances,
                Icons.account_balance_wallet_outlined, 'Economía'),
            const _MenuItem(
                AppSection.documents, Icons.description_outlined, 'Documentos'),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Divider(height: 1, color: Color(0xFF343241)),
            ),
            const _MenuItem(
                AppSection.settings, Icons.settings_outlined, 'Ajustes'),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: _ConnectionFooter(),
            ),
          ].map((child) {
            if (child is _MenuItem) {
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
        color: selected ? const Color(0xFF302C50) : Colors.transparent,
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
                        ? const Color(0xFFAFA7FF)
                        : const Color(0xFFA6A4B5)),
                const SizedBox(width: 12),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            selected ? Colors.white : const Color(0xFFD2D0DA))),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
              color: Color(0xFF57D6A5),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x9957D6A5), blurRadius: 7)],
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Firebase conectado',
                style: TextStyle(fontSize: 11, color: Color(0xFFA6A4B5))),
          ),
          const Text('v1.0.0',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF777482))),
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
                color: Color(0xFF898695))),
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

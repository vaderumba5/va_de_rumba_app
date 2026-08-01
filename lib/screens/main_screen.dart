import 'package:flutter/material.dart';

import '../widgets/app_layout.dart';
import '../widgets/side_menu.dart';
import 'calendar_screen.dart';
import 'concerts_screen.dart';
import 'dashboard_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  AppSection _section = AppSection.dashboard;

  @override
  Widget build(BuildContext context) {
    final page = _pageFor(_section);
    return AppLayout(
      section: _section,
      onSectionSelected: (section) {
        setState(() => _section = section);
      },
      title: page.title,
      subtitle: page.subtitle,
      child: page.child,
    );
  }

  _Page _pageFor(AppSection section) {
    switch (section) {
      case AppSection.dashboard:
        return const _Page(
            'Dashboard', 'Visión general de Va de Rumba', DashboardScreen());
      case AppSection.calendar:
        return const _Page('Calendario', 'Planificación de conciertos',
            CalendarScreen(embedded: true));
      case AppSection.concerts:
        return const _Page(
            'Conciertos', 'Agenda y gestión de actuaciones', ConcertsScreen());
      case AppSection.clients:
        return const _Page('Clientes', 'Próximamente',
            _PlaceholderPage(icon: Icons.groups_outlined, title: 'Clientes'));
      case AppSection.finances:
        return const _Page(
            'Economía',
            'Próximamente',
            _PlaceholderPage(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Economía'));
      case AppSection.documents:
        return const _Page(
            'Documentos',
            'Próximamente',
            _PlaceholderPage(
                icon: Icons.description_outlined, title: 'Documentos'));
      case AppSection.settings:
        return const _Page('Ajustes', 'Configuración de la aplicación',
            _PlaceholderPage(icon: Icons.settings_outlined, title: 'Ajustes'));
    }
  }
}

class _Page {
  const _Page(this.title, this.subtitle, this.child);
  final String title;
  final String subtitle;
  final Widget child;
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 42, color: const Color(0xFF918B98)),
        const SizedBox(height: 14),
        Text('$title estará disponible próximamente',
            style: const TextStyle(fontSize: 16, color: Color(0xFF69636E))),
      ]));
}

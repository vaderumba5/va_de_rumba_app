import 'package:flutter/material.dart';

import '../widgets/app_layout.dart';
import '../widgets/side_menu.dart';
import 'calendar_screen.dart';
import 'concerts_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'fund_screen.dart';
import 'documents_screen.dart';
import 'repertoire_screen.dart';
import 'admin/users_screen.dart';
import '../models/app_permission.dart';
import '../providers/current_user_scope.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  AppSection _section = AppSection.dashboard;

  @override
  Widget build(BuildContext context) {
    final user = CurrentUserScope.of(context);
    const authorization = CurrentUserScope.authorization;
    final allowed = AppSection.values
        .where((section) => authorization.canViewModule(user, section.module))
        .toList();
    if (!allowed.contains(_section) && allowed.isNotEmpty) {
      _section = allowed.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No tienes permiso para acceder a este apartado.'),
          ));
        }
      });
    }
    if (allowed.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No tienes ningún módulo habilitado.')),
      );
    }
    final page = _pageFor(_section);
    return AppLayout(
      section: _section,
      onSectionSelected: (section) {
        setState(() => _section = section);
      },
      title: page.title,
      subtitle: page.subtitle,
      allowedSections: allowed,
      child: page.child,
    );
  }

  _Page _pageFor(AppSection section) {
    switch (section) {
      case AppSection.dashboard:
        return _Page(
          'Inicio',
          'Visión general de Va de Rumba',
          DashboardScreen(
            onOpenFund: () => setState(() => _section = AppSection.finances),
          ),
        );
      case AppSection.calendar:
        return const _Page('Calendario', 'Planificación de conciertos',
            CalendarScreen(embedded: true));
      case AppSection.concerts:
        return const _Page(
            'Conciertos', 'Agenda y gestión de actuaciones', ConcertsScreen());
      case AppSection.repertoire:
        return const _Page('Repertorio', 'Canciones y repertorios de directo',
            RepertoireScreen());
      case AppSection.finances:
        return const _Page('Fondo', 'Cuenta común del grupo', FundScreen());
      case AppSection.documents:
        return const _Page(
            'Documentación', 'Archivos del grupo', DocumentsScreen());
      case AppSection.settings:
        return const _Page(
            'Ajustes', 'Perfil, seguridad y sesión', SettingsScreen());
      case AppSection.users:
        return const _Page(
            'Administración', 'Usuarios y permisos', UsersScreen());
    }
  }
}

extension on AppSection {
  String get module => switch (this) {
        AppSection.dashboard => AppModules.dashboard,
        AppSection.calendar => AppModules.calendar,
        AppSection.concerts => AppModules.concerts,
        AppSection.repertoire => AppModules.repertoire,
        AppSection.finances => AppModules.fund,
        AppSection.documents => AppModules.documents,
        AppSection.settings => AppModules.settings,
        AppSection.users => AppModules.users,
      };
}

class _Page {
  const _Page(this.title, this.subtitle, this.child);
  final String title;
  final String subtitle;
  final Widget child;
}

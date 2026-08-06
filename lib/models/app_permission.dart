enum PermissionLevel {
  none,
  view,
  manage;

  static PermissionLevel fromValue(Object? value) => switch (value) {
        'manage' => PermissionLevel.manage,
        'view' => PermissionLevel.view,
        _ => PermissionLevel.none,
      };

  String get value => name;
}

abstract final class AppModules {
  static const dashboard = 'dashboard';
  static const calendar = 'calendar';
  static const concerts = 'concerts';
  static const repertoire = 'repertoire';
  static const fund = 'fund';
  static const documents = 'documents';
  static const settings = 'settings';
  static const users = 'users';

  static const all = <String>[
    dashboard,
    calendar,
    concerts,
    repertoire,
    fund,
    documents,
    settings,
    users,
  ];

  static const labels = <String, String>{
    dashboard: 'Inicio',
    calendar: 'Calendario',
    concerts: 'Conciertos',
    repertoire: 'Repertorio',
    fund: 'Fondo',
    documents: 'Documentos',
    settings: 'Ajustes',
    users: 'Usuarios y permisos',
  };
}

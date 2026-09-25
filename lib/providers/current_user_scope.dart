import 'package:flutter/widgets.dart';

import '../models/app_user.dart';
import '../services/authorization_service.dart';

class CurrentUserScope extends InheritedWidget {
  const CurrentUserScope({
    super.key,
    required this.user,
    required super.child,
  });

  final AppUser user;
  static const authorization = AuthorizationService();

  static AppUser of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CurrentUserScope>();
    assert(scope != null, 'CurrentUserScope no encontrado');
    return scope!.user;
  }

  @override
  bool updateShouldNotify(CurrentUserScope oldWidget) => oldWidget.user != user;
}

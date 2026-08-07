import 'package:flutter/material.dart';

import '../models/app_permission.dart';
import '../providers/current_user_scope.dart';

class PermissionGuard extends StatelessWidget {
  const PermissionGuard({
    super.key,
    required this.module,
    required this.requiredLevel,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String module;
  final PermissionLevel requiredLevel;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final user = CurrentUserScope.of(context);
    const auth = CurrentUserScope.authorization;
    final allowed = requiredLevel == PermissionLevel.manage
        ? auth.canManageModule(user, module)
        : auth.canViewModule(user, module);
    return allowed ? child : fallback;
  }
}

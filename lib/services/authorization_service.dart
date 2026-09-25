import '../models/app_permission.dart';
import '../models/app_user.dart';

class AuthorizationService {
  const AuthorizationService();

  bool isOwner(AppUser user) => user.isOwnerEmail;
  bool isAdmin(AppUser user) => isOwner(user) || user.role == UserRole.admin;

  PermissionLevel levelFor(AppUser user, String module) => isOwner(user)
      ? PermissionLevel.manage
      : user.permissions[module] ?? PermissionLevel.none;

  bool canViewModule(AppUser user, String module) {
    final level = levelFor(user, module);
    return level == PermissionLevel.view || level == PermissionLevel.manage;
  }

  bool canManageModule(AppUser user, String module) =>
      levelFor(user, module) == PermissionLevel.manage;

  bool canManageUsers(AppUser user) =>
      isOwner(user) ||
      (user.role == UserRole.admin && canManageModule(user, AppModules.users));
}

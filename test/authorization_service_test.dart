import 'package:flutter_test/flutter_test.dart';
import 'package:va_de_rumba/models/app_permission.dart';
import 'package:va_de_rumba/models/app_user.dart';
import 'package:va_de_rumba/services/authorization_service.dart';

void main() {
  const authorization = AuthorizationService();

  AppUser user({
    String email = 'member@example.com',
    UserRole role = UserRole.member,
    bool active = true,
    Map<String, PermissionLevel> permissions = const {},
  }) =>
      AppUser(
        uid: 'uid',
        email: email,
        displayName: 'Test',
        role: role,
        isActive: active,
        permissions: permissions,
      );

  test('owner always has full access based on normalized email', () {
    final owner = user(
      email: '  GRUPOVADERUMBA@GMAIL.COM ',
      active: false,
    );
    expect(authorization.isOwner(owner), isTrue);
    expect(
      authorization.canManageModule(owner, AppModules.users),
      isTrue,
    );
  });

  test('view does not imply manage', () {
    final member = user(
      permissions: const {AppModules.concerts: PermissionLevel.view},
    );
    expect(authorization.canViewModule(member, AppModules.concerts), isTrue);
    expect(authorization.canManageModule(member, AppModules.concerts), isFalse);
  });

  test('missing permission is none', () {
    expect(
      authorization.canViewModule(user(), AppModules.documents),
      isFalse,
    );
  });

  test('admin needs explicit users manage permission', () {
    expect(
      authorization.canManageUsers(user(role: UserRole.admin)),
      isFalse,
    );
    expect(
      authorization.canManageUsers(user(
        role: UserRole.admin,
        permissions: const {AppModules.users: PermissionLevel.manage},
      )),
      isTrue,
    );
  });
}

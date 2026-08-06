import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_permission.dart';

const ownerEmail = 'grupovaderumba@gmail.com';

enum UserRole {
  owner,
  admin,
  member;

  static UserRole fromValue(Object? value) => switch (value) {
        'owner' => UserRole.owner,
        'admin' => UserRole.admin,
        _ => UserRole.member,
      };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.photoVersion,
    required this.role,
    required this.isActive,
    required this.permissions,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int? photoVersion;
  final UserRole role;
  final bool isActive;
  final Map<String, PermissionLevel> permissions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOwnerEmail => email.trim().toLowerCase() == ownerEmail;

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    String fallbackEmail = '',
    String fallbackName = '',
  }) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final email = (data['email'] as String? ?? fallbackEmail).trim();
    final owner = email.toLowerCase() == ownerEmail;
    final rawPermissions = data['permissions'];
    final permissions = <String, PermissionLevel>{};
    if (rawPermissions is Map) {
      for (final entry in rawPermissions.entries) {
        if (entry.key is String) {
          permissions[entry.key as String] =
              PermissionLevel.fromValue(entry.value);
        }
      }
    }
    return AppUser(
      uid: snapshot.id,
      email: email,
      displayName: data['displayName'] as String? ?? fallbackName,
      photoUrl: data['photoUrl'] as String?,
      photoVersion: (data['photoVersion'] as num?)?.toInt(),
      role: owner ? UserRole.owner : UserRole.fromValue(data['role']),
      isActive: owner ? true : data['isActive'] as bool? ?? true,
      permissions: permissions,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, Object?> toFirestore() => {
        'email': email.trim().toLowerCase(),
        'displayName': displayName.trim(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (photoVersion != null) 'photoVersion': photoVersion,
        'role': isOwnerEmail ? UserRole.owner.name : role.name,
        'isActive': isOwnerEmail ? true : isActive,
        'permissions': {
          for (final entry in permissions.entries) entry.key: entry.value.value,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    int? photoVersion,
    UserRole? role,
    bool? isActive,
    Map<String, PermissionLevel>? permissions,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        photoVersion: photoVersion ?? this.photoVersion,
        role: isOwnerEmail ? UserRole.owner : role ?? this.role,
        isActive: isOwnerEmail ? true : isActive ?? this.isActive,
        permissions: isOwnerEmail
            ? const {}
            : Map.unmodifiable(permissions ?? this.permissions),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

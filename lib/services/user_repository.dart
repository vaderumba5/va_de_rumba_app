import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/app_permission.dart';
import '../models/app_user.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Creates an Authentication account without replacing the actor's session.
  ///
  /// Firebase Auth instances are isolated per [FirebaseApp]. The temporary
  /// secondary app signs in as the new account while the default app keeps the
  /// owner authenticated. No password is written to Firestore or audit logs.
  Future<void> createUser({
    required AppUser actor,
    required String displayName,
    required String email,
    required String temporaryPassword,
    required UserRole role,
    required bool isActive,
    required Map<String, PermissionLevel> permissions,
  }) async {
    if (!actor.isOwnerEmail) {
      throw StateError('Solo el propietario puede crear usuarios.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == ownerEmail) {
      throw StateError('La cuenta propietaria ya existe.');
    }

    final secondaryApp = await Firebase.initializeApp(
      name: 'user-creation-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    User? createdAuthUser;
    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: temporaryPassword,
      );
      createdAuthUser = credential.user;
      if (createdAuthUser == null) {
        throw StateError('Firebase no ha devuelto el usuario creado.');
      }
      await createdAuthUser.updateDisplayName(displayName.trim());

      final batch = _firestore.batch();
      batch.set(_users.doc(createdAuthUser.uid), {
        'email': normalizedEmail,
        'displayName': displayName.trim(),
        'photoUrl': null,
        'role': role == UserRole.owner ? UserRole.member.name : role.name,
        'isActive': isActive,
        'permissions': permissions.map(
          (key, value) => MapEntry(key, value.value),
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('audit_logs').doc(), {
        'action': 'user_created',
        'performedBy': actor.uid,
        'targetUserId': createdAuthUser.uid,
        'changes': {
          'email': normalizedEmail,
          'role': role.name,
          'isActive': isActive,
          'permissions': permissions.map(
            (key, value) => MapEntry(key, value.value),
          ),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      try {
        await batch.commit();
      } catch (_) {
        // Avoid leaving an Authentication account without an application
        // profile when the Firestore transaction cannot be completed.
        await createdAuthUser.delete();
        createdAuthUser = null;
        rethrow;
      }
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }
  }

  Stream<List<AppUser>> watchAll() => _users.snapshots().map((snapshot) {
        final users = snapshot.docs.map(AppUser.fromFirestore).toList();
        users.sort((a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        return users;
      });

  /// Owner-only, non-destructive normalization for legacy profiles.
  Future<int> normalizeLegacyUsers(AppUser actor) async {
    if (!actor.isOwnerEmail) {
      throw StateError('Solo el propietario puede ejecutar la migración.');
    }
    final snapshot = await _users.get();
    var changed = 0;
    for (final document in snapshot.docs) {
      final data = document.data();
      final patch = <String, Object?>{};
      if (!data.containsKey('role')) patch['role'] = 'member';
      if (!data.containsKey('isActive')) patch['isActive'] = true;
      if (!data.containsKey('permissions')) {
        patch['permissions'] = <String, String>{};
      }
      if (patch.isNotEmpty) {
        patch['updatedAt'] = FieldValue.serverTimestamp();
        await document.reference.update(patch);
        changed++;
      }
    }
    return changed;
  }

  Future<AppUser> loadCurrent(User authUser) async {
    final ref = _users.doc(authUser.uid);
    var snapshot = await ref.get();
    if (!snapshot.exists) {
      final email = (authUser.email ?? '').trim().toLowerCase();
      await ref.set({
        'email': email,
        'displayName': authUser.displayName ?? '',
        'photoUrl': authUser.photoURL,
        'role': email == ownerEmail ? 'owner' : 'member',
        'isActive': true,
        'permissions': <String, String>{},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      snapshot = await ref.get();
    }
    return AppUser.fromFirestore(
      snapshot,
      fallbackEmail: authUser.email ?? '',
      fallbackName: authUser.displayName ?? '',
    );
  }

  Future<void> updateUser({
    required AppUser actor,
    required AppUser original,
    required AppUser updated,
  }) async {
    if (original.isOwnerEmail) {
      throw StateError('La cuenta propietaria está protegida.');
    }
    if (actor.uid == original.uid &&
        (original.role != updated.role ||
            original.permissions.toString() !=
                updated.permissions.toString())) {
      throw StateError('No puedes elevar tus propios permisos.');
    }
    final changes = <String, Object?>{};
    if (original.role != updated.role) changes['role'] = updated.role.name;
    if (original.isActive != updated.isActive) {
      changes['isActive'] = updated.isActive;
    }
    if (original.permissions.toString() != updated.permissions.toString()) {
      changes['permissions'] = updated.permissions.map(
        (key, value) => MapEntry(key, value.value),
      );
    }
    if (original.displayName != updated.displayName) {
      changes['displayName'] = updated.displayName.trim();
    }
    final batch = _firestore.batch();
    batch.update(_users.doc(original.uid), {
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('audit_logs').doc(), {
      'action': 'user_updated',
      'performedBy': actor.uid,
      'targetUserId': original.uid,
      'changes': changes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> deleteUser({
    required AppUser actor,
    required AppUser target,
  }) async {
    if (target.isOwnerEmail) {
      throw StateError('La cuenta propietaria no se puede eliminar.');
    }
    final batch = _firestore.batch();
    batch.delete(_users.doc(target.uid));
    batch.set(_firestore.collection('audit_logs').doc(), {
      'action': 'user_deleted',
      'performedBy': actor.uid,
      'targetUserId': target.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

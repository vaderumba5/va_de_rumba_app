import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Avatar compartido que se actualiza cuando Firebase notifica cambios del usuario.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.size = 42,
    this.borderRadius,
    this.showShadow = true,
  });

  final double size;
  final double? borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return _AvatarContent(
            user: null,
            size: size,
            borderRadius: borderRadius ?? size * .33,
            showShadow: showShadow,
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            final data = profileSnapshot.data?.data();
            final storedUrl = data?['photoUrl'] as String?;
            final version = (data?['photoVersion'] as num?)?.toInt();
            return _AvatarContent(
              user: user,
              photoUrl: storedUrl ?? user.photoURL,
              photoVersion: version,
              size: size,
              borderRadius: borderRadius ?? size * .33,
              showShadow: showShadow,
            );
          },
        );
      },
    );
  }
}

String versionedPhotoUrl(String photoUrl, int? version) {
  if (version == null) return photoUrl;
  final separator = photoUrl.contains('?') ? '&' : '?';
  return '$photoUrl${separator}v=$version';
}

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.user,
    this.photoUrl,
    this.photoVersion,
    required this.size,
    required this.borderRadius,
    required this.showShadow,
  });

  final User? user;
  final String? photoUrl;
  final int? photoVersion;
  final double size;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final resolvedPhotoUrl = photoUrl?.trim() ?? '';
    final initials = _initialsFor(user);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 3))
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedPhotoUrl.isEmpty
          ? _Initials(initials: initials, size: size)
          : Image.network(
              versionedPhotoUrl(resolvedPhotoUrl, photoVersion),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => _Initials(
                initials: initials,
                size: size,
              ),
            ),
    );
  }

  static String _initialsFor(User? user) {
    final name = user?.displayName?.trim() ?? '';
    if (name.isNotEmpty) {
      final words = name.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
      return words.take(2).map((word) => word[0]).join().toUpperCase();
    }
    final email = user?.email?.trim() ?? '';
    return email.isEmpty ? 'VR' : email[0].toUpperCase();
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * .3,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
}

import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/concert_import_service.dart';
import '../widgets/user_avatar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _picker = ImagePicker();
  final _concertImportService = ConcertImportService();

  XFile? _pendingAvatar;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarContentType;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _signingOut = false;
  bool _importingConcerts = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _syncUser(FirebaseAuth.instance.currentUser);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _syncUser(User? user) {
    _nameController.text = user?.displayName ?? '';
    _email = user?.email;
  }

  Future<void> _pickAvatar() async {
    if (_savingProfile) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null) return;

      final extension = _extensionFor(file.name);
      final contentType =
          file.mimeType?.toLowerCase() ?? _mimeTypeFor(extension);
      if (!const {'image/jpeg', 'image/png', 'image/webp'}
          .contains(contentType)) {
        _showMessage('Selecciona una imagen JPG, PNG o WebP.', error: true);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _showMessage('La imagen no puede superar los 5 MB.', error: true);
        return;
      }
      setState(() {
        _pendingAvatar = file;
        _pendingAvatarBytes = bytes;
        _pendingAvatarContentType = contentType;
      });
    } catch (error, stackTrace) {
      debugPrint('Error al seleccionar la foto: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage('No se ha podido seleccionar la imagen.', error: true);
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final name = _nameController.text.trim();
    if (user == null) {
      _showMessage('Tu sesión ya no está disponible.', error: true);
      return;
    }
    if (name.isEmpty) {
      _showMessage('Indica el nombre visible.', error: true);
      return;
    }

    setState(() => _savingProfile = true);
    try {
      String? photoUrl;
      int? photoVersion;
      if (_pendingAvatar != null && _pendingAvatarBytes != null) {
        final reference = FirebaseStorage.instance
            .ref('profile_images/${user.uid}/profile.jpg');
        await reference.putData(
          _pendingAvatarBytes!,
          SettableMetadata(
            contentType: _pendingAvatarContentType ?? 'image/jpeg',
            customMetadata: {'uploadedBy': user.uid},
          ),
        );
        photoUrl = await reference.getDownloadURL();
        photoVersion = DateTime.now().millisecondsSinceEpoch;
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'photoUrl': photoUrl,
            'photoVersion': photoVersion,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await user.updateDisplayName(name);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }
      await user.reload();
      if (!mounted) return;
      setState(() {
        _pendingAvatar = null;
        _pendingAvatarBytes = null;
        _pendingAvatarContentType = null;
        _savingProfile = false;
        _syncUser(FirebaseAuth.instance.currentUser);
      });
      _showMessage('Perfil actualizado correctamente.');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _savingProfile = false);
      _showMessage(_firebaseMessage(error), error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingProfile = false);
      _showMessage('No se ha podido actualizar el perfil.', error: true);
    }
  }

  Future<void> _deleteProfileImage() async {
    if (_savingProfile) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Tu sesión ya no está disponible.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text(
          'Se eliminará tu foto de perfil y volverán a mostrarse tus iniciales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar foto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _savingProfile = true);
    try {
      try {
        await FirebaseStorage.instance
            .ref('profile_images/${user.uid}/profile.jpg')
            .delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'photoUrl': FieldValue.delete(),
        'photoVersion': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await user.updatePhotoURL(null);
      await user.reload();
      if (!mounted) return;
      setState(() {
        _pendingAvatar = null;
        _pendingAvatarBytes = null;
        _pendingAvatarContentType = null;
      });
      _showMessage('Foto de perfil eliminada.');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Error Firebase al eliminar foto: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage(
          'No se pudo eliminar la foto: ${error.message ?? error.code}',
          error: true,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Error al eliminar foto: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage('No se pudo eliminar la imagen de perfil.', error: true);
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;
    if (current.isEmpty || next.isEmpty || confirmation.isEmpty) {
      _showMessage('Completa todos los campos de contraseña.', error: true);
      return;
    }
    if (next.length < 8) {
      _showMessage('La nueva contraseña debe tener al menos 8 caracteres.',
          error: true);
      return;
    }
    if (next != confirmation) {
      _showMessage('La confirmación no coincide con la nueva contraseña.',
          error: true);
      return;
    }
    if (next == current) {
      _showMessage('La nueva contraseña debe ser distinta de la actual.',
          error: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      _showMessage('Esta cuenta no tiene un correo electrónico disponible.',
          error: true);
      return;
    }

    setState(() => _changingPassword = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: current,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(next);
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      _showMessage('Contraseña actualizada correctamente.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _changingPassword = false);
      _showMessage(_authMessage(error), error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _changingPassword = false);
      _showMessage('No se ha podido actualizar la contraseña.', error: true);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres cerrar la sesión en este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      _showMessage(_authMessage(error), error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      _showMessage('No se ha podido cerrar la sesión.', error: true);
    }
  }

  Future<void> _importConcerts2026() async {
    if (_importingConcerts) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar conciertos 2026'),
        content: const Text(
          '¿Quieres importar los conciertos de 2026?\n\nLos conciertos que ya existan no se duplicarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Importar conciertos'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importingConcerts = true);
    try {
      final result = await _concertImportService.import2026Concerts();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            result.imported == 0 && result.errors == 0
                ? 'Conciertos de 2026 ya importados'
                : 'Importación completada',
          ),
          content: Text(
            result.imported == 0 && result.errors == 0
                ? 'No se ha añadido ningún concierto.\nTodos los conciertos ya estaban importados.'
                : '${result.reviewed} conciertos revisados.\n'
                    '${result.imported} conciertos añadidos.\n'
                    '${result.duplicates} conciertos ya existían.\n'
                    '${result.errors} errores.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } on ConcertImportAuthenticationException catch (error, stackTrace) {
      debugPrint('Importación sin sesión: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No tienes permisos para importar conciertos.',
            error: true);
      }
    } on FormatException catch (error, stackTrace) {
      debugPrint(
          'Error leyendo el archivo de importación: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se ha podido leer el archivo de conciertos.',
            error: true);
      }
    } catch (error, stackTrace) {
      debugPrint('Error importando conciertos: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se han podido importar los conciertos.', error: true);
      }
    } finally {
      if (mounted) setState(() => _importingConcerts = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFB63D4D) : null,
    ));
  }

  static String _extensionFor(String name) {
    final separator = name.lastIndexOf('.');
    return separator == -1 ? '' : name.substring(separator + 1).toLowerCase();
  }

  static String _mimeTypeFor(String extension) => switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'application/octet-stream',
      };

  static String _authMessage(FirebaseAuthException error) =>
      switch (error.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'La contraseña actual no es correcta.',
        'weak-password' => 'La nueva contraseña es demasiado débil.',
        'requires-recent-login' =>
          'Tu sesión ha caducado. Vuelve a iniciar sesión e inténtalo de nuevo.',
        'network-request-failed' =>
          'No hay conexión. Comprueba tu red e inténtalo de nuevo.',
        'too-many-requests' =>
          'Demasiados intentos. Espera unos minutos antes de volver a intentarlo.',
        'user-disabled' => 'Esta cuenta está deshabilitada.',
        _ => 'No se ha podido completar la operación. Inténtalo de nuevo.',
      };

  static String _firebaseMessage(FirebaseException error) =>
      error.plugin == 'firebase_storage'
          ? 'No se ha podido subir la imagen. Conservamos tu foto anterior.'
          : _authMessage(FirebaseAuthException(code: error.code));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 600 ? 16 : 28,
              22,
              constraints.maxWidth < 600 ? 16 : 28,
              40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Perfil',
                      subtitle: 'Información visible para tu equipo',
                      child: _ProfileSection(
                        email: _email ?? user?.email ?? '',
                        nameController: _nameController,
                        pendingAvatar: _pendingAvatarBytes,
                        isSaving: _savingProfile,
                        onPickAvatar: _savingProfile ? null : _pickAvatar,
                        onCancelAvatar: _pendingAvatarBytes == null
                            ? null
                            : () => setState(() {
                                  _pendingAvatar = null;
                                  _pendingAvatarBytes = null;
                                  _pendingAvatarContentType = null;
                                }),
                        hasPhoto: (user?.photoURL?.trim().isNotEmpty ?? false),
                        onDeleteAvatar:
                            _savingProfile ? null : _deleteProfileImage,
                        onSave: _savingProfile ? null : _saveProfile,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (user != null) ...[
                      _SectionCard(
                        icon: Icons.file_upload_outlined,
                        title: 'Importación',
                        subtitle: 'Herramientas administrativas',
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Importa los conciertos incluidos en la hoja VdR BOLOS 2026. Los conciertos ya importados se omitirán automáticamente.',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _importingConcerts
                                    ? null
                                    : _importConcerts2026,
                                icon: _importingConcerts
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.upload_file_outlined),
                                label: Text(
                                  _importingConcerts
                                      ? 'Importando…'
                                      : 'Importar conciertos',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    _SectionCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'Seguridad',
                      subtitle: 'Actualiza la contraseña de acceso',
                      child: _PasswordSection(
                        currentController: _currentPasswordController,
                        newController: _newPasswordController,
                        confirmController: _confirmPasswordController,
                        isSaving: _changingPassword,
                        onSave: _changingPassword ? null : _changePassword,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      icon: Icons.logout_rounded,
                      title: 'Sesión',
                      subtitle: 'Gestiona el acceso en este dispositivo',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _signingOut ? null : _signOut,
                          icon: _signingOut
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.logout_rounded),
                          label: const Text('Cerrar sesión'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB63D4D),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E6EF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F0E16),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EFFF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: const Color(0xFF6255E7), size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF77727D))),
                  ],
                ),
              ),
            ]),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1),
            ),
            child,
          ],
        ),
      );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.email,
    required this.nameController,
    required this.pendingAvatar,
    required this.isSaving,
    required this.onPickAvatar,
    required this.onCancelAvatar,
    required this.hasPhoto,
    required this.onDeleteAvatar,
    required this.onSave,
  });

  final String email;
  final TextEditingController nameController;
  final Uint8List? pendingAvatar;
  final bool isSaving;
  final VoidCallback? onPickAvatar;
  final VoidCallback? onCancelAvatar;
  final bool hasPhoto;
  final VoidCallback? onDeleteAvatar;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        pendingAvatar == null
            ? const UserAvatar(size: 82, borderRadius: 25)
            : ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.memory(
                  pendingAvatar!,
                  width: 82,
                  height: 82,
                  fit: BoxFit.cover,
                ),
              ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Material(
            color: const Color(0xFF6255E7),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPickAvatar,
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: Icon(Icons.edit_outlined, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ],
    );
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre visible',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: email,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
      ],
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (compact) ...[
        Center(child: avatar),
        const SizedBox(height: 24),
        fields,
      ] else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          avatar,
          const SizedBox(width: 24),
          Expanded(child: fields),
        ]),
      const SizedBox(height: 12),
      Align(
        alignment: compact ? Alignment.center : Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPickAvatar,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Cambiar foto'),
        ),
      ),
      if (hasPhoto && pendingAvatar == null)
        Align(
          alignment: compact ? Alignment.center : Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onDeleteAvatar,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar foto'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB63D4D),
            ),
          ),
        ),
      if (pendingAvatar != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 15, color: Color(0xFF6255E7)),
            const SizedBox(width: 6),
            const Expanded(
                child: Text('La nueva foto se subirá al guardar los cambios.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6255E7)))),
            TextButton(
                onPressed: onCancelAvatar, child: const Text('Cancelar')),
          ]),
        ),
      const SizedBox(height: 18),
      compact
          ? SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Guardando…' : 'Guardar cambios'),
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Guardando…' : 'Guardar cambios'),
              ),
            ),
    ]);
  }
}

class _PasswordSection extends StatelessWidget {
  const _PasswordSection({
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool isSaving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PasswordField(
              controller: currentController, label: 'Contraseña actual'),
          const SizedBox(height: 14),
          _PasswordField(controller: newController, label: 'Nueva contraseña'),
          const SizedBox(height: 14),
          _PasswordField(
              controller: confirmController,
              label: 'Confirmar nueva contraseña'),
          const SizedBox(height: 18),
          if (MediaQuery.sizeOf(context).width < 600)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_rounded),
                label:
                    Text(isSaving ? 'Actualizando…' : 'Actualizar contraseña'),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_rounded),
                label:
                    Text(isSaving ? 'Actualizando…' : 'Actualizar contraseña'),
              ),
            ),
        ],
      );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.key_outlined),
        ),
      );
}

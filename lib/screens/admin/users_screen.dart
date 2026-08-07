import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_permission.dart';
import '../../models/app_user.dart';
import '../../providers/current_user_scope.dart';
import '../../services/user_repository.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final actor = CurrentUserScope.of(context);
    final repository = UserRepository();
    return StreamBuilder<List<AppUser>>(
      stream: repository.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text(
                  'No se han podido cargar los usuarios.\n${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: EdgeInsets.all(constraints.maxWidth >= 900 ? 32 : 18),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text('${users.length} usuarios',
                      style: Theme.of(context).textTheme.titleMedium),
                  FilledButton.icon(
                    onPressed: actor.isOwnerEmail
                        ? () => showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => _CreateUserDialog(
                                actor: actor,
                                repository: repository,
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Crear usuario'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (users.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No hay usuarios registrados.')),
                )
              else
                ...users.map((user) => _UserCard(
                      user: user,
                      onEdit: () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => _UserEditor(
                          actor: actor,
                          original: user,
                          repository: repository,
                        ),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog({
    required this.actor,
    required this.repository,
  });

  final AppUser actor;
  final UserRepository repository;

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.member;
  bool _active = true;
  bool _obscurePassword = true;
  bool _saving = false;
  late final Map<String, PermissionLevel> _permissions = {
    for (final module in AppModules.all) module: PermissionLevel.none,
  };

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createUser(
        actor: widget.actor,
        displayName: _name.text,
        email: _email.text,
        temporaryPassword: _password.text,
        role: _role,
        isActive: _active,
        permissions: _permissions,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Usuario creado. La sesión del propietario sigue activa.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_authError(error));
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _authError(FirebaseAuthException error) => switch (error.code) {
        'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
        'invalid-email' => 'El correo electrónico no es válido.',
        'weak-password' => 'La contraseña temporal es demasiado débil.',
        'operation-not-allowed' =>
          'La creación con correo y contraseña no está habilitada en Firebase.',
        _ => error.message ?? 'No se ha podido crear el usuario.',
      };

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Crear usuario'),
        content: SizedBox(
          width: 580,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Introduce el nombre.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    enabled: !_saving,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration:
                        const InputDecoration(labelText: 'Correo electrónico'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email)) {
                        return 'Introduce un correo válido.';
                      }
                      if (email.toLowerCase() == ownerEmail) {
                        return 'La cuenta propietaria ya existe.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    enabled: !_saving,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña temporal',
                      helperText:
                          'Mínimo 6 caracteres. No se guarda en Firestore.',
                      suffixIcon: IconButton(
                        onPressed: _saving
                            ? null
                            : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (value) => (value?.length ?? 0) < 6
                        ? 'Usa al menos 6 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('Administrador'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.member,
                        child: Text('Miembro'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _role = value ?? _role),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usuario activo'),
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _active = value),
                  ),
                  const Divider(),
                  ...AppModules.all.map(
                    (module) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DropdownButtonFormField<PermissionLevel>(
                        initialValue: _permissions[module],
                        decoration: InputDecoration(
                          labelText: AppModules.labels[module],
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: PermissionLevel.none,
                            child: Text('Sin acceso'),
                          ),
                          DropdownMenuItem(
                            value: PermissionLevel.view,
                            child: Text('Ver'),
                          ),
                          DropdownMenuItem(
                            value: PermissionLevel.manage,
                            child: Text('Gestionar'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                  _permissions[module] =
                                      value ?? PermissionLevel.none;
                                }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _create,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1),
            label: Text(_saving ? 'Creando…' : 'Crear usuario'),
          ),
        ],
      );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage:
                user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
            child: user.photoUrl == null
                ? Text(
                    (user.displayName.isEmpty ? user.email : user.displayName)
                        .characters
                        .first
                        .toUpperCase())
                : null,
          ),
          title: Row(children: [
            Flexible(
              child: Text(
                  user.displayName.isEmpty ? 'Sin nombre' : user.displayName),
            ),
            if (user.isOwnerEmail) ...[
              const SizedBox(width: 8),
              const Chip(label: Text('Propietario')),
            ],
          ]),
          subtitle: Text(
            '${user.email}\n${_roleLabel(user.role)} · '
            '${user.isActive ? 'Activo' : 'Desactivado'} · '
            '${user.permissions.values.where((p) => p != PermissionLevel.none).length} módulos',
          ),
          isThreeLine: true,
          trailing: IconButton(
            tooltip: user.isOwnerEmail ? 'Cuenta protegida' : 'Editar',
            onPressed: user.isOwnerEmail ? null : onEdit,
            icon: Icon(
                user.isOwnerEmail ? Icons.lock_outline : Icons.edit_outlined),
          ),
        ),
      );
}

class _UserEditor extends StatefulWidget {
  const _UserEditor({
    required this.actor,
    required this.original,
    required this.repository,
  });
  final AppUser actor;
  final AppUser original;
  final UserRepository repository;

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  late final TextEditingController _name;
  late UserRole _role;
  late bool _active;
  late Map<String, PermissionLevel> _permissions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.original.displayName);
    _role = widget.original.role;
    _active = widget.original.isActive;
    _permissions = {
      for (final module in AppModules.all)
        module: widget.original.permissions[module] ?? PermissionLevel.none,
    };
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar cambios'),
        content: Text('¿Aplicar los cambios a ${widget.original.email}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateUser(
        actor: widget.actor,
        original: widget.original,
        updated: widget.original.copyWith(
          displayName: _name.text,
          role: _role,
          isActive: _active,
          permissions: _permissions,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario actualizado correctamente.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Usuario y permisos'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    DropdownMenuItem(
                        value: UserRole.admin, child: Text('Administrador')),
                    DropdownMenuItem(
                        value: UserRole.member, child: Text('Miembro')),
                  ],
                  onChanged: (value) => setState(() => _role = value ?? _role),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usuario activo'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
                const Divider(),
                ...AppModules.all.map((module) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DropdownButtonFormField<PermissionLevel>(
                        initialValue: _permissions[module],
                        decoration: InputDecoration(
                            labelText: AppModules.labels[module]),
                        items: const [
                          DropdownMenuItem(
                              value: PermissionLevel.none,
                              child: Text('Sin acceso')),
                          DropdownMenuItem(
                              value: PermissionLevel.view, child: Text('Ver')),
                          DropdownMenuItem(
                              value: PermissionLevel.manage,
                              child: Text('Gestionar')),
                        ],
                        onChanged: (value) => setState(() {
                          _permissions[module] = value ?? PermissionLevel.none;
                        }),
                      ),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar cambios'),
          ),
        ],
      );
}

String _roleLabel(UserRole role) => switch (role) {
      UserRole.owner => 'Propietario',
      UserRole.admin => 'Administrador',
      UserRole.member => 'Miembro',
    };

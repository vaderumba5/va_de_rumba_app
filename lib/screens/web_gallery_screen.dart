import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/web_gallery_service.dart';

class WebGalleryScreen extends StatefulWidget {
  const WebGalleryScreen({super.key});

  @override
  State<WebGalleryScreen> createState() => _WebGalleryScreenState();
}

class _WebGalleryScreenState extends State<WebGalleryScreen> {
  final _service = WebGalleryService();
  final _picker = ImagePicker();
  late final Stream<WebGallerySnapshot> _photos = _service.watch();
  int? _busySlot;
  bool _adding = false;
  String? _deletingId;

  bool get _locked => _busySlot != null || _adding || _deletingId != null;

  Future<void> _add() async {
    if (_locked) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );
      if (file == null || !mounted) return;
      var description = '';
      final alt = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Añadir fotografía a la web'),
          content: SizedBox(
            width: 420,
            child: TextFormField(
              onChanged: (value) => description = value,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Descripción accesible',
                helperText: 'Describe brevemente lo que se ve en la foto.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, description),
              child: const Text('Publicar foto'),
            ),
          ],
        ),
      );
      if (alt == null || !mounted) return;
      setState(() => _adding = true);
      await _service.add(file, alt);
      _message('Fotografía añadida a la galería de la web.');
    } catch (error) {
      _message('No se pudo añadir la foto: $error');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeAdded(AddedWebGalleryPhoto photo) async {
    if (_locked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar fotografía'),
        content: const Text('¿Quitar esta foto de la galería pública?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar foto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingId = photo.id);
    try {
      await _service.removeAdded(photo.id);
      _message('Fotografía retirada de la web.');
    } catch (error) {
      _message('No se pudo quitar la foto: $error');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<void> _replace(int slot, WebGalleryPhoto? current) async {
    if (_locked) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );
      if (file == null || !mounted) return;
      var description = current?.alt ?? 'Va de Rumba en directo';
      final alt = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Fotografía $slot'),
          content: SizedBox(
            width: 420,
            child: TextFormField(
              initialValue: description,
              onChanged: (value) => description = value,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Descripción accesible',
                helperText: 'Describe brevemente lo que se ve en la foto.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, description),
              child: const Text('Publicar foto'),
            ),
          ],
        ),
      );
      if (alt == null || !mounted) return;
      setState(() => _busySlot = slot);
      await _service.replace(slot, file, alt);
      _message('Fotografía $slot actualizada en la web.');
    } catch (error) {
      _message('No se pudo actualizar la foto: $error');
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  Future<void> _restore(int slot) async {
    if (_locked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar fotografía'),
        content: Text('¿Volver a la foto original de la posición $slot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busySlot = slot);
    try {
      await _service.restoreDefault(slot);
      _message('Fotografía original restaurada.');
    } catch (error) {
      _message('No se pudo restaurar la foto: $error');
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WebGallerySnapshot>(
      stream: _photos,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(
            'No se pudo cargar la galería: ${snapshot.error}',
          ));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final gallery = snapshot.data!;
        final photos = gallery.slots;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 64) / 2
                : constraints.maxWidth - 48;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Las fotos añadidas aparecen al final de «Fuera y dentro '
                    'del escenario» sin sustituir las 14 originales.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _locked ? null : _add,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Añadir fotografía'),
                  ),
                  if (_adding) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (gallery.added.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Fotos añadidas',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final photo in gallery.added)
                          SizedBox(
                            width: width,
                            child: _AddedPhotoCard(
                              photo: photo,
                              busy: _deletingId == photo.id,
                              locked: _locked,
                              onRemove: () => _removeAdded(photo),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Fotos originales',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (var slot = 1;
                          slot <= WebGalleryService.defaultImages.length;
                          slot++)
                        SizedBox(
                          width: width,
                          child: _PhotoCard(
                            slot: slot,
                            photo: photos[slot],
                            busy: _busySlot == slot,
                            locked: _locked,
                            onReplace: () => _replace(slot, photos[slot]),
                            onRestore: () => _restore(slot),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.slot,
    required this.photo,
    required this.busy,
    required this.locked,
    required this.onReplace,
    required this.onRestore,
  });

  final int slot;
  final WebGalleryPhoto? photo;
  final bool busy;
  final bool locked;
  final VoidCallback onReplace;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final url = photo?.imageUrl ?? WebGalleryService.defaultImages[slot - 1];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: url.startsWith('assets/')
                ? Image.asset(url, fit: BoxFit.cover)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fotografía $slot',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(photo == null ? 'Imagen actual de la web' : 'Personalizada'),
                const SizedBox(height: 14),
                if (busy) const LinearProgressIndicator(),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: locked ? null : onReplace,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Cambiar foto'),
                    ),
                    if (photo != null)
                      TextButton.icon(
                        onPressed: locked ? null : onRestore,
                        icon: const Icon(Icons.restore),
                        label: const Text('Restaurar original'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddedPhotoCard extends StatelessWidget {
  const _AddedPhotoCard({
    required this.photo,
    required this.busy,
    required this.locked,
    required this.onRemove,
  });

  final AddedWebGalleryPhoto photo;
  final bool busy;
  final bool locked;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                photo.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(photo.alt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (busy) const LinearProgressIndicator(),
                  TextButton.icon(
                    onPressed: locked ? null : onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar de la web'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

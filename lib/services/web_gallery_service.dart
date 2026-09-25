import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class WebGalleryPhoto {
  const WebGalleryPhoto({
    required this.slot,
    required this.imageUrl,
    required this.storagePath,
    required this.alt,
  });

  final int slot;
  final String imageUrl;
  final String storagePath;
  final String alt;

  factory WebGalleryPhoto.fromMap(int slot, Map<String, dynamic> data) =>
      WebGalleryPhoto(
        slot: slot,
        imageUrl: data['imageUrl'] as String? ?? '',
        storagePath: data['storagePath'] as String? ?? '',
        alt: data['alt'] as String? ?? '',
      );
}

class AddedWebGalleryPhoto {
  const AddedWebGalleryPhoto({
    required this.id,
    required this.imageUrl,
    required this.storagePath,
    required this.alt,
    required this.createdAt,
  });

  final String id;
  final String imageUrl;
  final String storagePath;
  final String alt;
  final Timestamp? createdAt;

  factory AddedWebGalleryPhoto.fromMap(String id, Map<String, dynamic> data) =>
      AddedWebGalleryPhoto(
        id: id,
        imageUrl: data['imageUrl'] as String? ?? '',
        storagePath: data['storagePath'] as String? ?? '',
        alt: data['alt'] as String? ?? '',
        createdAt: data['createdAt'] as Timestamp?,
      );
}

class WebGallerySnapshot {
  const WebGallerySnapshot(this.slots, this.added);

  final Map<int, WebGalleryPhoto> slots;
  final List<AddedWebGalleryPhoto> added;
}

class WebGalleryService {
  static const defaultImages = <String>[
    'assets/images/galeria-grupo-playa.jpeg',
    'assets/images/galeria-pintando-cartel.jpeg',
    'assets/images/galeria-cartel.jpeg',
    'assets/images/galeria-brindis.jpeg',
    'assets/images/galeria-playa.jpeg',
    'assets/images/concierto-escenario.jpeg',
    'assets/images/concierto-final.jpeg',
    'assets/images/galeria-publico-boda.jpeg',
    'assets/images/galeria-baile-boda.jpeg',
    'assets/images/galeria-banda-boda.jpeg',
    'assets/images/galeria-voz-boda.jpeg',
    'assets/images/galeria-guitarra-boda.jpeg',
    'assets/images/galeria-momento-boda.jpeg',
    'assets/images/galeria-grupo-coche.jpeg',
  ];

  final _photos = FirebaseFirestore.instance.collection('public_gallery');

  Stream<WebGallerySnapshot> watch() => _photos.snapshots().map((snapshot) {
        final photos = <int, WebGalleryPhoto>{};
        final added = <AddedWebGalleryPhoto>[];
        for (final doc in snapshot.docs) {
          final slot = doc.id.startsWith('slot-')
              ? int.tryParse(doc.id.substring(5))
              : null;
          if (slot != null && slot >= 1 && slot <= defaultImages.length) {
            photos[slot] = WebGalleryPhoto.fromMap(slot, doc.data());
          } else if (doc.id.startsWith('photo-')) {
            added.add(AddedWebGalleryPhoto.fromMap(doc.id, doc.data()));
          }
        }
        added.sort((a, b) {
          final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
          final order = aTime.compareTo(bTime);
          return order != 0 ? order : a.id.compareTo(b.id);
        });
        return WebGallerySnapshot(photos, added);
      });

  Future<void> add(XFile file, String alt) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Tu sesión ha caducado.');
    final extension = file.name.split('.').last.toLowerCase();
    const types = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'png': 'image/png', 'webp': 'image/webp'};
    final contentType = types[extension];
    if (contentType == null) {
      throw StateError('Selecciona una imagen JPG, PNG o WebP.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.lengthInBytes >= 10 * 1024 * 1024) {
      throw StateError('La imagen debe ocupar menos de 10 MB.');
    }
    final id = 'photo-${const Uuid().v4()}';
    final path = 'public_gallery/$id/${const Uuid().v4()}.$extension';
    final storage = FirebaseStorage.instance.ref(path);
    var uploaded = false;
    try {
      await storage.putData(bytes, SettableMetadata(contentType: contentType));
      uploaded = true;
      final url = await storage.getDownloadURL();
      await _photos.doc(id).set({
        'imageUrl': url,
        'storagePath': path,
        'alt': alt.trim().isEmpty ? 'Va de Rumba' : alt.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    } catch (_) {
      if (uploaded) {
        try { await storage.delete(); } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> removeAdded(String id) async {
    if (!RegExp(r'^photo-[a-f0-9-]{36}$').hasMatch(id)) {
      throw StateError('Fotografía no válida.');
    }
    final doc = _photos.doc(id);
    final old = await doc.get();
    if (!old.exists) return;
    final path = old.data()?['storagePath'] as String?;
    await doc.delete();
    if (path != null && path.startsWith('public_gallery/$id/')) {
      try { await FirebaseStorage.instance.ref(path).delete(); } catch (_) {}
    }
  }

  Future<void> replace(int slot, XFile file, String alt) async {
    if (slot < 1 || slot > defaultImages.length) {
      throw StateError('Posición no válida.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Tu sesión ha caducado.');
    final extension = file.name.split('.').last.toLowerCase();
    const types = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'png': 'image/png', 'webp': 'image/webp'};
    final contentType = types[extension];
    if (contentType == null) {
      throw StateError('Selecciona una imagen JPG, PNG o WebP.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.lengthInBytes > 10 * 1024 * 1024) {
      throw StateError('La imagen debe ocupar menos de 10 MB.');
    }
    final doc = _photos.doc('slot-$slot');
    final old = await doc.get();
    final oldPath = old.data()?['storagePath'] as String?;
    final newPath = 'public_gallery/slot-$slot/${const Uuid().v4()}.$extension';
    final storage = FirebaseStorage.instance.ref(newPath);
    var uploaded = false;
    try {
      await storage.putData(bytes, SettableMetadata(contentType: contentType));
      uploaded = true;
      final url = await storage.getDownloadURL();
      await doc.set({
        'imageUrl': url,
        'storagePath': newPath,
        'alt': alt.trim().isEmpty ? 'Va de Rumba' : alt.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    } catch (_) {
      if (uploaded) {
        try { await storage.delete(); } catch (_) {}
      }
      rethrow;
    }
    if (oldPath != null && oldPath.startsWith('public_gallery/slot-$slot/')) {
      try { await FirebaseStorage.instance.ref(oldPath).delete(); } catch (_) {}
    }
  }

  Future<void> restoreDefault(int slot) async {
    if (slot < 1 || slot > defaultImages.length) {
      throw StateError('Posición no válida.');
    }
    final doc = _photos.doc('slot-$slot');
    final old = await doc.get();
    final oldPath = old.data()?['storagePath'] as String?;
    await doc.delete();
    if (oldPath != null && oldPath.startsWith('public_gallery/slot-$slot/')) {
      try { await FirebaseStorage.instance.ref(oldPath).delete(); } catch (_) {}
    }
  }
}

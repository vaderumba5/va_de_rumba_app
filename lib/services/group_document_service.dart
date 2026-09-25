import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

import '../models/group_document.dart';

class GroupDocumentService {
  final _docs = FirebaseFirestore.instance.collection('group_documents');
  Stream<List<GroupDocument>> watch() =>
      _docs.orderBy('createdAt', descending: true).snapshots().map((s) =>
          s.docs.map((d) => GroupDocument.fromMap(d.id, d.data())).toList());

  Future<PlatformFile?> pickPdf() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    return r?.files.isEmpty ?? true ? null : r!.files.single;
  }

  Future<void> upload(
      {required PlatformFile file,
      required String title,
      required String category,
      required String description}) async {
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No se ha podido leer el archivo seleccionado.');
    }
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      throw StateError('Solo se pueden subir archivos PDF.');
    }
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      throw StateError('El archivo no puede superar los 20 MB.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado');
    final ref = _docs.doc();
    final safe = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storage =
        FirebaseStorage.instance.ref('group_documents/${ref.id}/$safe');
    var uploaded = false;

    try {
      await storage.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {'documentId': ref.id, 'uploadedBy': user.uid},
        ),
      );
      uploaded = true;
      final url = await storage.getDownloadURL();
      await ref.set({
        'title': title.trim(),
        'category': category,
        'description': description.trim(),
        'originalFileName': file.name,
        'storagePath': storage.fullPath,
        'downloadUrl': url,
        'sizeBytes': bytes.lengthInBytes,
        'mimeType': 'application/pdf',
        'uploadedBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (uploaded) {
        try {
          await storage.delete();
        } catch (_) {
          // La carga original es el error relevante; evitar ocultarlo.
        }
      }
      rethrow;
    }
  }

  Future<void> delete(GroupDocument document) async {
    if (document.storagePath.isNotEmpty) {
      await FirebaseStorage.instance.ref(document.storagePath).delete();
    }
    await _docs.doc(document.id).delete();
  }

  String errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Tu sesión ha caducado. Inicia sesión de nuevo.';
        case 'unauthorized':
        case 'permission-denied':
          return 'No tienes permiso para subir documentos.';
        case 'quota-exceeded':
          return 'No queda espacio disponible para nuevos documentos.';
        case 'canceled':
          return 'La subida del documento se ha cancelado.';
        case 'network-request-failed':
          return 'No se ha podido conectar. Comprueba tu conexión.';
        default:
          return 'No se ha podido subir el documento (${error.code}).';
      }
    }
    return 'No se ha podido subir el documento.';
  }
}

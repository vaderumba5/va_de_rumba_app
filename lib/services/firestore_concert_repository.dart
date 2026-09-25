import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/concert.dart';

class FirestoreConcertRepository {
  final CollectionReference<Map<String, dynamic>> _concerts =
      FirebaseFirestore.instance.collection('concerts');
  final CollectionReference<Map<String, dynamic>> _publicConcerts =
      FirebaseFirestore.instance.collection('public_concerts');

  final _uuid = const Uuid();

  Future<List<Concert>> getAll() async {
    final snapshot = await _concerts.get();

    debugPrint(
        '[FirestoreConcertRepository] Documentos: ${snapshot.docs.length}');

    for (final doc in snapshot.docs) {
      debugPrint('[FirestoreConcertRepository] ${doc.data()}');
    }

    return snapshot.docs.map((doc) => Concert.fromJson(doc.data())).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> saveAll(List<Concert> concerts) async {
    final batch = FirebaseFirestore.instance.batch();

    // Elimina los documentos existentes
    final existing = await _concerts.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    // Vuelve a crearlos
    for (final concert in concerts) {
      batch.set(_concerts.doc(concert.id), concert.toJson());
    }

    await batch.commit();
  }

  String newId() => _uuid.v4();

  Stream<List<Concert>> streamConcerts() {
    return _concerts.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Concert.fromJson(doc.data())).toList();
    });
  }

  Future<void> createConcert(Concert concert) async {
    debugPrint(
        '[FirestoreConcertRepository] createConcert iniciado: ${concert.id}');
    if (concert.isPublishedOnWeb) {
      await _writePublication(concert, action: 'concert_published');
    } else {
      await _concerts.doc(concert.id).set({
        ...concert.toJson(),
        'isPublishedOnWeb': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    debugPrint(
        '[FirestoreConcertRepository] createConcert completado: ${concert.id}');
  }

  Future<void> updateConcert(
    Concert concert, {
    bool updatePublicConcert = false,
  }) async {
    debugPrint(
        '[FirestoreConcertRepository] updateConcert iniciado: ${concert.id}');
    if (!concert.isPublishedOnWeb && concert.publishedAt != null) {
      await unpublishConcert(concert);
    } else if (!concert.isPublishedOnWeb) {
      await _concerts.doc(concert.id).set({
        ...concert.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (concert.publishedAt == null || updatePublicConcert) {
      await _writePublication(
        concert,
        action: concert.publishedAt == null
            ? 'concert_published'
            : 'public_concert_updated',
      );
    } else {
      await _concerts.doc(concert.id).set({
        ...concert.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    debugPrint(
        '[FirestoreConcertRepository] updateConcert completado: ${concert.id}');
  }

  Future<void> deleteConcert(String id) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_concerts.doc(id));
    batch.delete(_publicConcerts.doc(id));
    await batch.commit();
  }

  Future<void> publishConcert(Concert concert) =>
      _writePublication(concert, action: 'concert_published');

  Future<void> unpublishConcert(Concert concert) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No hay ningún usuario autenticado.');
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_concerts.doc(concert.id), {
      ...concert.toJson(),
      'isPublishedOnWeb': false,
      'publishedAt': null,
      'publicUpdatedAt': null,
      'publishedBy': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(_publicConcerts.doc(concert.id));
    batch.set(FirebaseFirestore.instance.collection('audit_logs').doc(), {
      'action': 'concert_unpublished',
      'targetId': concert.id,
      'performedBy': user.uid,
      'performedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _writePublication(
    Concert concert, {
    required String action,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No hay ningún usuario autenticado.');
    final publishedAt = concert.publishedAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(concert.publishedAt!);
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_concerts.doc(concert.id), {
      ...concert.toJson(),
      'isPublishedOnWeb': true,
      'publishedAt': publishedAt,
      'publicUpdatedAt': FieldValue.serverTimestamp(),
      'publishedBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _publicConcerts.doc(concert.id),
      concert.toPublicConcertData(publishedAtValue: publishedAt),
    );
    batch.set(FirebaseFirestore.instance.collection('audit_logs').doc(), {
      'action': action,
      'targetId': concert.id,
      'performedBy': user.uid,
      'performedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

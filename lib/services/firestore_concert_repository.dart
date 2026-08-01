import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/concert.dart';

class FirestoreConcertRepository {
  final CollectionReference<Map<String, dynamic>> _concerts =
      FirebaseFirestore.instance.collection('concerts');

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
    await _concerts.doc(concert.id).set(concert.toJson());
    debugPrint(
        '[FirestoreConcertRepository] createConcert completado: ${concert.id}');
  }

  Future<void> updateConcert(Concert concert) async {
    debugPrint(
        '[FirestoreConcertRepository] updateConcert iniciado: ${concert.id}');
    await _concerts.doc(concert.id).update(concert.toJson());
    debugPrint(
        '[FirestoreConcertRepository] updateConcert completado: ${concert.id}');
  }

  Future<void> deleteConcert(String id) async {
    await _concerts.doc(id).delete();
  }
}

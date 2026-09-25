import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/concert.dart';
import '../models/concert_import_data.dart';

class ConcertImportResult {
  const ConcertImportResult({
    required this.reviewed,
    required this.imported,
    required this.duplicates,
    required this.errors,
  });

  final int reviewed;
  final int imported;
  final int duplicates;
  final int errors;
}

class ConcertImportAuthenticationException implements Exception {}

class ConcertImportService {
  ConcertImportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const assetPath = 'assets/imports/conciertos_2026_import.json';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _concerts =>
      _firestore.collection('concerts');

  Future<ConcertImportResult> import2026Concerts() async {
    final user = _auth.currentUser;
    if (user == null) throw ConcertImportAuthenticationException();

    final entries = await _loadEntries();
    final validEntries = <ConcertImportData>[];
    var invalidEntries = 0;
    for (final rawEntry in entries) {
      try {
        if (rawEntry is! Map) {
          throw const FormatException('El registro no es un objeto JSON.');
        }
        validEntries.add(
          ConcertImportData.fromJson(Map<String, dynamic>.from(rawEntry)),
        );
      } catch (error, stackTrace) {
        invalidEntries++;
        debugPrint('Registro de importación omitido: $error\n$stackTrace');
      }
    }

    final existingSnapshot = await _concerts.get();
    final existingKeys = existingSnapshot.docs
        .map((document) => document.data()['importKey'] as String?)
        .whereType<String>()
        .toSet();
    final keysInFile = <String>{};
    final newEntries = <ConcertImportData>[];
    var duplicates = 0;

    for (final entry in validEntries) {
      if (!keysInFile.add(entry.importKey) ||
          existingKeys.contains(entry.importKey)) {
        duplicates++;
      } else {
        newEntries.add(entry);
      }
    }

    var imported = 0;
    if (newEntries.isNotEmpty) {
      final batch = _firestore.batch();
      for (final entry in newEntries) {
        try {
          final concert = _toConcert(entry, _concerts.doc().id);
          batch.set(_concerts.doc(concert.id), {
            ...concert.toJson(),
            'importKey': entry.importKey,
            'importSource': entry.source,
            'importedAt': FieldValue.serverTimestamp(),
            'importedBy': user.uid,
          });
          imported++;
        } catch (error, stackTrace) {
          invalidEntries++;
          debugPrint(
              'Concierto ${entry.importKey} omitido: $error\n$stackTrace');
        }
      }
      await batch.commit();
    }

    return ConcertImportResult(
      reviewed: entries.length,
      imported: imported,
      duplicates: duplicates,
      errors: invalidEntries,
    );
  }

  Future<List<dynamic>> _loadEntries() async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        throw const FormatException('El JSON no es una lista.');
      }
      return List<dynamic>.from(decoded, growable: false);
    } catch (error, stackTrace) {
      debugPrint(
          'No se ha podido leer el archivo de conciertos: $error\n$stackTrace');
      throw const FormatException(
          'No se ha podido leer el archivo de conciertos.');
    }
  }

  Concert _toConcert(ConcertImportData entry, String id) {
    final date = DateTime.tryParse(entry.date);
    if (date == null) {
      throw FormatException('Fecha inválida: ${entry.date}');
    }
    final time = _normalizedTime(entry.time);
    final notes = <String>[
      if (entry.notes != null) entry.notes!,
      if (entry.endTime != null)
        'Hora de finalización: ${_normalizedTime(entry.endTime)}.',
      if (entry.deposit != null)
        'Reserva: ${entry.deposit!.toStringAsFixed(2)} €.',
    ];

    return Concert(
      id: id,
      date: DateTime(date.year, date.month, date.day),
      time: time,
      place: entry.title,
      price: entry.budget,
      comments: notes.join('\n'),
      status: _statusFor(entry.status),
      contactPerson: entry.contactPerson ?? '',
      contactPhone: entry.phone ?? '',
      address: entry.location ?? '',
      venueName: entry.title,
    );
  }

  String _normalizedTime(String? value) {
    if (value == null || value.trim().isEmpty) return '12:00';
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) throw FormatException('Hora inválida: $value');
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw FormatException('Hora inválida: $value');
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  ConcertStatus _statusFor(String status) =>
      status.trim().toLowerCase() == 'cancelled'
          ? ConcertStatus.cancelled
          : ConcertStatus.confirmed;
}

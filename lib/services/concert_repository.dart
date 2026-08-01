import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/concert.dart';

class ConcertRepository {
  static const _key = 'va_de_rumba_concerts';
  final _uuid = const Uuid();

  Future<List<Concert>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Concert.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveAll(List<Concert> concerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(concerts.map((e) => e.toJson()).toList()));
  }

  String newId() => _uuid.v4();
}

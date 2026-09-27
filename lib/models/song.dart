import 'package:cloud_firestore/cloud_firestore.dart';

String normalizeSongSearch(String value) {
  const accents = 'áàäâéèëêíìïîóòöôúùüûñç';
  const plain = 'aaaaeeeeiiiioooouuuunc';
  var result = value.trim().toLowerCase();
  for (var index = 0; index < accents.length; index++) {
    result = result.replaceAll(accents[index], plain[index]);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

class SongModel {
  const SongModel({
    required this.id,
    required this.title,
    required this.normalizedTitle,
    this.artist = '',
    this.key = '',
    this.chords = const [],
    this.capo = 0,
    this.tempo,
    this.durationSeconds,
    this.notes = '',
    this.category = 'Repertorio habitual',
    this.status = 'active',
    required this.defaultOrder,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
  });

  final String id;
  final String title;
  final String normalizedTitle;
  final String artist;
  final String key;
  final List<String> chords;
  final int capo;
  final int? tempo;
  final int? durationSeconds;
  final String notes;
  final String category;
  final String status;
  final int defaultOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  bool get isArchived => status == 'archived';

  factory SongModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final title = data['title'] as String? ?? '';
    return SongModel(
      id: document.id,
      title: title,
      normalizedTitle:
          data['normalizedTitle'] as String? ?? normalizeSongSearch(title),
      artist: data['artist'] as String? ?? '',
      key: data['key'] as String? ?? '',
      chords: List<String>.from(data['chords'] as List? ?? const []),
      capo: (data['capo'] as num?)?.toInt() ?? 0,
      tempo: (data['tempo'] as num?)?.toInt(),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
      notes: data['notes'] as String? ?? '',
      category: data['category'] as String? ?? 'Repertorio habitual',
      status: data['status'] as String? ?? 'active',
      defaultOrder: (data['defaultOrder'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, Object?> toFirestore({required bool creating}) => {
        'title': title.trim(),
        'normalizedTitle': normalizeSongSearch(title),
        'artist': artist.trim(),
        'key': key.trim(),
        'chords': chords,
        'capo': capo,
        'tempo': tempo,
        'durationSeconds': durationSeconds,
        'notes': notes.trim(),
        'category': category.trim(),
        'status': status,
        'defaultOrder': defaultOrder,
        if (creating) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (creating) 'createdBy': createdBy,
      };

  SongModel copyWith({
    String? title,
    String? artist,
    String? key,
    List<String>? chords,
    int? capo,
    int? tempo,
    int? durationSeconds,
    String? notes,
    String? category,
    String? status,
    int? defaultOrder,
  }) =>
      SongModel(
        id: id,
        title: title ?? this.title,
        normalizedTitle: normalizeSongSearch(title ?? this.title),
        artist: artist ?? this.artist,
        key: key ?? this.key,
        chords: List.unmodifiable(chords ?? this.chords),
        capo: capo ?? this.capo,
        tempo: tempo ?? this.tempo,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        notes: notes ?? this.notes,
        category: category ?? this.category,
        status: status ?? this.status,
        defaultOrder: defaultOrder ?? this.defaultOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
      );

  @override
  bool operator ==(Object other) =>
      other is SongModel &&
      id == other.id &&
      title == other.title &&
      artist == other.artist &&
      key == other.key &&
      chords.join('|') == other.chords.join('|') &&
      capo == other.capo &&
      tempo == other.tempo &&
      durationSeconds == other.durationSeconds &&
      notes == other.notes &&
      category == other.category &&
      status == other.status &&
      defaultOrder == other.defaultOrder;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        artist,
        key,
        chords.join('|'),
        capo,
        tempo,
        durationSeconds,
        notes,
        category,
        status,
        defaultOrder,
      );
}

import 'package:cloud_firestore/cloud_firestore.dart';

class SetlistItemModel {
  const SetlistItemModel({
    required this.type,
    this.songId,
    this.title,
    required this.order,
    this.customKey,
    this.customCapo,
    this.customNotes = '',
  });

  final String type;
  final String? songId;
  final String? title;
  final int order;
  final String? customKey;
  final int? customCapo;
  final String customNotes;

  bool get isSection => type == 'section';

  factory SetlistItemModel.fromMap(Map<String, dynamic> map) =>
      SetlistItemModel(
        type: map['type'] as String? ?? 'song',
        songId: map['songId'] as String?,
        title: map['title'] as String?,
        order: (map['order'] as num?)?.toInt() ?? 0,
        customKey: map['customKey'] as String?,
        customCapo: (map['customCapo'] as num?)?.toInt(),
        customNotes: map['customNotes'] as String? ?? '',
      );

  Map<String, Object?> toMap() => {
        'type': type,
        if (songId != null) 'songId': songId,
        if (title != null) 'title': title,
        'order': order,
        'customKey': customKey,
        'customCapo': customCapo,
        'customNotes': customNotes,
      };

  SetlistItemModel copyWith({
    int? order,
    String? customKey,
    int? customCapo,
    String? customNotes,
  }) =>
      SetlistItemModel(
        type: type,
        songId: songId,
        title: title,
        order: order ?? this.order,
        customKey: customKey ?? this.customKey,
        customCapo: customCapo ?? this.customCapo,
        customNotes: customNotes ?? this.customNotes,
      );
}

class SetlistModel {
  const SetlistModel({
    required this.id,
    required this.name,
    this.description = '',
    this.concertId,
    this.items = const [],
    this.estimatedDurationSeconds = 0,
    this.pauseBetweenSongsSeconds = 10,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
  });

  final String id;
  final String name;
  final String description;
  final String? concertId;
  final List<SetlistItemModel> items;
  final int estimatedDurationSeconds;
  final int pauseBetweenSongsSeconds;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  factory SetlistModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawItems = data['items'] ?? data['songs'];
    return SetlistModel(
      id: document.id,
      name: data['name'] as String? ?? 'Repertorio',
      description: data['description'] as String? ?? '',
      concertId: data['concertId'] as String?,
      items: (rawItems as List? ?? const [])
          .whereType<Map>()
          .map((item) =>
              SetlistItemModel.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      estimatedDurationSeconds:
          (data['estimatedDurationSeconds'] as num?)?.toInt() ?? 0,
      pauseBetweenSongsSeconds:
          (data['pauseBetweenSongsSeconds'] as num?)?.toInt() ?? 10,
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, Object?> toFirestore({required bool creating}) => {
        'name': name.trim(),
        'description': description.trim(),
        'concertId': concertId,
        'songIds': items
            .where((item) => !item.isSection && item.songId != null)
            .map((item) => item.songId)
            .toList(),
        'songs': items.map((item) => item.toMap()).toList(),
        'items': items.map((item) => item.toMap()).toList(),
        'estimatedDurationSeconds': estimatedDurationSeconds,
        'pauseBetweenSongsSeconds': pauseBetweenSongsSeconds,
        'status': status,
        if (creating) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (creating) 'createdBy': createdBy,
      };

  SetlistModel copyWith({
    String? id,
    String? name,
    String? description,
    String? concertId,
    List<SetlistItemModel>? items,
    int? estimatedDurationSeconds,
    int? pauseBetweenSongsSeconds,
    String? status,
  }) =>
      SetlistModel(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        concertId: concertId ?? this.concertId,
        items: List.unmodifiable(items ?? this.items),
        estimatedDurationSeconds:
            estimatedDurationSeconds ?? this.estimatedDurationSeconds,
        pauseBetweenSongsSeconds:
            pauseBetweenSongsSeconds ?? this.pauseBetweenSongsSeconds,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
      );
}

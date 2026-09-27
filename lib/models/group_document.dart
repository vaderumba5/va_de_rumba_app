import 'package:cloud_firestore/cloud_firestore.dart';

class GroupDocument {
  const GroupDocument(
      {required this.id,
      required this.title,
      required this.category,
      required this.description,
      required this.originalFileName,
      required this.storagePath,
      required this.downloadUrl,
      required this.sizeBytes,
      required this.mimeType,
      required this.uploadedBy,
      this.createdAt});
  final String id,
      title,
      category,
      description,
      originalFileName,
      storagePath,
      downloadUrl,
      mimeType,
      uploadedBy;
  final int sizeBytes;
  final DateTime? createdAt;
  factory GroupDocument.fromMap(String id, Map<String, dynamic> map) =>
      GroupDocument(
          id: id,
          title: map['title'] ?? '',
          category: map['category'] ?? 'Otros',
          description: map['description'] ?? '',
          originalFileName: map['originalFileName'] ?? '',
          storagePath: map['storagePath'] ?? '',
          downloadUrl: map['downloadUrl'] ?? '',
          sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
          mimeType: map['mimeType'] ?? 'application/pdf',
          uploadedBy: map['uploadedBy'] ?? '',
          createdAt: (map['createdAt'] as Timestamp?)?.toDate());
}

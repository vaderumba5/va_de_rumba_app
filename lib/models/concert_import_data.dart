class ConcertImportData {
  const ConcertImportData({
    required this.date,
    required this.title,
    required this.status,
    required this.source,
    required this.importKey,
    this.location,
    this.time,
    this.endTime,
    this.budget,
    this.deposit,
    this.contactPerson,
    this.phone,
    this.notes,
  });

  final String date;
  final String title;
  final String? location;
  final String? time;
  final String? endTime;
  final double? budget;
  final double? deposit;
  final String? contactPerson;
  final String? phone;
  final String? notes;
  final String status;
  final String source;
  final String importKey;

  factory ConcertImportData.fromJson(Map<String, dynamic> json) {
    final date = _requiredString(json, 'date');
    final title = _requiredString(json, 'title');
    final importKey = _requiredString(json, 'importKey');
    return ConcertImportData(
      date: date,
      title: title,
      status: _nullableString(json['status']) ?? 'confirmed',
      source: _nullableString(json['source']) ?? '',
      importKey: importKey,
      location: _nullableString(json['location']),
      time: _nullableString(json['time']),
      endTime: _nullableString(json['endTime']),
      budget: (json['budget'] as num?)?.toDouble(),
      deposit: (json['deposit'] as num?)?.toDouble(),
      contactPerson: _nullableString(json['contactPerson']),
      phone: _nullableString(json['phone']),
      notes: _nullableString(json['notes']),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = _nullableString(json[key]);
    if (value == null) throw FormatException('Falta el campo $key.');
    return value;
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

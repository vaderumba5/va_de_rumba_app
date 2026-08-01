enum ConcertStatus { pending, confirmed, cancelled }

class Concert {
  final String id;
  final DateTime date;
  final String time;
  final String place;
  final double? price;
  final String comments;
  final ConcertStatus status;

  const Concert({
    required this.id,
    required this.date,
    required this.time,
    required this.place,
    this.price,
    this.comments = '',
    this.status = ConcertStatus.pending,
  });

  Concert copyWith({
    DateTime? date,
    String? time,
    String? place,
    double? price,
    String? comments,
    ConcertStatus? status,
  }) => Concert(
    id: id,
    date: date ?? this.date,
    time: time ?? this.time,
    place: place ?? this.place,
    price: price ?? this.price,
    comments: comments ?? this.comments,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'time': time,
    'place': place,
    'price': price,
    'comments': comments,
    'status': status.name,
  };

  factory Concert.fromJson(Map<String, dynamic> j) => Concert(
    id: j['id'],
    date: DateTime.parse(j['date']),
    time: j['time'] ?? '',
    place: j['place'] ?? '',
    price: j['price'] == null ? null : (j['price'] as num).toDouble(),
    comments: j['comments'] ?? '',
    status: ConcertStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => ConcertStatus.pending,
    ),
  );
}

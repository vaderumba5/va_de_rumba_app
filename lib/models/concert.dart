import 'package:cloud_firestore/cloud_firestore.dart';

enum ConcertStatus { pending, confirmed, reserved, cancelled }

class Concert {
  final String id;
  final DateTime date;
  final String time;
  final String place;
  final double? price;
  final String comments;
  final ConcertStatus status;
  final String contactPerson;
  final String contactPhone;
  final String address;
  final String mapsUrl;
  final String venueName;
  final String googlePlaceId;
  final double? latitude;
  final double? longitude;
  final String municipality;
  final String province;
  final String organizer;
  final String contactEmail;
  final String setupTime;
  final String parkingNotes;
  final String setlistId;
  final bool isPublishedOnWeb;
  final DateTime? publishedAt;
  final DateTime? publicUpdatedAt;
  final DateTime? updatedAt;
  final String? publishedBy;
  final String publicTitle;
  final String publicTime;
  final String publicVenue;
  final String city;
  final String publicLocation;
  final String ticketType;
  final String ticketUrl;
  final String ticketLabel;
  final String publicDescription;
  final String posterUrl;
  final bool featured;
  final String publicStatus;

  const Concert({
    required this.id,
    required this.date,
    required this.time,
    required this.place,
    this.price,
    this.comments = '',
    this.status = ConcertStatus.pending,
    this.contactPerson = '',
    this.contactPhone = '',
    this.address = '',
    this.mapsUrl = '',
    this.venueName = '',
    this.googlePlaceId = '',
    this.latitude,
    this.longitude,
    this.municipality = '',
    this.province = '',
    this.organizer = '',
    this.contactEmail = '',
    this.setupTime = '',
    this.parkingNotes = '',
    this.setlistId = '',
    this.isPublishedOnWeb = false,
    this.publishedAt,
    this.publicUpdatedAt,
    this.updatedAt,
    this.publishedBy,
    this.publicTitle = '',
    this.publicTime = '',
    this.publicVenue = '',
    this.city = '',
    this.publicLocation = '',
    this.ticketType = 'unavailable',
    this.ticketUrl = '',
    this.ticketLabel = '',
    this.publicDescription = '',
    this.posterUrl = '',
    this.featured = false,
    this.publicStatus = 'scheduled',
  });

  Concert copyWith({
    DateTime? date,
    String? time,
    String? place,
    double? price,
    String? comments,
    ConcertStatus? status,
    String? contactPerson,
    String? contactPhone,
    String? address,
    String? mapsUrl,
    String? venueName,
    String? googlePlaceId,
    double? latitude,
    double? longitude,
    String? municipality,
    String? province,
    String? organizer,
    String? contactEmail,
    String? setupTime,
    String? parkingNotes,
    String? setlistId,
    bool? isPublishedOnWeb,
    DateTime? publishedAt,
    DateTime? publicUpdatedAt,
    DateTime? updatedAt,
    String? publishedBy,
    String? publicTitle,
    String? publicTime,
    String? publicVenue,
    String? city,
    String? publicLocation,
    String? ticketType,
    String? ticketUrl,
    String? ticketLabel,
    String? publicDescription,
    String? posterUrl,
    bool? featured,
    String? publicStatus,
  }) =>
      Concert(
        id: id,
        date: date ?? this.date,
        time: time ?? this.time,
        place: place ?? this.place,
        price: price ?? this.price,
        comments: comments ?? this.comments,
        status: status ?? this.status,
        contactPerson: contactPerson ?? this.contactPerson,
        contactPhone: contactPhone ?? this.contactPhone,
        address: address ?? this.address,
        mapsUrl: mapsUrl ?? this.mapsUrl,
        venueName: venueName ?? this.venueName,
        googlePlaceId: googlePlaceId ?? this.googlePlaceId,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        municipality: municipality ?? this.municipality,
        province: province ?? this.province,
        organizer: organizer ?? this.organizer,
        contactEmail: contactEmail ?? this.contactEmail,
        setupTime: setupTime ?? this.setupTime,
        parkingNotes: parkingNotes ?? this.parkingNotes,
        setlistId: setlistId ?? this.setlistId,
        isPublishedOnWeb: isPublishedOnWeb ?? this.isPublishedOnWeb,
        publishedAt: publishedAt ?? this.publishedAt,
        publicUpdatedAt: publicUpdatedAt ?? this.publicUpdatedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        publishedBy: publishedBy ?? this.publishedBy,
        publicTitle: publicTitle ?? this.publicTitle,
        publicTime: publicTime ?? this.publicTime,
        publicVenue: publicVenue ?? this.publicVenue,
        city: city ?? this.city,
        publicLocation: publicLocation ?? this.publicLocation,
        ticketType: ticketType ?? this.ticketType,
        ticketUrl: ticketUrl ?? this.ticketUrl,
        ticketLabel: ticketLabel ?? this.ticketLabel,
        publicDescription: publicDescription ?? this.publicDescription,
        posterUrl: posterUrl ?? this.posterUrl,
        featured: featured ?? this.featured,
        publicStatus: publicStatus ?? this.publicStatus,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'time': time,
        'place': place,
        'price': price,
        'comments': comments,
        'status': status.name,
        'contactPerson': contactPerson,
        'contactPhone': contactPhone,
        'address': address,
        'mapsUrl': mapsUrl,
        'venueName': venueName,
        'googlePlaceId': googlePlaceId,
        'latitude': latitude,
        'longitude': longitude,
        'municipality': municipality,
        'province': province,
        'organizer': organizer,
        'contactEmail': contactEmail,
        'setupTime': setupTime,
        'parkingNotes': parkingNotes,
        'setlistId': setlistId,
        'isPublishedOnWeb': isPublishedOnWeb,
        'publishedAt':
            publishedAt == null ? null : Timestamp.fromDate(publishedAt!),
        'publicUpdatedAt': publicUpdatedAt == null
            ? null
            : Timestamp.fromDate(publicUpdatedAt!),
        'publishedBy': publishedBy,
        'publicTitle': publicTitle,
        'publicTime': publicTime,
        'publicVenue': publicVenue,
        'city': city,
        'publicLocation': publicLocation,
        'ticketType': ticketType,
        'ticketUrl': ticketUrl,
        'ticketLabel': ticketLabel,
        'publicDescription': publicDescription,
        'posterUrl': posterUrl,
        'featured': featured,
        'publicStatus': publicStatus,
      };

  Map<String, Object?> toPublicConcertData({
    Object? publishedAtValue,
  }) =>
      {
        'concertId': id,
        'title': publicTitle.trim().isEmpty ? place : publicTitle.trim(),
        'date': Timestamp.fromDate(date),
        'time': publicTime.trim().isEmpty ? time : publicTime.trim(),
        'venue': publicVenue.trim().isEmpty ? place : publicVenue.trim(),
        'city': city.trim().isEmpty ? municipality : city.trim(),
        'province': province.trim(),
        'publicLocation': publicLocation.trim(),
        'mapsUrl': mapsUrl.trim(),
        'ticketType': ticketType,
        'ticketUrl': ticketUrl.trim(),
        'ticketLabel': ticketLabel.trim(),
        'publicDescription': publicDescription.trim(),
        'posterUrl': posterUrl.trim(),
        'featured': featured,
        'status': publicStatus,
        'publishedAt': publishedAtValue ??
            (publishedAt == null
                ? FieldValue.serverTimestamp()
                : Timestamp.fromDate(publishedAt!)),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Concert.fromJson(Map<String, dynamic> j) => Concert(
        id: j['id'],
        date: _dateFromValue(j['date']) ?? DateTime.now(),
        time: j['time'] ?? '',
        place: j['place'] ?? '',
        price: j['price'] == null ? null : (j['price'] as num).toDouble(),
        comments: j['comments'] ?? '',
        status: ConcertStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => ConcertStatus.pending,
        ),
        contactPerson: j['contactPerson'] ?? '',
        contactPhone: j['contactPhone'] ?? '',
        address: j['address'] ?? '',
        mapsUrl: j['mapsUrl'] ?? '',
        venueName: j['venueName'] ?? '',
        googlePlaceId: j['googlePlaceId'] ?? '',
        latitude:
            j['latitude'] == null ? null : (j['latitude'] as num).toDouble(),
        longitude:
            j['longitude'] == null ? null : (j['longitude'] as num).toDouble(),
        municipality: j['municipality'] ?? '',
        province: j['province'] ?? '',
        organizer: j['organizer'] ?? '',
        contactEmail: j['contactEmail'] ?? '',
        setupTime: j['setupTime'] ?? '',
        parkingNotes: j['parkingNotes'] ?? '',
        setlistId: j['setlistId'] ?? j['repertoireId'] ?? '',
        isPublishedOnWeb: j['isPublishedOnWeb'] as bool? ?? false,
        publishedAt: _dateFromValue(j['publishedAt']),
        publicUpdatedAt: _dateFromValue(j['publicUpdatedAt']),
        updatedAt: _dateFromValue(j['updatedAt']),
        publishedBy: j['publishedBy'] as String?,
        publicTitle: j['publicTitle'] as String? ?? '',
        publicTime: j['publicTime'] as String? ?? '',
        publicVenue: j['publicVenue'] as String? ?? '',
        city: j['city'] as String? ?? '',
        publicLocation: j['publicLocation'] as String? ?? '',
        ticketType: j['ticketType'] as String? ?? 'unavailable',
        ticketUrl: j['ticketUrl'] as String? ?? '',
        ticketLabel: j['ticketLabel'] as String? ?? '',
        publicDescription: j['publicDescription'] as String? ?? '',
        posterUrl: j['posterUrl'] as String? ?? '',
        featured: j['featured'] as bool? ?? false,
        publicStatus: j['publicStatus'] as String? ?? 'scheduled',
      );

  bool get hasUnpublishedChanges =>
      isPublishedOnWeb &&
      updatedAt != null &&
      (publicUpdatedAt == null || updatedAt!.isAfter(publicUpdatedAt!));

  bool get hasLocation =>
      mapsUrl.trim().isNotEmpty ||
      googlePlaceId.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      (latitude != null && longitude != null);
  bool get hasContact =>
      contactPerson.trim().isNotEmpty || contactPhone.trim().isNotEmpty;
}

DateTime? _dateFromValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

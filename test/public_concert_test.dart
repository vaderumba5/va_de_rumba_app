import 'package:flutter_test/flutter_test.dart';
import 'package:va_de_rumba/models/concert.dart';

void main() {
  test('un concierto nuevo no se publica por defecto', () {
    final concert = Concert(
      id: 'concert-1',
      date: DateTime(2026, 8, 14),
      time: '23:30',
      place: 'Urbanización Omet',
    );
    expect(concert.isPublishedOnWeb, isFalse);
  });

  test('el mapa público no contiene datos privados', () {
    final concert = Concert(
      id: 'concert-1',
      date: DateTime(2026, 8, 14),
      time: '23:30',
      place: 'Urbanización Omet',
      price: 1200,
      comments: 'Nota interna',
      contactPerson: 'Contacto privado',
      contactPhone: '600000000',
      contactEmail: 'privado@example.com',
      publicTitle: 'Va de Rumba en Picassent',
      publicVenue: 'Urbanización Omet',
      city: 'Picassent',
      ticketType: 'free',
    );
    final data = concert.toPublicConcertData();

    expect(data['title'], 'Va de Rumba en Picassent');
    expect(data['city'], 'Picassent');
    expect(data['ticketType'], 'free');
    expect(data.containsKey('price'), isFalse);
    expect(data.containsKey('comments'), isFalse);
    expect(data.containsKey('contactPerson'), isFalse);
    expect(data.containsKey('contactPhone'), isFalse);
    expect(data.containsKey('contactEmail'), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:va_de_rumba/core/fund_concert_metrics.dart';
import 'package:va_de_rumba/models/concert.dart';

Concert concert({
  required String id,
  required double? price,
  ConcertStatus status = ConcertStatus.confirmed,
  int year = 2026,
  int month = 8,
  double fundContribution = 50,
  double associatedExpenses = 0,
  int? splitMemberCount,
}) =>
    Concert(
      id: id,
      date: DateTime(year, month, 1),
      time: '20:00',
      place: 'Prueba',
      price: price,
      status: status,
      fundContribution: fundContribution,
      associatedExpenses: associatedExpenses,
      splitMemberCount: splitMemberCount,
    );

void main() {
  test('suma una vez cada concierto válido con precio', () {
    final concerts = [
      concert(id: 'a', price: 500),
      concert(id: 'b', price: 600),
      concert(id: 'c', price: 700),
    ];
    expect(concertIncomeTotal(concerts), 1800);
  });

  test('excluye cancelados, importes vacíos y no positivos', () {
    final concerts = [
      concert(id: 'ok', price: 500),
      concert(id: 'cancelled', price: 900, status: ConcertStatus.cancelled),
      concert(id: 'empty', price: null),
      concert(id: 'zero', price: 0),
    ];
    expect(concertIncomeTotal(concerts), 500);
  });

  test('recalcula periodos y desglose anual desde los conciertos', () {
    final concerts = [
      concert(id: 'a', price: 500, month: 8),
      concert(id: 'b', price: 600, month: 7),
      concert(id: 'c', price: 700, year: 2025),
    ];
    expect(concertIncomeForPeriod(concerts, year: 2026, month: 8), 500);
    expect(concertIncomeForPeriod(concerts, year: 2026), 1100);
    expect(concertIncomeByYear(concerts), {2026: 1100, 2025: 700});
  });

  test('reparte 500 menos 50 entre cinco integrantes', () {
    final metrics = calculateConcertDistribution(
      concert(id: 'a', price: 500),
      defaultMemberCount: 5,
    )!;
    expect(metrics.fundContribution, 50);
    expect(metrics.distributable, 450);
    expect(metrics.perMember, 90);
  });

  test('descuenta gastos asociados antes del reparto', () {
    final metrics = calculateConcertDistribution(
      concert(id: 'a', price: 500, associatedExpenses: 100),
      defaultMemberCount: 5,
    )!;
    expect(metrics.distributable, 350);
    expect(metrics.perMember, 70);
  });

  test('no calcula un reparto sin caché', () {
    expect(
      calculateConcertDistribution(
        concert(id: 'a', price: null),
        defaultMemberCount: 5,
      ),
      isNull,
    );
  });

  test('un reparto histórico conserva su número de integrantes', () {
    final metrics = calculateConcertDistribution(
      concert(id: 'a', price: 500, splitMemberCount: 4),
      defaultMemberCount: 6,
    )!;
    expect(metrics.memberCount, 4);
    expect(metrics.perMember, 112.5);
  });
}

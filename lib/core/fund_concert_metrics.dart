import '../models/concert.dart';

class ConcertDistributionMetrics {
  const ConcertDistributionMetrics({
    required this.cache,
    required this.fundContribution,
    required this.associatedExpenses,
    required this.memberCount,
    required this.distributable,
    required this.perMember,
  });

  final double cache;
  final double fundContribution;
  final double associatedExpenses;
  final int memberCount;
  final double distributable;
  final double perMember;
}

ConcertDistributionMetrics? calculateConcertDistribution(
  Concert concert, {
  required int defaultMemberCount,
}) {
  final cache = concert.price;
  if (cache == null ||
      cache <= 0 ||
      concert.status == ConcertStatus.cancelled) {
    return null;
  }
  final memberCount = concert.splitMemberCount ?? defaultMemberCount;
  if (memberCount <= 0) return null;
  final contribution = concert.fundContribution.clamp(0, cache).toDouble();
  final expenses = concert.associatedExpenses.clamp(0, cache).toDouble();
  final distributable =
      (cache - contribution - expenses).clamp(0, double.infinity).toDouble();
  return ConcertDistributionMetrics(
    cache: cache,
    fundContribution: contribution,
    associatedExpenses: expenses,
    memberCount: memberCount,
    distributable: distributable,
    perMember: distributable / memberCount,
  );
}

double distributionTotalForPeriod(
  Iterable<Concert> concerts, {
  required int defaultMemberCount,
  required int year,
  int? month,
}) =>
    concerts
        .where((concert) =>
            concert.date.year == year &&
            (month == null || concert.date.month == month))
        .map((concert) => calculateConcertDistribution(
              concert,
              defaultMemberCount: defaultMemberCount,
            ))
        .whereType<ConcertDistributionMetrics>()
        .fold(0, (sum, metrics) => sum + metrics.distributable);

bool isConcertIncomeCountable(Concert concert) =>
    concert.status != ConcertStatus.cancelled &&
    concert.price != null &&
    concert.price! > 0;

double concertIncomeTotal(Iterable<Concert> concerts) => concerts
    .where(isConcertIncomeCountable)
    .fold<double>(0, (total, concert) => total + concert.price!);

double concertIncomeForPeriod(
  Iterable<Concert> concerts, {
  required int year,
  int? month,
}) =>
    concertIncomeTotal(concerts.where((concert) =>
        concert.date.year == year &&
        (month == null || concert.date.month == month)));

Map<int, double> concertIncomeByYear(Iterable<Concert> concerts) {
  final totals = <int, double>{};
  for (final concert in concerts.where(isConcertIncomeCountable)) {
    totals.update(
      concert.date.year,
      (value) => value + concert.price!,
      ifAbsent: () => concert.price!,
    );
  }
  return totals;
}

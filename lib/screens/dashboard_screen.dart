import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/concert.dart';
import '../services/firestore_concert_repository.dart';
import 'concert_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = FirestoreConcertRepository();
  late Future<List<Concert>> _concertsFuture;

  @override
  void initState() {
    super.initState();
    _concertsFuture = _repository.getAll();
  }

  Future<void> _editConcert(Concert concert) async {
    final updated = await Navigator.push<Concert>(
      context,
      MaterialPageRoute(
        builder: (_) => ConcertFormScreen(
          initialDate: concert.date,
          concert: concert,
          repository: _repository,
        ),
      ),
    );
    if (updated != null) {
      await _repository.updateConcert(updated);
      if (mounted) setState(() => _concertsFuture = _repository.getAll());
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Concert>>(
        future: _concertsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DashboardMessage(
              icon: Icons.cloud_off_rounded,
              title: 'No se han podido cargar los conciertos',
              detail: 'Comprueba la conexión e inténtalo de nuevo.',
              onRetry: () =>
                  setState(() => _concertsFuture = _repository.getAll()),
            );
          }
          return _DashboardContent(
            concerts: snapshot.data ?? const [],
            onEditConcert: _editConcert,
          );
        },
      );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent(
      {required this.concerts, required this.onEditConcert});

  final List<Concert> concerts;
  final ValueChanged<Concert> onEditConcert;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureConcerts = concerts
        .where((concert) => !concert.date.isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final monthConcerts = concerts
        .where((concert) =>
            concert.date.year == now.year && concert.date.month == now.month)
        .toList();
    final income = monthConcerts.fold<double>(
        0, (total, concert) => total + (concert.price ?? 0));
    final pending = concerts
        .where((concert) => concert.status == ConcertStatus.pending)
        .length;
    final nextConcert = futureConcerts.isEmpty ? null : futureConcerts.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1000;
        return SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(desktop ? 28 : 18, 12, desktop ? 28 : 18, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1680),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen general',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7)),
                    const SizedBox(height: 2),
                    const Text('La actividad de Va de Rumba en tiempo real.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF777482))),
                    const SizedBox(height: 12),
                    _KpiGrid(
                        nextConcert: nextConcert,
                        monthlyConcerts: monthConcerts.length,
                        income: income,
                        pending: pending),
                    const SizedBox(height: 14),
                    _NextConcertCard(
                        concert: nextConcert, onEdit: onEditConcert),
                    const SizedBox(height: 18),
                    const Text('Próximos conciertos',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.3)),
                    const SizedBox(height: 9),
                    if (futureConcerts.isEmpty)
                      const _EmptyUpcoming()
                    else
                      _UpcomingList(
                          concerts: futureConcerts.take(5).toList(),
                          onEdit: onEditConcert),
                  ]),
            ),
          ),
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid(
      {required this.nextConcert,
      required this.monthlyConcerts,
      required this.income,
      required this.pending});
  final Concert? nextConcert;
  final int monthlyConcerts;
  final double income;
  final int pending;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1150
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        final cardHeight = columns == 1 ? 142.0 : 164.0;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cardWidth / cardHeight,
          children: [
            _MetricCard(
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF6255E7),
                label: 'PRÓXIMO CONCIERTO',
                value: nextConcert == null
                    ? '—'
                    : DateFormat('d MMM', 'es_ES').format(nextConcert!.date),
                detail: nextConcert?.place ?? 'Sin actuaciones futuras',
                accent: const Color(0xFFEAE8FF)),
            _MetricCard(
                icon: Icons.graphic_eq_rounded,
                iconColor: const Color(0xFF008D75),
                label: 'CONCIERTOS ESTE MES',
                value: '$monthlyConcerts',
                detail: DateFormat('MMMM', 'es_ES').format(DateTime.now()),
                accent: const Color(0xFFDDF7F1)),
            _MetricCard(
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFFB66A00),
                label: 'INGRESOS PREVISTOS',
                value: NumberFormat.currency(
                        locale: 'es_ES', symbol: '€', decimalDigits: 0)
                    .format(income),
                detail: 'Previsión del mes',
                accent: const Color(0xFFFFF1D9)),
            _MetricCard(
                icon: Icons.task_alt_rounded,
                iconColor: const Color(0xFFDA5365),
                label: 'PENDIENTES',
                value: '$pending',
                detail: pending == 1
                    ? 'Concierto pendiente'
                    : 'Conciertos pendientes',
                accent: const Color(0xFFFFE8EC)),
          ],
        );
      });
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      required this.detail,
      required this.accent});
  final IconData icon;
  final Color iconColor;
  final Color accent;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAE9F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A262235),
                  blurRadius: 12,
                  offset: Offset(0, 5))
            ]),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: accent, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 18)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: Color(0xFF292632))),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .75,
                        color: Color(0xFF85818E))),
                const SizedBox(height: 3),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF777482))),
              ]),
            ]),
      );
}

class _NextConcertCard extends StatelessWidget {
  const _NextConcertCard({required this.concert, required this.onEdit});
  final Concert? concert;
  final ValueChanged<Concert> onEdit;

  @override
  Widget build(BuildContext context) {
    if (concert == null) return const _EmptyUpcoming(featured: true);
    final date = concert!.date;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF29253E), Color(0xFF1D1B2B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x20211F33), blurRadius: 18, offset: Offset(0, 7))
          ]),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final details =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PRÓXIMO CONCIERTO',
              style: TextStyle(
                  color: Color(0xFFAAA4CF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(height: 5),
          Text(concert!.place,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 13, runSpacing: 5, children: [
            _Detail(icon: Icons.schedule_rounded, label: concert!.time),
            _Detail(icon: Icons.location_on_outlined, label: concert!.place),
            _Detail(
                icon: Icons.payments_outlined,
                label: concert!.price == null
                    ? 'Precio pendiente'
                    : NumberFormat.currency(
                            locale: 'es_ES', symbol: '€', decimalDigits: 0)
                        .format(concert!.price)),
          ]),
        ]);
        final action = FilledButton.icon(
            onPressed: () => onEdit(concert!),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7064EB),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11)),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Ver concierto'));
        return wide
            ? Row(children: [
                _DateBlock(date: date, compact: true),
                const SizedBox(width: 16),
                Expanded(child: details),
                _StatusChip(status: concert!.status, dark: true),
                const SizedBox(width: 12),
                action
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _DateBlock(date: date, compact: true),
                const SizedBox(height: 12),
                _StatusChip(status: concert!.status, dark: true),
                const SizedBox(height: 10),
                details,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: action)
              ]);
      }),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.concerts, required this.onEdit});
  final List<Concert> concerts;
  final ValueChanged<Concert> onEdit;

  @override
  Widget build(BuildContext context) => Column(
      children: concerts
          .map((concert) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _UpcomingItem(concert: concert, onEdit: onEdit)))
          .toList());
}

class _UpcomingItem extends StatelessWidget {
  const _UpcomingItem({required this.concert, required this.onEdit});
  final Concert concert;
  final ValueChanged<Concert> onEdit;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => onEdit(concert),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFEAE9F0))),
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final info = Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(concert.place,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF302D38))),
                    const SizedBox(height: 3),
                    Text(
                        '${concert.time} · ${concert.price == null ? 'Precio pendiente' : NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0).format(concert.price)}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF777482)))
                  ]));
              return wide
                  ? Row(children: [
                      _DateBlock(date: concert.date, small: true),
                      const SizedBox(width: 10),
                      info,
                      _StatusChip(status: concert.status)
                    ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Row(children: [
                            _DateBlock(date: concert.date, small: true),
                            const SizedBox(width: 10),
                            info
                          ]),
                          const SizedBox(height: 7),
                          _StatusChip(status: concert.status)
                        ]);
            }),
          ),
        ),
      );
}

class _DateBlock extends StatelessWidget {
  const _DateBlock(
      {required this.date, this.small = false, this.compact = false});
  final DateTime date;
  final bool small;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
        width: small ? 44 : (compact ? 58 : 74),
        padding: EdgeInsets.symmetric(vertical: small ? 5 : (compact ? 7 : 10)),
        decoration: BoxDecoration(
            color: const Color(0xFF3B365A),
            borderRadius: BorderRadius.circular(small ? 10 : 12)),
        child: Column(children: [
          Text('${date.day}',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: small ? 17 : (compact ? 23 : 30),
                  height: 1,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: small ? 2 : 3),
          Text(DateFormat('MMM', 'es_ES').format(date).toUpperCase(),
              style: TextStyle(
                  color: const Color(0xFFC4BFE5),
                  fontSize: small ? 8 : 9,
                  fontWeight: FontWeight.w800))
        ]),
      );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFFAFA7FF), size: 15),
        const SizedBox(width: 5),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFD0CCDC),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)))
      ]);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.dark = false});
  final ConcertStatus status;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConcertStatus.pending => ('Pendiente', const Color(0xFFE49B27)),
      ConcertStatus.confirmed => ('Confirmado', const Color(0xFF32B881)),
      ConcertStatus.cancelled => ('Cancelado', const Color(0xFFE05A68))
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: dark ? .18 : .12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: dark ? color.withValues(alpha: .95) : color)));
  }
}

class _EmptyUpcoming extends StatelessWidget {
  const _EmptyUpcoming({this.featured = false});
  final bool featured;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
            color: featured ? const Color(0xFF29253E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:
                featured ? null : Border.all(color: const Color(0xFFEAE9F0))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_available_outlined,
              size: 36,
              color:
                  featured ? const Color(0xFFAFA7FF) : const Color(0xFF8E87D8)),
          const SizedBox(height: 10),
          Text('No hay próximos conciertos',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: featured ? Colors.white : const Color(0xFF413D48))),
          const SizedBox(height: 5),
          Text('Cuando se programe uno aparecerá aquí.',
              style: TextStyle(
                  fontSize: 13,
                  color: featured
                      ? const Color(0xFFC1BDCE)
                      : const Color(0xFF777482)))
        ]),
      );
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage(
      {required this.icon,
      required this.title,
      required this.detail,
      required this.onRetry});
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: const Color(0xFF8E87D8)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(detail, style: const TextStyle(color: Color(0xFF777482))),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'))
      ]));
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/concert.dart';
import '../services/firestore_concert_repository.dart';
import '../services/group_fund_service.dart';
import '../utils/concert_actions.dart';
import '../core/app_theme.dart';
import '../core/fund_constants.dart';
import 'concert_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onOpenFund});

  final VoidCallback? onOpenFund;

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
    if (!mounted || updated == null) return;
    await _repository.updateConcert(updated);
    if (mounted) setState(() => _concertsFuture = _repository.getAll());
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
            onOpenFund: widget.onOpenFund,
          );
        },
      );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent(
      {required this.concerts, required this.onEditConcert, this.onOpenFund});
  final List<Concert> concerts;
  final ValueChanged<Concert> onEditConcert;
  final VoidCallback? onOpenFund;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureConcerts = concerts
        .where((concert) => !concert.date.isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final nextConcert = futureConcerts.isEmpty ? null : futureConcerts.first;
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 980;
      final padding =
          EdgeInsets.fromLTRB(desktop ? 28 : 18, 12, desktop ? 28 : 18, 24);
      final primary =
          _NextConcertCard(concert: nextConcert, onEdit: onEditConcert);
      return SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1680),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Centro de trabajo',
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6)),
              const SizedBox(height: 2),
              const Text('Agenda, avisos y previsión del mes.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777482))),
              const SizedBox(height: 12),
              primary,
              const SizedBox(height: 12),
              _GroupFundCard(onTap: onOpenFund),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(
                    child: Text('Próximos conciertos',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800))),
                Text('${futureConcerts.length} en agenda',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF777482)))
              ]),
              const SizedBox(height: 8),
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
    });
  }
}

class _NextConcertCard extends StatelessWidget {
  const _NextConcertCard({required this.concert, required this.onEdit});
  final Concert? concert;
  final ValueChanged<Concert> onEdit;

  @override
  Widget build(BuildContext context) {
    if (concert == null) return const _EmptyUpcoming(featured: true);
    final price = concert!.price == null
        ? 'Precio pendiente'
        : NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0)
            .format(concert!.price);
    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
          color: AppColors.topBarBackground,
          borderRadius: BorderRadius.circular(18)),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 530;
        final date = _DateBadge(date: concert!.date);
        final details =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PRÓXIMO CONCIERTO',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .9)),
          const SizedBox(height: 5),
          Text(concert!.place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Wrap(spacing: 13, runSpacing: 4, children: [
            _Detail(icon: Icons.schedule_rounded, label: concert!.time),
            _Detail(icon: Icons.payments_outlined, label: price),
            if (concert!.contactPerson.isNotEmpty)
              _Detail(
                  icon: Icons.person_outline_rounded,
                  label: concert!.contactPerson),
            if (concert!.contactPhone.isNotEmpty)
              _Detail(icon: Icons.phone_outlined, label: concert!.contactPhone),
            if (concert!.address.isNotEmpty)
              _Detail(
                  icon: Icons.location_on_outlined, label: concert!.address),
          ]),
        ]);
        final action = FilledButton.icon(
            onPressed: () =>
                ConcertActions.openConcertLocation(context, concert!.address),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10)),
            icon: const Icon(Icons.directions_outlined, size: 17),
            label: const Text('Cómo llegar'));
        return wide
            ? Row(children: [
                date,
                const SizedBox(width: 14),
                Expanded(child: details),
                _StatusChip(status: concert!.status),
                if (concert!.hasLocation)
                  IconButton(
                      tooltip: 'Abrir mapa',
                      onPressed: () =>
                          ConcertActions.openLocation(context, concert!),
                      icon: const Icon(Icons.map_outlined,
                          color: AppColors.iconPrimary)),
                const SizedBox(width: 10),
                action
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  date,
                  const SizedBox(width: 12),
                  Expanded(child: details)
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _StatusChip(status: concert!.status),
                  const Spacer(),
                  if (concert!.hasLocation)
                    IconButton(
                        tooltip: 'Abrir mapa',
                        onPressed: () =>
                            ConcertActions.openLocation(context, concert!),
                        icon: const Icon(Icons.map_outlined,
                            color: AppColors.iconPrimary)),
                  action
                ])
              ]);
      }),
    );
  }
}

class _GroupFundCard extends StatelessWidget {
  const _GroupFundCard({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final service = GroupFundService();
    final now = DateTime.now();
    return StreamBuilder<double>(
      stream: service.watchAvailableAmount(),
      builder: (context, balanceSnapshot) => StreamBuilder(
        stream: service.watchRoomPayment(now.year, now.month),
        builder: (context, paymentSnapshot) {
          final paid = paymentSnapshot.data != null;
          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.savings_outlined,
                      color: AppColors.iconPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fondo disponible',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          paid
                              ? 'Local de ${DateFormat.MMMM('es_ES').format(now).toLowerCase()} pagado'
                              : 'Local de ${DateFormat.MMMM('es_ES').format(now).toLowerCase()} pendiente: ${NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2).format(rehearsalRoomMonthlyPayment)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'es_ES',
                      symbol: '€',
                      decimalDigits: 2,
                    ).format(balanceSnapshot.data ?? 0),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
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
              decoration: _whitePanelDecoration(radius: 13),
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 590;
                final info = Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(concert.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${concert.time} · ${_price(concert.price)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF777482)))
                    ]));
                return wide
                    ? Row(children: [
                        _DateBadge(date: concert.date),
                        const SizedBox(width: 10),
                        info,
                        _StatusChip(status: concert.status)
                      ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(children: [
                              _DateBadge(date: concert.date),
                              const SizedBox(width: 10),
                              info
                            ]),
                            const SizedBox(height: 7),
                            _StatusChip(status: concert.status)
                          ]);
              }))));
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) => Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text('${date.day}',
            style: const TextStyle(
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 3),
        Text(DateFormat('MMM', 'es_ES').format(date).toUpperCase(),
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary))
      ]));
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
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFD0CCDC),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)))
      ]);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ConcertStatus status;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConcertStatus.pending => ('Pendiente', const Color(0xFFE49B27)),
      ConcertStatus.confirmed => ('Confirmado', const Color(0xFF32B881)),
      ConcertStatus.reserved => ('Reservado', const Color(0xFF4389C9)),
      ConcertStatus.cancelled => ('Cancelado', const Color(0xFFE05A68))
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)));
  }
}

class _EmptyUpcoming extends StatelessWidget {
  const _EmptyUpcoming({this.featured = false});
  final bool featured;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: featured ? const Color(0xFF29253E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: featured ? null : Border.all(color: const Color(0xFFEAE9F0))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.event_available_outlined,
            size: 30,
            color:
                featured ? const Color(0xFFAFA7FF) : const Color(0xFF8E87D8)),
        const SizedBox(height: 8),
        Text('No hay próximos conciertos',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: featured ? Colors.white : const Color(0xFF413D48))),
        const SizedBox(height: 4),
        Text('Cuando se programe uno aparecerá aquí.',
            style: TextStyle(
                fontSize: 12,
                color: featured
                    ? const Color(0xFFC1BDCE)
                    : const Color(0xFF777482)))
      ]));
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

BoxDecoration _whitePanelDecoration({double radius = 15}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFEAE9F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08262335), blurRadius: 12, offset: Offset(0, 4))
        ]);
String _price(double? value) => value == null
    ? 'Precio pendiente'
    : NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0)
        .format(value);

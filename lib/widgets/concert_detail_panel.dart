import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/concert.dart';
import '../utils/concert_actions.dart';
import 'concert_status_chip.dart';

class ConcertDetailPanel extends StatelessWidget {
  const ConcertDetailPanel({
    super.key,
    required this.concert,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
  });

  final Concert? concert;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final item = concert;
    if (item == null) {
      return const _EmptyDetail();
    }
    final phone = item.contactPhone.trim();
    return Material(
      color: Colors.white,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
          child: Row(children: [
            IconButton(
                tooltip: 'Cerrar detalle',
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back)),
            const SizedBox(width: 4),
            const Expanded(
                child: Text('Concierto',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            IconButton(
                tooltip: 'Editar concierto',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                tooltip: 'Eliminar concierto',
                onPressed: onDelete,
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFA13F48))),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          DateFormat('EEEE', 'es_ES')
                              .format(item.date)
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF666666),
                              letterSpacing: .8)),
                      const SizedBox(height: 6),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${item.date.day}',
                                style: const TextStyle(
                                    fontSize: 52,
                                    height: .9,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 10),
                            Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                    DateFormat('MMMM y', 'es_ES')
                                        .format(item.date),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF666666)))),
                          ]),
                      const SizedBox(height: 18),
                      Text(
                          item.venueName.isNotEmpty
                              ? item.venueName
                              : item.place,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      if (item.municipality.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                                [item.municipality, item.province]
                                    .where((v) => v.isNotEmpty)
                                    .join(', '),
                                style:
                                    const TextStyle(color: Color(0xFF666666)))),
                      const SizedBox(height: 12),
                      ConcertStatusChip(status: item.status),
                      const SizedBox(height: 22),
                      _Info(
                          icon: Icons.schedule_outlined,
                          label: 'Hora',
                          value: item.time),
                      _Info(
                          icon: Icons.location_on_outlined,
                          label: 'Dirección',
                          value: item.address),
                      _Info(
                          icon: Icons.euro_outlined,
                          label: 'Caché',
                          value: item.price == null
                              ? 'Pendiente'
                              : NumberFormat.currency(
                                      locale: 'es_ES',
                                      symbol: '€',
                                      decimalDigits: 0)
                                  .format(item.price)),
                      _Info(
                          icon: Icons.person_outline,
                          label: 'Contacto',
                          value: item.contactPerson),
                      _Info(
                          icon: Icons.business_outlined,
                          label: 'Organización',
                          value: item.organizer),
                      _Info(
                          icon: Icons.phone_outlined,
                          label: 'Teléfono',
                          value: phone),
                      _Info(
                          icon: Icons.notes_outlined,
                          label: 'Notas',
                          value: item.comments,
                          multiline: true),
                      _Info(
                          icon: Icons.construction_outlined,
                          label: 'Montaje',
                          value: item.setupTime),
                      _Info(
                          icon: Icons.local_parking_outlined,
                          label: 'Parking',
                          value: item.parkingNotes,
                          multiline: true),
                    ]))),
        const Divider(height: 1),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: item.hasLocation
                          ? () => ConcertActions.openLocation(context, item)
                          : null,
                      child: const Text('CÓMO LLEGAR'))),
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton(
                      onPressed: phone.isEmpty
                          ? null
                          : () => ConcertActions.callPhone(context, phone),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF111111)),
                      child: const Text('LLAMAR'))),
            ])),
      ]),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(
      {required this.icon,
      required this.label,
      required this.value,
      this.multiline = false});
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;
  @override
  Widget build(BuildContext context) => value.trim().isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
              crossAxisAlignment: multiline
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: const Color(0xFF666666)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(label.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF888888))),
                      const SizedBox(height: 3),
                      Text(value, style: const TextStyle(fontSize: 13))
                    ]))
              ]));
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.touch_app_outlined, size: 32, color: Color(0xFF888888)),
            SizedBox(height: 12),
            Text('Selecciona un concierto para ver sus detalles',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666)))
          ])));
}

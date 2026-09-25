import 'package:flutter/material.dart';

import '../models/concert.dart';
import '../core/app_theme.dart';

class ConcertStatusChip extends StatelessWidget {
  const ConcertStatusChip({super.key, required this.status});

  final ConcertStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      ConcertStatus.confirmed => (
          'Confirmado',
          AppColors.successText,
          AppColors.successBackground,
        ),
      ConcertStatus.pending => (
          'Pendiente',
          AppColors.warningText,
          AppColors.warningBackground,
        ),
      ConcertStatus.reserved => (
          'Reservado',
          AppColors.infoText,
          AppColors.infoBackground,
        ),
      ConcertStatus.cancelled => (
          'Cancelado',
          AppColors.dangerText,
          AppColors.dangerBackground,
        ),
    };
    return Semantics(
      label: 'Estado: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: foreground, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

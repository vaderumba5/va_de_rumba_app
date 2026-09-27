import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';

/// The fund balance and monthly activity, separate from concert estimates.
class FundOverview extends StatelessWidget {
  const FundOverview({
    super.key,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.monthlyFee,
    required this.previousMonthBalance,
    required this.concertContributions,
    required this.individualEstimate,
    required this.hidden,
    required this.onToggleAmounts,
    required this.month,
  });

  final double balance;
  final double income;
  final double expenses;
  final double monthlyFee;
  final double previousMonthBalance;
  final double concertContributions;
  final double individualEstimate;
  final bool hidden;
  final VoidCallback onToggleAmounts;
  final DateTime month;

  static const _ink = Color(0xFF183D35);
  static const _muted = Color(0xFFC4D9D0);

  String _amount(double value, {bool signed = false}) {
    if (hidden) return '•••• €';
    final formatted = NumberFormat.currency(
      locale: 'es_ES',
      symbol: '€',
      decimalDigits: 2,
    ).format(signed ? value.abs() : value);
    return signed ? '${value < 0 ? '−' : '+'}$formatted' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final net = income - expenses;
    final coverage =
        monthlyFee > 0 ? (balance / monthlyFee).floor().clamp(0, 9999) : 0;
    final balanceCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, Color(0xFF102922)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: _muted, size: 20),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Saldo disponible',
                  style: TextStyle(color: _muted, fontSize: 14))),
          IconButton(
            onPressed: onToggleAmounts,
            tooltip: hidden
                ? 'Mostrar importes del resumen'
                : 'Ocultar importes del resumen',
            icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _muted,
                size: 20),
          ),
        ]),
        const SizedBox(height: 12),
        Text(_amount(balance),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2)),
        const SizedBox(height: 8),
        const Text('El dinero común de Va de Rumba',
            style: TextStyle(color: _muted, fontSize: 13)),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Color(0xFF416057))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.music_note_outlined, color: _muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    hidden
                        ? 'Previsión del local oculta'
                        : monthlyFee <= 0
                            ? 'Cuota del local sin configurar'
                            : '$coverage ${coverage == 1 ? 'cuota cubierta' : 'cuotas cubiertas'} del local',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${_amount(monthlyFee)} / mes · Sin contar otros gastos',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ])),
        ]),
      ]),
    );
    final activity =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text('Este mes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(DateFormat('MMMM yyyy', 'es_ES').format(month),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 320 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.6
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final metric in [
            (
              label: 'Ingresos',
              value: income,
              icon: Icons.south_west_rounded,
              color: AppColors.successText,
              note: 'Registrados en el fondo'
            ),
            (
              label: 'Gastos',
              value: expenses,
              icon: Icons.north_east_rounded,
              color: AppColors.dangerText,
              note: 'Registrados en el fondo'
            ),
            (
              label: 'Aportación de conciertos',
              value: concertContributions,
              icon: Icons.mic_none_rounded,
              color: AppColors.infoText,
              note: 'Previsión del mes'
            ),
            (
              label: 'Por integrante',
              value: individualEstimate,
              icon: Icons.people_outline,
              color: AppColors.textSecondary,
              note: 'Reparto estimado del mes'
            ),
          ])
            SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(
                          color: AppColors.border.withValues(alpha: .7)),
                      borderRadius: BorderRadius.circular(18)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(metric.label,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13))),
                              const SizedBox(width: 6),
                              Icon(metric.icon, color: metric.color, size: 18),
                            ]),
                        const SizedBox(height: 12),
                        Text(_amount(metric.value),
                            style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.5)),
                        const SizedBox(height: 4),
                        Text(metric.note,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ]),
                )),
        ]);
      }),
      const SizedBox(height: 14),
      Text(
          'Balance del mes: ${_amount(net, signed: true)} · '
          '${_amount(net - previousMonthBalance, signed: true)} frente al mes anterior',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
    ]);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 840) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              balanceCard,
              const SizedBox(height: 24),
              activity,
            ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 4, child: balanceCard),
        const SizedBox(width: 24),
        Expanded(flex: 6, child: activity),
      ]);
    });
  }
}

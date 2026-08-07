import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/fund_constants.dart';
import '../models/rehearsal_room_payment.dart';
import '../services/group_fund_service.dart';
import '../models/app_permission.dart';
import '../providers/current_user_scope.dart';

enum _MovementFilter { all, income, rehearsalRoom, adjustments }

class FundScreen extends StatefulWidget {
  const FundScreen({super.key});

  @override
  State<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {
  final _service = GroupFundService();
  final _processingMonths = <String>{};
  var _selectedYear = DateTime.now().year;
  var _addingMoney = false;
  var _adjustingFund = false;
  var _filter = _MovementFilter.all;

  Future<void> _addMoney() async {
    if (_addingMoney) return;
    final request = await showDialog<_ManualIncomeRequest>(
      context: context,
      builder: (_) => const _ManualIncomeDialog(),
    );
    if (request == null || !mounted) return;

    setState(() => _addingMoney = true);
    try {
      await _service.addManualIncome(
        amount: request.amount,
        description: request.description,
        effectiveDate: request.effectiveDate,
      );
      if (mounted) _showMessage('Dinero añadido al Fondo.');
    } catch (error, stackTrace) {
      debugPrint('Error al añadir dinero al Fondo: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se ha podido actualizar el Fondo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _addingMoney = false);
    }
  }

  Future<void> _adjustFund(double currentBalance) async {
    if (_adjustingFund) return;
    final request = await showDialog<_FundAdjustmentRequest>(
      context: context,
      builder: (_) => _FundAdjustmentDialog(currentBalance: currentBalance),
    );
    if (request == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar ajuste'),
        content: const Text('¿Deseas ajustar el fondo del grupo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ajustar fondo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _adjustingFund = true);
    try {
      await _service.adjustFund(
        realBalance: request.realBalance,
        reason: request.reason,
      );
      if (mounted) _showMessage('Fondo ajustado correctamente.');
    } catch (error, stackTrace) {
      debugPrint('Error al ajustar el Fondo: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se ha podido ajustar el Fondo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _adjustingFund = false);
    }
  }

  Future<void> _payRoom(int year, int month) async {
    final key = '$year-$month';
    if (_processingMonths.contains(key)) return;
    setState(() => _processingMonths.add(key));
    try {
      await _service.payRehearsalRoom(year, month);
      if (mounted) _showMessage('Pago del local registrado.');
    } catch (error, stackTrace) {
      debugPrint('Error al pagar el local: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se ha podido registrar el pago del local.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _processingMonths.remove(key));
    }
  }

  Future<void> _undoRoomPayment(int year, int month) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deshacer pago'),
        content: Text(
          '¿Quieres deshacer el pago del local de ${_monthName(month).toLowerCase()} de $year?\n\nSe devolverán ${_currency(rehearsalRoomMonthlyPayment)} al Fondo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deshacer pago'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final key = '$year-$month';
    if (_processingMonths.contains(key)) return;
    setState(() => _processingMonths.add(key));
    try {
      await _service.undoRehearsalRoomPayment(year, month);
      if (mounted) _showMessage('Pago del local deshecho.');
    } catch (error, stackTrace) {
      debugPrint('Error al deshacer el pago del local: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se ha podido deshacer el pago.', error: true);
      }
    } finally {
      if (mounted) setState(() => _processingMonths.remove(key));
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.dangerText : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<double>(
        stream: _service.watchAvailableAmount(),
        builder: (context, balanceSnapshot) =>
            StreamBuilder<Map<int, RehearsalRoomPayment>>(
          stream: _service.watchRoomPayments(_selectedYear),
          builder: (context, paymentsSnapshot) => StreamBuilder<
                  List<FundMovement>>(
              stream: _service.watchMovements(),
              builder: (context, movementsSnapshot) {
                final movements =
                    movementsSnapshot.data ?? const <FundMovement>[];
                final filteredMovements = _filterMovements(movements);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    _BalanceCard(
                      balance: balanceSnapshot.data ?? 0,
                      busy: _addingMoney || _adjustingFund,
                      onAddMoney:
                          CurrentUserScope.authorization.canManageModule(
                        CurrentUserScope.of(context),
                        AppModules.fund,
                      )
                              ? _addMoney
                              : null,
                      onAdjust: CurrentUserScope.authorization.canManageModule(
                        CurrentUserScope.of(context),
                        AppModules.fund,
                      )
                          ? () => _adjustFund(balanceSnapshot.data ?? 0)
                          : null,
                    ),
                    const SizedBox(height: 22),
                    _RoomSection(
                      year: _selectedYear,
                      payments: paymentsSnapshot.data ?? const {},
                      processingMonths: _processingMonths,
                      onPreviousYear: () => setState(() => _selectedYear--),
                      onNextYear: () => setState(() => _selectedYear++),
                      onPay: CurrentUserScope.authorization.canManageModule(
                              CurrentUserScope.of(context), AppModules.fund)
                          ? (month) => _payRoom(_selectedYear, month)
                          : null,
                      onUndo: CurrentUserScope.authorization.canManageModule(
                              CurrentUserScope.of(context), AppModules.fund)
                          ? (month) => _undoRoomPayment(_selectedYear, month)
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _HistoryHeader(
                      filter: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(height: 8),
                    if (movementsSnapshot.hasError)
                      const _FundMessage(
                        icon: Icons.cloud_off_outlined,
                        message: 'No se han podido cargar los movimientos.',
                      )
                    else if (movementsSnapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filteredMovements.isEmpty)
                      const _FundMessage(
                        icon: Icons.receipt_long_outlined,
                        message: 'Todavía no hay movimientos en el Fondo.',
                      )
                    else
                      ...filteredMovements.map(_MovementTile.new),
                  ],
                );
              }),
        ),
      );

  List<FundMovement> _filterMovements(List<FundMovement> movements) {
    return switch (_filter) {
      _MovementFilter.all => movements,
      _MovementFilter.income => movements
          .where((movement) => movement.category == 'manual_income')
          .toList(),
      _MovementFilter.rehearsalRoom => movements
          .where((movement) => movement.category == 'rehearsal_room')
          .toList(),
      _MovementFilter.adjustments => movements
          .where((movement) => movement.category == 'adjustment')
          .toList(),
    };
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.busy,
    required this.onAddMoney,
    required this.onAdjust,
  });

  final double balance;
  final bool busy;
  final VoidCallback? onAddMoney;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 16,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fondo disponible',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(
                  _currency(balance),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onAdjust,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Ajustar fondo'),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onAddMoney,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(busy ? 'Guardando…' : 'Añadir dinero'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _RoomSection extends StatelessWidget {
  const _RoomSection({
    required this.year,
    required this.payments,
    required this.processingMonths,
    required this.onPreviousYear,
    required this.onNextYear,
    required this.onPay,
    required this.onUndo,
  });

  final int year;
  final Map<int, RehearsalRoomPayment> payments;
  final Set<String> processingMonths;
  final VoidCallback onPreviousYear;
  final VoidCallback onNextYear;
  final ValueChanged<int>? onPay;
  final ValueChanged<int>? onUndo;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Local',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Año anterior',
                onPressed: onPreviousYear,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$year',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(
                tooltip: 'Año siguiente',
                onPressed: onNextYear,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Pago mensual del local de ensayo: ${_currency(rehearsalRoomMonthlyPayment)}',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 3
                  : constraints.maxWidth >= 590
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  12,
                  (index) {
                    final month = index + 1;
                    final payment = payments[month];
                    final busy = processingMonths.contains('$year-$month');
                    return SizedBox(
                      width: width,
                      child: _MonthCard(
                        year: year,
                        month: month,
                        isPaid: payment != null,
                        busy: busy,
                        onPay: onPay == null ? null : () => onPay!(month),
                        onUndo: onUndo == null ? null : () => onUndo!(month),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      );
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.year,
    required this.month,
    required this.isPaid,
    required this.busy,
    required this.onPay,
    required this.onUndo,
  });

  final int year;
  final int month;
  final bool isPaid;
  final bool busy;
  final VoidCallback? onPay;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_monthName(month)} $year',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                _currency(rehearsalRoomMonthlyPayment),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _PaymentStatusChip(isPaid: isPaid),
              const SizedBox(height: 10),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isPaid)
                TextButton(
                  onPressed: onUndo,
                  child: const Text('Deshacer pago'),
                )
              else
                OutlinedButton(
                  onPressed: onPay,
                  child: const Text('Marcar como pagado'),
                ),
            ],
          ),
        ),
      );
}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.isPaid});

  final bool isPaid;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPaid
              ? AppColors.successBackground
              : AppColors.warningBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isPaid ? 'Pagado' : 'Pendiente',
          style: TextStyle(
            color: isPaid ? AppColors.successText : AppColors.warningText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.filter, required this.onChanged});

  final _MovementFilter filter;
  final ValueChanged<_MovementFilter> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          const Text(
            'Historial de movimientos',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          DropdownButton<_MovementFilter>(
            value: filter,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                  value: _MovementFilter.all, child: Text('Todos')),
              DropdownMenuItem(
                value: _MovementFilter.income,
                child: Text('Ingresos'),
              ),
              DropdownMenuItem(
                value: _MovementFilter.rehearsalRoom,
                child: Text('Local'),
              ),
              DropdownMenuItem(
                value: _MovementFilter.adjustments,
                child: Text('Ajustes'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      );
}

class _MovementTile extends StatelessWidget {
  const _MovementTile(this.movement);

  final FundMovement movement;

  @override
  Widget build(BuildContext context) {
    final negative = movement.amount.isNegative;
    final adjustment = movement.type == 'adjustment';
    final date = movement.effectiveDate ?? movement.createdAt;
    final formattedDate = date == null
        ? 'Procesando fecha'
        : DateFormat('dd/MM/y', 'es_ES').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          adjustment
              ? Icons.tune_rounded
              : negative
                  ? Icons.remove_circle_outline
                  : Icons.add_circle_outline,
          color: negative ? AppColors.dangerText : AppColors.successText,
        ),
        title: Text(movement.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (adjustment && movement.reason?.isNotEmpty == true)
              Text('Motivo: ${movement.reason}'),
            Row(
              children: [
                Text(formattedDate),
                if (movement.isReversed) ...[
                  const SizedBox(width: 8),
                  const _ReversedChip(),
                ],
              ],
            ),
          ],
        ),
        trailing: Text(
          _signedCurrency(movement.amount),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: negative ? AppColors.dangerText : AppColors.successText,
          ),
        ),
      ),
    );
  }
}

class _ReversedChip extends StatelessWidget {
  const _ReversedChip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Revertido',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      );
}

class _FundAdjustmentDialog extends StatefulWidget {
  const _FundAdjustmentDialog({required this.currentBalance});

  final double currentBalance;

  @override
  State<_FundAdjustmentDialog> createState() => _FundAdjustmentDialogState();
}

class _FundAdjustmentDialogState extends State<_FundAdjustmentDialog> {
  final _realBalanceController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _balanceError;
  String? _reasonError;

  double? get _realBalance => parseFundAmount(_realBalanceController.text);

  double? get _difference {
    final realBalance = _realBalance;
    if (realBalance == null) return null;
    return fundAdjustmentDifference(
      currentBalance: widget.currentBalance,
      realBalance: realBalance,
    );
  }

  @override
  void initState() {
    super.initState();
    _realBalanceController.addListener(_refreshDifference);
  }

  @override
  void dispose() {
    _realBalanceController
      ..removeListener(_refreshDifference)
      ..dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _refreshDifference() => setState(() {
        _balanceError = null;
      });

  void _submit() {
    final realBalance = _realBalance;
    final difference = _difference;
    final reason = _reasonController.text.trim();
    if (realBalance == null || !realBalance.isFinite) {
      setState(() => _balanceError = 'Introduce un saldo válido.');
      return;
    }
    if (realBalance < 0) {
      setState(() => _balanceError = 'El saldo real no puede ser negativo.');
      return;
    }
    if (difference == null || difference.abs() < 0.005) {
      setState(() => _balanceError = 'No hay ninguna diferencia que guardar.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _reasonError = 'Indica el motivo del ajuste.');
      return;
    }
    Navigator.pop(
      context,
      _FundAdjustmentRequest(
        realBalance: realBalance,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final difference = _difference;
    final differenceColor = difference == null || difference.abs() < 0.005
        ? AppColors.textSecondary
        : difference.isNegative
            ? AppColors.dangerText
            : AppColors.successText;
    return AlertDialog(
      title: const Text('Ajustar fondo'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdjustmentSummaryRow(
              label: 'Saldo actual',
              value: _currency(widget.currentBalance),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _realBalanceController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Saldo real',
                prefixText: '€ ',
                errorText: _balanceError,
              ),
            ),
            const SizedBox(height: 12),
            _AdjustmentSummaryRow(
              label: 'Diferencia',
              value: difference == null
                  ? '—'
                  : difference.abs() < 0.005
                      ? _currency(0)
                      : _signedCurrency(difference),
              valueColor: differenceColor,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLength: 160,
              decoration: InputDecoration(
                labelText: 'Motivo del ajuste',
                hintText: 'Ej. Ajuste de caja',
                errorText: _reasonError,
              ),
              onChanged: (_) {
                if (_reasonError != null) {
                  setState(() => _reasonError = null);
                }
              },
            ),
            const Text(
              'Se añadirá un movimiento nuevo. El historial existente no se modificará.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _AdjustmentSummaryRow extends StatelessWidget {
  const _AdjustmentSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      );
}

class _FundAdjustmentRequest {
  const _FundAdjustmentRequest({
    required this.realBalance,
    required this.reason,
  });

  final double realBalance;
  final String reason;
}

class _ManualIncomeDialog extends StatefulWidget {
  const _ManualIncomeDialog();

  @override
  State<_ManualIncomeDialog> createState() => _ManualIncomeDialogState();
}

class _ManualIncomeDialogState extends State<_ManualIncomeDialog> {
  final _amountController = TextEditingController();
  final _descriptionController =
      TextEditingController(text: 'Aportación manual');
  var _effectiveDate = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && mounted) setState(() => _effectiveDate = picked);
  }

  void _submit() {
    final amount = parseFundAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Indica un importe mayor que 0.');
      return;
    }
    Navigator.pop(
      context,
      _ManualIncomeRequest(
        amount: amount,
        description: _descriptionController.text,
        effectiveDate: _effectiveDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Añadir dinero'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Importe',
                  prefixText: '€ ',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Concepto'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                      DateFormat('dd/MM/y', 'es_ES').format(_effectiveDate)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Añadir dinero')),
        ],
      );
}

class _ManualIncomeRequest {
  const _ManualIncomeRequest({
    required this.amount,
    required this.description,
    required this.effectiveDate,
  });

  final double amount;
  final String description;
  final DateTime effectiveDate;
}

class _FundMessage extends StatelessWidget {
  const _FundMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: AppColors.iconSecondary),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

String _currency(double amount) => NumberFormat.currency(
      locale: 'es_ES',
      symbol: '€',
      decimalDigits: 2,
    ).format(amount);

String _signedCurrency(double amount) =>
    '${amount.isNegative ? '−' : '+'}${_currency(amount.abs())}';

String _monthName(int month) => const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ][month - 1];

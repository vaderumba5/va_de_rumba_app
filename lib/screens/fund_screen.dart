import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/fund_concert_metrics.dart';
import '../core/fund_constants.dart';
import '../models/concert.dart';
import '../models/rehearsal_room_payment.dart';
import '../services/group_fund_service.dart';
import '../services/firestore_concert_repository.dart';
import '../models/app_permission.dart';
import '../providers/current_user_scope.dart';
import '../widgets/app_refresh_view.dart';
import '../widgets/fund_overview.dart';

enum _MovementFilter { all, income, expense }

class FundScreen extends StatefulWidget {
  const FundScreen({super.key});

  @override
  State<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {
  final _service = GroupFundService();
  final _concertRepo = FirestoreConcertRepository();
  final _processingMonths = <String>{};
  final _processingConcerts = <String>{};
  var _selectedYear = DateTime.now().year;
  var _addingMoney = false;
  var _adjustingFund = false;
  var _filter = _MovementFilter.all;
  var _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _categoryFilter;
  DateTime? _monthFilter;
  bool _movementsExpanded = true;
  int _section = 0;
  bool _hideAmounts = false;
  bool _movementsAscending = false;
  List<Concert> _availableConcerts = const [];
  double _currentBalance = 0;

  Future<void> _refresh() async {
    await Future.wait([
      _service.refresh(_selectedYear),
      _concertRepo.refresh(),
    ]);
  }

  Future<void> _addMoney() async {
    if (_addingMoney) return;
    final request = await showDialog<_ManualMovementRequest>(
      context: context,
      builder: (_) => _ManualMovementDialog(
        concerts: _availableConcerts,
        currentBalance: _currentBalance,
      ),
    );
    if (request == null || !mounted) return;

    setState(() => _addingMoney = true);
    try {
      await _service.addManualMovement(
        isIncome: request.isIncome,
        amount: request.amount,
        description: request.description,
        category: request.category,
        effectiveDate: request.effectiveDate,
        notes: request.notes,
        concertId: request.concertId,
        concertName: request.concertName,
      );
      if (mounted) _showMessage('Movimiento registrado correctamente.');
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

  Future<void> _payRoom(
    int year,
    int month,
    _RoomPaymentRequest request,
  ) async {
    final key = '$year-$month';
    if (_processingMonths.contains(key)) return;
    setState(() => _processingMonths.add(key));
    try {
      await _service.payRehearsalRoom(
        year,
        month,
        amount: request.amount,
        effectiveDate: request.date,
        notes: request.notes,
        description: request.description,
      );
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

  Future<void> _undoRoomPayment(int year, int month,
      [double? paidAmount]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deshacer pago'),
        content: Text(
          '¿Quieres desmarcar como pagado el local de ${_monthName(month).toLowerCase()} de $year?\n\nSe devolverán ${_currency(paidAmount ?? rehearsalRoomMonthlyPayment)} al Fondo.',
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

  Future<void> _confirmRoomPayment(int year, int month, double fee) async {
    final request = await showDialog<_RoomPaymentRequest>(
      context: context,
      builder: (context) => _RoomPaymentDialog(
        year: year,
        month: month,
        initialAmount: fee,
      ),
    );
    if (request != null && mounted) await _payRoom(year, month, request);
  }

  Future<void> _changeRoomFee(double currentFee) async {
    final controller = TextEditingController(
      text: currentFee.toStringAsFixed(2).replaceAll('.', ','),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuración del local'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cuota mensual',
            suffixText: '€',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final amount = parseFundAmount(controller.text);
              if (amount != null && amount > 0) Navigator.pop(context, amount);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      await _service.setRehearsalRoomFee(value);
      if (mounted) _showMessage('Cuota mensual actualizada.');
    } catch (error, stackTrace) {
      debugPrint('Error al cambiar la cuota: $error\n$stackTrace');
      if (mounted) _showMessage('No se pudo cambiar la cuota.', error: true);
    }
  }

  Future<void> _changeDistributionMemberCount(int currentCount) async {
    final controller = TextEditingController(text: '$currentCount');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuración del reparto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de integrantes',
            helperText: 'Se aplicará a repartos estimados sin número fijado.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final count = int.tryParse(controller.text.trim());
              if (count != null && count > 0 && count <= 50) {
                Navigator.pop(context, count);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      await _service.setDistributionMemberCount(value);
      if (mounted) _showMessage('Configuración del reparto actualizada.');
    } catch (error, stackTrace) {
      debugPrint('Error al configurar integrantes: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo guardar la configuración.', error: true);
      }
    }
  }

  Future<void> _confirmConcertDistribution(
    Concert concert,
    int defaultMemberCount,
  ) async {
    if (_processingConcerts.contains(concert.id)) return;
    final metrics = calculateConcertDistribution(
      concert,
      defaultMemberCount: defaultMemberCount,
    );
    if (metrics == null) {
      _showMessage('Indica primero el caché del concierto.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cobro y reparto'),
        content: Text(
          'Se añadirán ${_currency(metrics.fundContribution)} al Fondo y se fijará el reparto entre ${metrics.memberCount} integrantes.\n\nGanancia por persona: ${_currency(metrics.perMember)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar reparto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processingConcerts.add(concert.id));
    try {
      await _service.confirmConcertDistribution(
        concert,
        memberCount: metrics.memberCount,
      );
      if (mounted) _showMessage('Cobro y reparto confirmados.');
    } catch (error, stackTrace) {
      debugPrint('Error al confirmar reparto: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo confirmar el reparto.', error: true);
      }
    } finally {
      if (mounted) setState(() => _processingConcerts.remove(concert.id));
    }
  }

  Future<void> _showMovementDetails(
    FundMovement movement, {
    required bool canManage,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => _MovementDetailsDialog(
        movement: movement,
        canManage: canManage && movement.type.startsWith('manual_'),
      ),
    );
    if (action == 'edit' && mounted) await _editMovement(movement);
    if (action == 'delete' && mounted) await _deleteMovement(movement);
  }

  Future<void> _editMovement(FundMovement movement) async {
    final request = await showDialog<_ManualMovementRequest>(
      context: context,
      builder: (_) => _ManualMovementDialog(
        initial: movement,
        concerts: _availableConcerts,
        currentBalance: _currentBalance,
      ),
    );
    if (request == null || !mounted) return;
    try {
      await _service.updateManualMovement(
        movement: movement,
        isIncome: request.isIncome,
        amount: request.amount,
        description: request.description,
        category: request.category,
        effectiveDate: request.effectiveDate,
        notes: request.notes,
        concertId: request.concertId,
        concertName: request.concertName,
      );
      if (mounted) _showMessage('Movimiento actualizado.');
    } catch (error, stackTrace) {
      debugPrint('Error al editar movimiento: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo editar el movimiento.', error: true);
      }
    }
  }

  Future<void> _deleteMovement(FundMovement movement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar movimiento?'),
        content: const Text(
          'Su efecto se revertirá automáticamente en el saldo del fondo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deleteManualMovement(movement);
      if (mounted) _showMessage('Movimiento eliminado.');
    } catch (error, stackTrace) {
      debugPrint('Error al eliminar movimiento: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo eliminar el movimiento.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Concert>>(
        stream: _concertRepo.streamConcerts(),
        builder: (context, concertsSnapshot) => StreamBuilder<double>(
          stream: _service.watchAvailableAmount(),
          builder: (context, balanceSnapshot) => StreamBuilder<double>(
            stream: _service.watchRehearsalRoomFee(),
            builder: (context, feeSnapshot) => StreamBuilder<int>(
              stream: _service.watchDistributionMemberCount(),
              builder: (context, memberCountSnapshot) =>
                  StreamBuilder<Map<int, RehearsalRoomPayment>>(
                stream: _service.watchRoomPayments(_selectedYear),
                builder: (context, paymentsSnapshot) =>
                    StreamBuilder<List<FundMovement>>(
                  stream: _service.watchMovements(),
                  builder: (context, movementsSnapshot) {
                    final concerts = concertsSnapshot.data ?? const <Concert>[];
                    final balance = balanceSnapshot.data ?? 0;
                    _availableConcerts = concerts;
                    _currentBalance = balance;
                    final fee = feeSnapshot.data ?? rehearsalRoomMonthlyPayment;
                    final memberCount = memberCountSnapshot.data ?? 5;
                    final movements =
                        movementsSnapshot.data ?? const <FundMovement>[];
                    final filteredMovements = _filterMovements(movements);
                    final now = DateTime.now();
                    final monthMovements = movements.where((movement) {
                      final date = movement.effectiveDate ?? movement.createdAt;
                      return !movement.isReversed &&
                          date != null &&
                          date.year == now.year &&
                          date.month == now.month;
                    }).toList();
                    final income = monthMovements
                        .where((movement) => movement.amount > 0)
                        .fold<double>(
                            0, (sum, movement) => sum + movement.amount);
                    final expenses = monthMovements
                        .where((movement) => movement.amount < 0)
                        .fold<double>(
                            0, (sum, movement) => sum + movement.amount.abs());
                    final previousMonth = DateTime(now.year, now.month - 1);
                    final previousMonthMovements = movements.where((movement) {
                      final date = movement.effectiveDate ?? movement.createdAt;
                      return !movement.isReversed &&
                          date != null &&
                          date.year == previousMonth.year &&
                          date.month == previousMonth.month;
                    });
                    final previousMonthBalance =
                        previousMonthMovements.fold<double>(
                      0,
                      (sum, movement) => sum + movement.amount,
                    );
                    final currentDistributions = concerts
                        .where((concert) =>
                            concert.date.year == now.year &&
                            concert.date.month == now.month)
                        .map((concert) => calculateConcertDistribution(
                              concert,
                              defaultMemberCount: memberCount,
                            ))
                        .whereType<ConcertDistributionMetrics>()
                        .toList();
                    final monthContributions =
                        currentDistributions.fold<double>(
                      0,
                      (sum, metrics) => sum + metrics.fundContribution,
                    );
                    final individualMonth = currentDistributions.fold<double>(
                      0,
                      (sum, metrics) => sum + metrics.perMember,
                    );
                    final concertTotal = concertIncomeTotal(concerts);
                    final concertMonth = concertIncomeForPeriod(
                      concerts,
                      year: now.year,
                      month: now.month,
                    );
                    final concertYear = concertIncomeForPeriod(
                      concerts,
                      year: now.year,
                    );
                    final incomeByYear = concertIncomeByYear(concerts);
                    final countableConcerts = concerts
                        .where((concert) =>
                            concert.status != ConcertStatus.cancelled)
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));
                    final canManage =
                        CurrentUserScope.authorization.canManageModule(
                      CurrentUserScope.of(context),
                      AppModules.fund,
                    );
                    return LayoutBuilder(builder: (context, constraints) {
                      final desktop = constraints.maxWidth >= 980;
                      final horizontal = constraints.maxWidth > 1280
                          ? (constraints.maxWidth - 1232) / 2
                          : desktop
                              ? 24.0
                              : 16.0;
                      final history = _MovementHistoryPanel(
                        movements: filteredMovements,
                        loading: movementsSnapshot.connectionState ==
                            ConnectionState.waiting,
                        error: movementsSnapshot.hasError,
                        canManage: canManage,
                        filter: _filter,
                        search: _search,
                        searchController: _searchController,
                        category: _categoryFilter,
                        month: _monthFilter,
                        onFilterChanged: (value) =>
                            setState(() => _filter = value),
                        onSearchChanged: (value) {
                          if (value.isEmpty) _searchController.clear();
                          setState(() => _search = value);
                        },
                        onCategoryChanged: (value) =>
                            setState(() => _categoryFilter = value),
                        onMonthChanged: (value) =>
                            setState(() => _monthFilter = value),
                        onAdd: canManage ? _addMoney : null,
                        onOpen: (movement) => _showMovementDetails(
                          movement,
                          canManage: canManage,
                        ),
                        expanded: _movementsExpanded,
                        onExpandedChanged: (value) =>
                            setState(() => _movementsExpanded = value),
                        ascending: _movementsAscending,
                        onToggleOrder: () => setState(
                            () => _movementsAscending = !_movementsAscending),
                      );
                      final room = _RoomDashboardCard(
                        year: _selectedYear,
                        fee: fee,
                        balance: balance,
                        payments: paymentsSnapshot.data ?? const {},
                        processingMonths: _processingMonths,
                        canManage: canManage,
                        onPreviousYear: () => setState(() => _selectedYear--),
                        onNextYear: () => setState(() => _selectedYear++),
                        onPay: (month) => _confirmRoomPayment(
                          _selectedYear,
                          month,
                          fee,
                        ),
                        onUndo: (month) => _undoRoomPayment(
                          _selectedYear,
                          month,
                          (paymentsSnapshot.data ?? const {})[month]?.amount,
                        ),
                        onChangeFee: () => _changeRoomFee(fee),
                      );
                      final analytics = Column(children: [
                        _ConcertIncomeBreakdown(
                          month: concertMonth,
                          year: concertYear,
                          total: concertTotal,
                          byYear: incomeByYear,
                          concerts: countableConcerts,
                          memberCount: memberCount,
                          canManage: canManage,
                          processingIds: _processingConcerts,
                          onConfirm: (concert) =>
                              _confirmConcertDistribution(concert, memberCount),
                        ),
                        const SizedBox(height: 12),
                        _ForecastCard(balance: balance, nextPayment: fee),
                        const SizedBox(height: 12),
                        _MonthlyBars(movements: movements),
                        const SizedBox(height: 12),
                        _TopExpenses(movements: monthMovements),
                      ]);
                      return AppRefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                              horizontal, 14, horizontal, 24),
                          children: [
                            _FundHeader(
                              busy: _addingMoney || _adjustingFund,
                              canManage: canManage,
                              onAdd: _addMoney,
                              onAdjust: () => _adjustFund(balance),
                              onSettings: () =>
                                  _changeDistributionMemberCount(memberCount),
                              onRefresh: _refresh,
                            ),
                            const SizedBox(height: 12),
                            if (balanceSnapshot.hasError ||
                                movementsSnapshot.hasError ||
                                feeSnapshot.hasError ||
                                concertsSnapshot.hasError ||
                                memberCountSnapshot.hasError)
                              const _SurfaceCard(
                                  child: _FundMessage(
                                icon: Icons.cloud_off_outlined,
                                message:
                                    'No se ha podido cargar el resumen. Pulsa Actualizar para volver a intentarlo.',
                              ))
                            else if (!balanceSnapshot.hasData ||
                                !movementsSnapshot.hasData ||
                                !feeSnapshot.hasData ||
                                !concertsSnapshot.hasData ||
                                !memberCountSnapshot.hasData)
                              const Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Center(
                                      child: CircularProgressIndicator()))
                            else
                              FundOverview(
                                month: now,
                                balance: balance,
                                income: income,
                                expenses: expenses,
                                monthlyFee: fee,
                                previousMonthBalance: previousMonthBalance,
                                concertContributions: monthContributions,
                                individualEstimate: individualMonth,
                                hidden: _hideAmounts,
                                onToggleAmounts: () => setState(
                                    () => _hideAmounts = !_hideAmounts),
                              ),
                            const SizedBox(height: 28),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final entry in const [
                                (
                                  label: 'Movimientos',
                                  icon: Icons.receipt_long_outlined
                                ),
                                (
                                  label: 'Local de ensayo',
                                  icon: Icons.music_note_outlined
                                ),
                                (
                                  label: 'Análisis',
                                  icon: Icons.bar_chart_rounded
                                ),
                              ].indexed)
                                ChoiceChip(
                                  avatar: Icon(entry.$2.icon, size: 18),
                                  label: Text(entry.$2.label),
                                  selected: _section == entry.$1,
                                  showCheckmark: false,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  onSelected: (_) =>
                                      setState(() => _section = entry.$1),
                                ),
                            ]),
                            const SizedBox(height: 18),
                            if (_section == 0) history,
                            if (_section == 1) room,
                            if (_section == 2) analytics,
                          ],
                        ),
                      );
                    });
                  },
                ),
              ),
            ),
          ),
        ),
      );

  List<FundMovement> _filterMovements(List<FundMovement> movements) {
    final filtered = switch (_filter) {
      _MovementFilter.all => movements,
      _MovementFilter.income =>
        movements.where((movement) => movement.amount > 0).toList(),
      _MovementFilter.expense =>
        movements.where((movement) => movement.amount < 0).toList(),
    };
    final result = filtered.where((movement) {
      final query = _search.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          movement.description.toLowerCase().contains(query) ||
          movement.category.toLowerCase().contains(query) ||
          (movement.notes ?? '').toLowerCase().contains(query);
      final matchesCategory =
          _categoryFilter == null || movement.category == _categoryFilter;
      final date = movement.effectiveDate ?? movement.createdAt;
      final matchesMonth = _monthFilter == null ||
          (date?.year == _monthFilter!.year &&
              date?.month == _monthFilter!.month);
      return matchesSearch && matchesCategory && matchesMonth;
    }).toList()
      ..sort((a, b) {
        final aDate = a.effectiveDate ?? a.createdAt ?? DateTime(1970);
        final bDate = b.effectiveDate ?? b.createdAt ?? DateTime(1970);
        return _movementsAscending
            ? aDate.compareTo(bDate)
            : bDate.compareTo(aDate);
      });
    return result;
  }
}

class _FundHeader extends StatelessWidget {
  const _FundHeader({
    required this.busy,
    required this.canManage,
    required this.onAdd,
    required this.onAdjust,
    required this.onSettings,
    required this.onRefresh,
  });
  final bool busy;
  final bool canManage;
  final VoidCallback onAdd;
  final VoidCallback onAdjust;
  final VoidCallback onSettings;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fondo del grupo',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Gestiona ingresos, gastos y pagos comunes.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          Wrap(spacing: 8, children: [
            IconButton(
              onPressed: onRefresh,
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (canManage)
              IconButton(
                onPressed: busy ? null : onSettings,
                tooltip: 'Configurar reparto',
                icon: const Icon(Icons.settings_outlined),
              ),
            if (canManage)
              OutlinedButton.icon(
                onPressed: busy ? null : onAdjust,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Ajustar saldo'),
              ),
            if (canManage)
              FilledButton.icon(
                onPressed: busy ? null : onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Añadir movimiento'),
              ),
          ]),
        ],
      );
}

class _MovementHistoryPanel extends StatelessWidget {
  const _MovementHistoryPanel({
    required this.movements,
    required this.loading,
    required this.error,
    required this.canManage,
    required this.filter,
    required this.search,
    required this.searchController,
    required this.category,
    required this.month,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onMonthChanged,
    required this.onAdd,
    required this.onOpen,
    required this.expanded,
    required this.onExpandedChanged,
    required this.ascending,
    required this.onToggleOrder,
  });
  final List<FundMovement> movements;
  final bool loading;
  final bool error;
  final bool canManage;
  final _MovementFilter filter;
  final String search;
  final TextEditingController searchController;
  final String? category;
  final DateTime? month;
  final ValueChanged<_MovementFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<DateTime?> onMonthChanged;
  final VoidCallback? onAdd;
  final ValueChanged<FundMovement> onOpen;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final bool ascending;
  final VoidCallback onToggleOrder;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<FundMovement>>{};
    for (final movement in movements) {
      final date = movement.effectiveDate ?? movement.createdAt;
      final key = date == null
          ? 'SIN FECHA'
          : DateFormat('MMMM y', 'es_ES').format(date).toUpperCase();
      grouped.putIfAbsent(key, () => []).add(movement);
    }
    return _SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('Movimientos',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          TextButton.icon(
            onPressed: () => onExpandedChanged(!expanded),
            icon: Icon(expanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded),
            label: Text(expanded ? 'Ver recientes' : 'Ver todos'),
          ),
          if (expanded)
            IconButton(
              onPressed: onToggleOrder,
              tooltip:
                  ascending ? 'Más recientes primero' : 'Más antiguos primero',
              icon: Icon(ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded),
            ),
        ]),
        Text(
          '${movements.length} movimientos según los filtros actuales',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        if (expanded) ...[
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Buscar movimientos...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final value in _MovementFilter.values)
              ChoiceChip(
                selected: filter == value,
                onSelected: (_) => onFilterChanged(value),
                label: Text(switch (value) {
                  _MovementFilter.all => 'Todos',
                  _MovementFilter.income => 'Ingresos',
                  _MovementFilter.expense => 'Gastos',
                }),
              ),
            PopupMenuButton<String>(
              tooltip: 'Filtrar categoría',
              onSelected: (value) =>
                  onCategoryChanged(value.isEmpty ? null : value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: '', child: Text('Todas las categorías')),
                PopupMenuItem(value: 'concert', child: Text('Concierto')),
                PopupMenuItem(value: 'contribution', child: Text('Aportación')),
                PopupMenuItem(
                    value: 'merchandising', child: Text('Merchandising')),
                PopupMenuItem(value: 'rehearsal_room', child: Text('Local')),
                PopupMenuItem(value: 'transport', child: Text('Transporte')),
                PopupMenuItem(value: 'material', child: Text('Material')),
                PopupMenuItem(value: 'promotion', child: Text('Publicidad')),
                PopupMenuItem(value: 'adjustment', child: Text('Ajustes')),
                PopupMenuItem(value: 'other', child: Text('Otros')),
              ],
              child: _FilterButton(
                icon: Icons.category_outlined,
                label:
                    category == null ? 'Categoría' : _categoryName(category!),
              ),
            ),
            PopupMenuButton<DateTime>(
              tooltip: 'Filtrar mes',
              onSelected: (value) =>
                  onMonthChanged(value.year == 1970 ? null : value),
              itemBuilder: (_) {
                final now = DateTime.now();
                return [
                  PopupMenuItem(
                      value: DateTime(1970),
                      child: const Text('Todos los meses')),
                  ...List.generate(12, (index) {
                    final date = DateTime(now.year, now.month - index);
                    return PopupMenuItem(
                      value: date,
                      child: Text(DateFormat('MMMM y', 'es_ES').format(date)),
                    );
                  }),
                ];
              },
              child: _FilterButton(
                icon: Icons.calendar_month_outlined,
                label: month == null
                    ? 'Mes'
                    : DateFormat('MMM y', 'es_ES').format(month!),
              ),
            ),
            if (search.isNotEmpty ||
                category != null ||
                month != null ||
                filter != _MovementFilter.all)
              TextButton.icon(
                onPressed: () {
                  onSearchChanged('');
                  onCategoryChanged(null);
                  onMonthChanged(null);
                  onFilterChanged(_MovementFilter.all);
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Limpiar filtros'),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        if (error)
          const _FundMessage(
              icon: Icons.cloud_off_outlined,
              message: 'No se han podido cargar los movimientos.')
        else if (loading)
          const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()))
        else if (movements.isEmpty &&
            (search.isNotEmpty ||
                category != null ||
                month != null ||
                filter != _MovementFilter.all))
          const _FundMessage(
              icon: Icons.search_off_rounded,
              message:
                  'No hay movimientos con estos filtros. Prueba otra búsqueda o limpia los filtros.')
        else if (movements.isEmpty)
          _EmptyMovements(onAdd: onAdd)
        else
          for (final entry in (expanded
              ? grouped.entries
              : _limitedMovementGroups(grouped, 3))) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 5),
              child: Text(entry.key,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: .7)),
            ),
            for (final movement in entry.value)
              _CompactMovementTile(
                  movement: movement, onTap: () => onOpen(movement)),
          ],
      ]),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          const Icon(Icons.arrow_drop_down_rounded, size: 17),
        ]),
      );
}

Iterable<MapEntry<String, List<FundMovement>>> _limitedMovementGroups(
  Map<String, List<FundMovement>> groups,
  int limit,
) sync* {
  var remaining = limit;
  for (final entry in groups.entries) {
    if (remaining <= 0) break;
    final values = entry.value.take(remaining).toList(growable: false);
    if (values.isNotEmpty) yield MapEntry(entry.key, values);
    remaining -= values.length;
  }
}

class _CompactMovementTile extends StatelessWidget {
  const _CompactMovementTile({required this.movement, required this.onTap});
  final FundMovement movement;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final negative = movement.amount < 0;
    final date = movement.effectiveDate ?? movement.createdAt;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_movementIcon(movement), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movement.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '${date == null ? 'Procesando fecha' : DateFormat('d MMM y', 'es_ES').format(date)} · ${_categoryName(movement.category)}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          )),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_signedCurrency(movement.amount),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: negative
                        ? AppColors.dangerText
                        : AppColors.successText)),
            if (movement.isReversed) const _ReversedChip(),
          ]),
        ]),
      ),
    );
  }
}

class _RoomDashboardCard extends StatelessWidget {
  const _RoomDashboardCard({
    required this.year,
    required this.fee,
    required this.balance,
    required this.payments,
    required this.processingMonths,
    required this.canManage,
    required this.onPreviousYear,
    required this.onNextYear,
    required this.onPay,
    required this.onUndo,
    required this.onChangeFee,
  });
  final int year;
  final double fee;
  final double balance;
  final Map<int, RehearsalRoomPayment> payments;
  final Set<String> processingMonths;
  final bool canManage;
  final VoidCallback onPreviousYear;
  final VoidCallback onNextYear;
  final ValueChanged<int> onPay;
  final ValueChanged<int> onUndo;
  final VoidCallback onChangeFee;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = year == now.year ? now.month : 1;
    final isPaid = payments.containsKey(currentMonth);
    final paidTotal = payments.values
        .fold<double>(0, (total, payment) => total + payment.amount);
    final pendingTotal = (12 - payments.length) * fee;
    return _SurfaceCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.music_note_rounded, size: 19),
        const SizedBox(width: 7),
        const Expanded(
            child: Text('Local de ensayo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        if (canManage)
          IconButton(
            onPressed: onChangeFee,
            tooltip: 'Cambiar cuota',
            icon: const Icon(Icons.settings_outlined, size: 19),
          ),
      ]),
      Text('${_currency(fee)} / mes',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      Wrap(spacing: 10, runSpacing: 5, children: [
        Text('Saldo antes: ${_currency(balance)}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text('Después del pago: ${_currency(balance - fee)}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: balance < fee
                    ? AppColors.dangerText
                    : AppColors.successText)),
      ]),
      if (!isPaid && balance < fee) ...[
        const SizedBox(height: 7),
        const Row(children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.warningText),
          SizedBox(width: 5),
          Expanded(
            child: Text('El saldo actual no cubre el próximo pago del local.',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningText)),
          ),
        ]),
      ],
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_monthName(currentMonth)} $year',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          _PaymentStatusChip(isPaid: isPaid),
        ])),
        if (processingMonths.contains('$year-$currentMonth'))
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
        else if (canManage && !isPaid)
          FilledButton(
            onPressed: () => onPay(currentMonth),
            child: const Text('Marcar como pagado'),
          ),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 6, children: [
        _RoomSummaryChip(
            label: 'Pagado', value: _currency(paidTotal), positive: true),
        _RoomSummaryChip(
            label: 'Sin pagar en el año',
            value: _currency(pendingTotal),
            positive: false),
        _RoomSummaryChip(label: 'Meses', value: '${payments.length} / 12'),
      ]),
      const SizedBox(height: 8),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('Historial de pagos',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        subtitle: Text('${payments.length} meses pagados',
            style: const TextStyle(fontSize: 11)),
        children: [
          Row(children: [
            IconButton(
                onPressed: onPreviousYear,
                tooltip: 'Año anterior',
                icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(
                child: Text('$year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: onNextYear,
                tooltip: 'Año siguiente',
                icon: const Icon(Icons.chevron_right_rounded)),
          ]),
          for (var month = 12; month >= 1; month--)
            _RoomMonthRow(
              month: month,
              amount: payments[month]?.amount ?? fee,
              isPaid: payments.containsKey(month),
              paidAt: payments[month]?.paidAt,
              paidByName: payments[month]?.createdByName,
              onPay: canManage &&
                      !payments.containsKey(month) &&
                      !processingMonths.contains('$year-$month')
                  ? () => onPay(month)
                  : null,
              onUndo: canManage && payments.containsKey(month)
                  ? () => onUndo(month)
                  : null,
            ),
        ],
      ),
    ]));
  }
}

class _RoomMonthRow extends StatelessWidget {
  const _RoomMonthRow(
      {required this.month,
      required this.amount,
      required this.isPaid,
      this.paidAt,
      this.paidByName,
      this.onPay,
      this.onUndo});
  final int month;
  final double amount;
  final bool isPaid;
  final DateTime? paidAt;
  final String? paidByName;
  final VoidCallback? onPay;
  final VoidCallback? onUndo;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
              child: Text(_monthName(month),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(
                isPaid
                    ? 'Pagado${paidAt == null ? '' : ' · ${DateFormat('dd/MM/y').format(paidAt!)}'}${(paidByName ?? '').isEmpty ? '' : ' · $paidByName'}'
                    : 'Pendiente',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 10,
                    color: isPaid
                        ? AppColors.successText
                        : AppColors.textSecondary)),
          ),
          const SizedBox(width: 10),
          SizedBox(
              width: 65,
              child: Text(_currency(amount),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700))),
          if (onUndo != null)
            TextButton(
              onPressed: onUndo,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('Desmarcar', style: TextStyle(fontSize: 10)),
            )
          else if (onPay != null)
            TextButton(
              onPressed: onPay,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('Marcar', style: TextStyle(fontSize: 10)),
            )
          else
            const SizedBox(width: 62),
        ]),
      );
}

class _RoomSummaryChip extends StatelessWidget {
  const _RoomSummaryChip({
    required this.label,
    required this.value,
    this.positive,
  });
  final String label;
  final String value;
  final bool? positive;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text('$label · $value',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: positive == null
                  ? AppColors.textSecondary
                  : positive!
                      ? AppColors.successText
                      : AppColors.dangerText,
            )),
      );
}

class _ConcertIncomeBreakdown extends StatelessWidget {
  const _ConcertIncomeBreakdown({
    required this.month,
    required this.year,
    required this.total,
    required this.byYear,
    required this.concerts,
    required this.memberCount,
    required this.canManage,
    required this.processingIds,
    required this.onConfirm,
  });

  final double month;
  final double year;
  final double total;
  final Map<int, double> byYear;
  final List<Concert> concerts;
  final int memberCount;
  final bool canManage;
  final Set<String> processingIds;
  final ValueChanged<Concert> onConfirm;

  @override
  Widget build(BuildContext context) {
    final years = byYear.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final now = DateTime.now();
    final monthDistributed = distributionTotalForPeriod(
      concerts,
      defaultMemberCount: memberCount,
      year: now.year,
      month: now.month,
    );
    final yearDistributed = distributionTotalForPeriod(
      concerts,
      defaultMemberCount: memberCount,
      year: now.year,
    );
    final monthContributions = concerts
        .where((concert) =>
            concert.date.year == now.year &&
            concert.date.month == now.month &&
            calculateConcertDistribution(concert,
                    defaultMemberCount: memberCount) !=
                null)
        .fold<double>(0, (sum, concert) => sum + concert.fundContribution);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Reparto entre integrantes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _SummaryLine(
              label: 'Ganancia estimada por persona este mes',
              value: _currency(monthDistributed / memberCount)),
          _SummaryLine(
              label: 'Ganancia estimada por persona este año',
              value: _currency(yearDistributed / memberCount)),
          _SummaryLine(
              label: 'Total repartido este mes',
              value: _currency(monthDistributed)),
          _SummaryLine(
              label: 'Aportaciones al fondo este mes',
              value: _currency(monthContributions)),
          _SummaryLine(label: 'Integrantes por defecto', value: '$memberCount'),
          const Divider(height: 20),
          _SummaryLine(label: 'Caché este mes', value: _currency(month)),
          _SummaryLine(label: 'Caché este año', value: _currency(year)),
          _SummaryLine(
              label: 'Caché histórico', value: _currency(total), strong: true),
          if (years.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Por año',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            for (final entry in years)
              _SummaryLine(
                  label: '${entry.key}', value: _currency(entry.value)),
          ],
          if (concerts.isNotEmpty) ...[
            const Divider(height: 20),
            _ConcertDistributionList(
              concerts: concerts,
              defaultMemberCount: memberCount,
              canManage: canManage,
              processingIds: processingIds,
              onConfirm: onConfirm,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConcertDistributionList extends StatefulWidget {
  const _ConcertDistributionList({
    required this.concerts,
    required this.defaultMemberCount,
    required this.canManage,
    required this.processingIds,
    required this.onConfirm,
  });

  final List<Concert> concerts;
  final int defaultMemberCount;
  final bool canManage;
  final Set<String> processingIds;
  final ValueChanged<Concert> onConfirm;

  @override
  State<_ConcertDistributionList> createState() =>
      _ConcertDistributionListState();
}

class _ConcertDistributionListState extends State<_ConcertDistributionList> {
  int _year = DateTime.now().year;
  int? _month = DateTime.now().month;
  String _status = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final years = widget.concerts.map((item) => item.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (!years.contains(_year)) years.insert(0, _year);
    final visible = widget.concerts.where((concert) {
      final title =
          concert.venueName.trim().isEmpty ? concert.place : concert.venueName;
      final matchesQuery =
          _query.isEmpty || title.toLowerCase().contains(_query.toLowerCase());
      final matchesDate = concert.date.year == _year &&
          (_month == null || concert.date.month == _month);
      final matchesStatus = _status == 'all' ||
          (_status == 'pending'
              ? concert.paymentStatus != 'confirmed'
              : concert.distributionStatus == _status);
      return matchesQuery && matchesDate && matchesStatus;
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Desglose por concierto',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      TextField(
        onChanged: (value) => setState(() => _query = value.trim()),
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Buscar concierto...',
          prefixIcon: Icon(Icons.search_rounded, size: 18),
        ),
      ),
      const SizedBox(height: 7),
      Wrap(spacing: 7, runSpacing: 7, children: [
        DropdownButton<int>(
          value: _year,
          items: years
              .map(
                  (year) => DropdownMenuItem(value: year, child: Text('$year')))
              .toList(),
          onChanged: (value) => setState(() => _year = value ?? _year),
        ),
        DropdownButton<int?>(
          value: _month,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todo el año')),
            ...List.generate(
              12,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text(_monthName(index + 1)),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _month = value),
        ),
        DropdownButton<String>(
          value: _status,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Todos los estados')),
            DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
            DropdownMenuItem(value: 'estimated', child: Text('Estimados')),
            DropdownMenuItem(value: 'confirmed', child: Text('Confirmados')),
          ],
          onChanged: (value) => setState(() => _status = value ?? 'all'),
        ),
      ]),
      const SizedBox(height: 6),
      if (visible.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('No hay conciertos para estos filtros.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        )
      else
        for (final concert in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: _ConcertDistributionRow(
              concert: concert,
              defaultMemberCount: widget.defaultMemberCount,
              canConfirm:
                  widget.canManage && concert.distributionStatus != 'confirmed',
              processing: widget.processingIds.contains(concert.id),
              onConfirm: () => widget.onConfirm(concert),
            ),
          ),
    ]);
  }
}

class _ConcertDistributionRow extends StatelessWidget {
  const _ConcertDistributionRow({
    required this.concert,
    required this.defaultMemberCount,
    required this.canConfirm,
    required this.processing,
    required this.onConfirm,
  });

  final Concert concert;
  final int defaultMemberCount;
  final bool canConfirm;
  final bool processing;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final metrics = calculateConcertDistribution(
      concert,
      defaultMemberCount: defaultMemberCount,
    );
    final title =
        concert.venueName.trim().isEmpty ? concert.place : concert.venueName;
    if (metrics == null) {
      return Row(children: [
        const Icon(Icons.mic_none_rounded, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text(DateFormat('d MMM y', 'es_ES').format(concert.date),
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
        const Text('Pendiente de indicar',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.warningText)),
      ]);
    }
    final confirmed = concert.distributionStatus == 'confirmed';
    final paid = concert.paymentStatus == 'confirmed';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.mic_none_rounded, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text(DateFormat('d MMM y', 'es_ES').format(concert.date),
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: confirmed
                ? AppColors.successBackground
                : AppColors.warningBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            !paid
                ? 'Pendiente de cobro'
                : confirmed
                    ? 'Confirmado'
                    : 'Estimado',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: confirmed ? AppColors.successText : AppColors.warningText,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 9, runSpacing: 4, children: [
        Text('Caché ${_currency(metrics.cache)}',
            style: const TextStyle(fontSize: 10)),
        Text('Fondo ${_currency(metrics.fundContribution)}',
            style: const TextStyle(fontSize: 10)),
        if (metrics.associatedExpenses > 0)
          Text('Gastos ${_currency(metrics.associatedExpenses)}',
              style: const TextStyle(fontSize: 10)),
        Text('Reparto ${_currency(metrics.distributable)}',
            style: const TextStyle(fontSize: 10)),
        Text(
          '${_currency(metrics.perMember)} por persona · ${metrics.memberCount}',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ]),
      if (canConfirm) ...[
        const SizedBox(height: 7),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: processing ? null : onConfirm,
            icon: processing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 17),
            label:
                Text(processing ? 'Confirmando…' : 'Confirmar cobro y reparto'),
          ),
        ),
      ],
    ]);
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.balance, required this.nextPayment});
  final double balance;
  final double nextPayment;
  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Previsión tras una cuota del local',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Saldo actual', value: _currency(balance)),
          _SummaryLine(
              label: 'Una cuota del local',
              value: '−${_currency(nextPayment)}'),
          const Divider(),
          _SummaryLine(
              label: 'Saldo después del local',
              value: _currency(balance - nextPayment),
              strong: true),
        ]),
      );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(
      {required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
        ]),
      );
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.movements});
  final List<FundMovement> movements;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months =
        List.generate(6, (index) => DateTime(now.year, now.month - 5 + index));
    final values = months.map((month) {
      var income = 0.0;
      var expenses = 0.0;
      for (final movement in movements) {
        if (movement.isReversed) continue;
        final date = movement.effectiveDate ?? movement.createdAt;
        if (date?.year == month.year && date?.month == month.month) {
          if (movement.amount >= 0) income += movement.amount;
          if (movement.amount < 0) expenses += movement.amount.abs();
        }
      }
      return (income: income, expenses: expenses);
    }).toList();
    final maxValue = values.fold<double>(1, (max, value) {
      final candidate =
          value.income > value.expenses ? value.income : value.expenses;
      return candidate > max ? candidate : max;
    });
    return _SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Balance últimos 6 meses',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(months.length, (index) {
              final value = values[index];
              return Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                    SizedBox(
                        height: 68,
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _MiniBar(
                                  height: 64 * value.income / maxValue,
                                  color: AppColors.successText),
                              const SizedBox(width: 3),
                              _MiniBar(
                                  height: 64 * value.expenses / maxValue,
                                  color: AppColors.dangerText),
                            ])),
                    const SizedBox(height: 5),
                    Text(DateFormat('MMM', 'es_ES').format(months[index]),
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textSecondary)),
                  ]));
            }),
          )),
      const SizedBox(height: 6),
      const Row(children: [
        _ChartLegend(color: AppColors.successText, label: 'Ingresos'),
        SizedBox(width: 12),
        _ChartLegend(color: AppColors.dangerText, label: 'Gastos'),
      ]),
    ]));
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.height, required this.color});
  final double height;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 8,
        height: height.clamp(2, 64),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(5)),
      );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]);
}

class _TopExpenses extends StatelessWidget {
  const _TopExpenses({required this.movements});
  final List<FundMovement> movements;
  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final movement in movements.where((item) => item.amount < 0)) {
      totals.update(movement.category, (value) => value + movement.amount.abs(),
          ifAbsent: () => movement.amount.abs());
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Principales gastos del mes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (entries.isEmpty)
        const Text('Todavía no hay gastos este mes.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
      else
        for (final entry in entries.take(5))
          _SummaryLine(
              label: _categoryName(entry.key), value: _currency(entry.value)),
    ]));
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class _EmptyMovements extends StatelessWidget {
  const _EmptyMovements({this.onAdd});
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(children: [
          const Icon(Icons.receipt_long_outlined,
              size: 32, color: AppColors.iconSecondary),
          const SizedBox(height: 8),
          const Text('Todavía no hay movimientos',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          const Text('Los ingresos y gastos aparecerán aquí.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (onAdd != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Añadir movimiento')),
          ],
        ]),
      );
}

class _MovementDetailsDialog extends StatelessWidget {
  const _MovementDetailsDialog(
      {required this.movement, required this.canManage});
  final FundMovement movement;
  final bool canManage;
  @override
  Widget build(BuildContext context) {
    final date = movement.effectiveDate ?? movement.createdAt;
    return AlertDialog(
      title: const Text('Detalle del movimiento'),
      content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(movement.amount >= 0 ? 'INGRESO' : 'GASTO',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: .7)),
              const SizedBox(height: 4),
              Text(_signedCurrency(movement.amount),
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: movement.amount < 0
                          ? AppColors.dangerText
                          : AppColors.successText)),
              const SizedBox(height: 14),
              _SummaryLine(label: 'Concepto', value: movement.description),
              _SummaryLine(
                  label: 'Fecha',
                  value: date == null
                      ? 'Procesando'
                      : DateFormat('d MMMM y', 'es_ES').format(date)),
              _SummaryLine(
                  label: 'Categoría', value: _categoryName(movement.category)),
              if ((movement.concertName ?? '').isNotEmpty)
                _SummaryLine(
                    label: 'Concierto relacionado',
                    value: movement.concertName!),
              if ((movement.notes ?? '').isNotEmpty)
                _SummaryLine(label: 'Notas', value: movement.notes!),
              if ((movement.reason ?? '').isNotEmpty)
                _SummaryLine(label: 'Motivo', value: movement.reason!),
              if ((movement.createdByName ?? '').isNotEmpty)
                _SummaryLine(
                    label: 'Creado por', value: movement.createdByName!),
            ],
          )),
      actions: [
        if (canManage)
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'delete'),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
          ),
        if (canManage)
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
      ],
    );
  }
}

IconData _movementIcon(FundMovement movement) {
  if (movement.type == 'adjustment') return Icons.tune_rounded;
  return switch (movement.category) {
    'rehearsal_room' => Icons.music_note_rounded,
    'concert' => Icons.mic_none_rounded,
    'transport' => Icons.directions_car_outlined,
    'material' || 'instruments' => Icons.build_outlined,
    'promotion' => Icons.campaign_outlined,
    _ => movement.amount < 0
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded,
  };
}

String _categoryName(String category) => switch (category) {
      'manual_income' => 'Aportación',
      'manual_expense' => 'Otros',
      'concert' => 'Concierto',
      'contribution' => 'Aportación',
      'merchandising' => 'Merchandising',
      'rehearsal_room' => 'Local',
      'transport' => 'Transporte',
      'material' => 'Material',
      'instruments' => 'Instrumentos',
      'promotion' => 'Publicidad',
      'recording' => 'Grabación',
      'adjustment' => 'Ajuste',
      _ => 'Otros',
    };

// Legacy presentation kept temporarily for compatibility with older snapshots.
// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
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
                value: _MovementFilter.expense,
                child: Text('Gastos'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      );
}

// ignore: unused_element
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

class _RoomPaymentRequest {
  const _RoomPaymentRequest({
    required this.amount,
    required this.date,
    required this.description,
    required this.notes,
  });

  final double amount;
  final DateTime date;
  final String description;
  final String notes;
}

class _RoomPaymentDialog extends StatefulWidget {
  const _RoomPaymentDialog({
    required this.year,
    required this.month,
    required this.initialAmount,
  });

  final int year;
  final int month;
  final double initialAmount;

  @override
  State<_RoomPaymentDialog> createState() => _RoomPaymentDialogState();
}

class _RoomPaymentDialogState extends State<_RoomPaymentDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.initialAmount.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final TextEditingController _description = TextEditingController(
    text: 'Pago local de ensayo - ${_monthName(widget.month)} ${widget.year}',
  );
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      locale: const Locale('es', 'ES'),
    );
    if (value != null) setState(() => _date = value);
  }

  void _submit() {
    final amount = parseFundAmount(_amount.text);
    if (amount == null || amount <= 0 || _description.text.trim().isEmpty) {
      setState(() => _error = 'Revisa el importe y el concepto.');
      return;
    }
    Navigator.pop(
      context,
      _RoomPaymentRequest(
        amount: amount,
        date: _date,
        description: _description.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Registrar pago del local'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '${_monthName(widget.month)} ${widget.year}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Importe',
                  suffixText: '€',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Concepto'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat('d MMMM y', 'es_ES').format(_date)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Notas (opcional)'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Marcar como pagado'),
          ),
        ],
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

class _ManualMovementDialog extends StatefulWidget {
  const _ManualMovementDialog({
    this.initial,
    required this.concerts,
    required this.currentBalance,
  });
  final FundMovement? initial;
  final List<Concert> concerts;
  final double currentBalance;

  @override
  State<_ManualMovementDialog> createState() => _ManualMovementDialogState();
}

class _ManualMovementDialogState extends State<_ManualMovementDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late bool _isIncome;
  late String _category;
  late DateTime _effectiveDate;
  String _concertId = '';
  String? _error;

  static const _incomeCategories = {
    'concert': 'Concierto',
    'contribution': 'Aportación',
    'merchandising': 'Merchandising',
    'other': 'Otros',
  };
  static const _expenseCategories = {
    'rehearsal_room': 'Local',
    'transport': 'Transporte',
    'material': 'Material',
    'instruments': 'Instrumentos',
    'promotion': 'Publicidad',
    'recording': 'Grabación',
    'other': 'Otros',
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _isIncome = initial == null || initial.amount >= 0;
    _amountController = TextEditingController(
      text: initial == null
          ? ''
          : initial.amount.abs().toStringAsFixed(2).replaceAll('.', ','),
    );
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _effectiveDate =
        initial?.effectiveDate ?? initial?.createdAt ?? DateTime.now();
    _concertId = initial?.concertId ?? '';
    final categories = _isIncome ? _incomeCategories : _expenseCategories;
    _category = categories.containsKey(initial?.category)
        ? initial!.category
        : (_isIncome ? 'contribution' : 'other');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
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
    if (amount == null ||
        amount <= 0 ||
        _descriptionController.text.trim().isEmpty) {
      setState(() => _error = amount == null || amount <= 0
          ? 'Indica un importe mayor que 0.'
          : 'Indica un concepto.');
      return;
    }
    var concertName = '';
    for (final concert in widget.concerts) {
      if (concert.id != _concertId) continue;
      concertName =
          concert.venueName.trim().isEmpty ? concert.place : concert.venueName;
      break;
    }
    Navigator.pop(
      context,
      _ManualMovementRequest(
        isIncome: _isIncome,
        amount: amount,
        description: _descriptionController.text,
        category: _category,
        effectiveDate: _effectiveDate,
        notes: _notesController.text,
        concertId: _concertId,
        concertName: concertName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.initial == null ? 'Añadir movimiento' : 'Editar movimiento'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        label: Text('Ingreso'),
                        icon: Icon(Icons.arrow_upward_rounded)),
                    ButtonSegment(
                        value: false,
                        label: Text('Gasto'),
                        icon: Icon(Icons.arrow_downward_rounded)),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (selection) => setState(() {
                    _isIncome = selection.first;
                    final categories =
                        _isIncome ? _incomeCategories : _expenseCategories;
                    if (!categories.containsKey(_category)) {
                      _category = _isIncome ? 'contribution' : 'other';
                    }
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descriptionController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Concepto',
                    errorText:
                        _error?.contains('concepto') == true ? _error : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Importe',
                    suffixText: '€',
                    errorText:
                        _error?.contains('importe') == true ? _error : null,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: (_isIncome ? _incomeCategories : _expenseCategories)
                      .entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      widget.concerts.any((item) => item.id == _concertId)
                          ? _concertId
                          : '',
                  decoration: const InputDecoration(
                    labelText: 'Concierto relacionado (opcional)',
                    prefixIcon: Icon(Icons.mic_none_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Sin concierto relacionado')),
                    ...widget.concerts.map((concert) => DropdownMenuItem(
                          value: concert.id,
                          child: Text(concert.venueName.trim().isEmpty
                              ? concert.place
                              : concert.venueName),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => _concertId = value ?? ''),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                        DateFormat('d MMM y', 'es_ES').format(_effectiveDate)),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Saldo previsto: ${_currency(widget.currentBalance + (_isIncome ? 1 : -1) * (parseFundAmount(_amountController.text) ?? 0))}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.initial == null
                ? 'Guardar movimiento'
                : 'Guardar cambios'),
          ),
        ],
      );
}

class _ManualMovementRequest {
  const _ManualMovementRequest({
    required this.isIncome,
    required this.amount,
    required this.description,
    required this.category,
    required this.effectiveDate,
    required this.notes,
    required this.concertId,
    required this.concertName,
  });

  final bool isIncome;
  final double amount;
  final String description;
  final String category;
  final DateTime effectiveDate;
  final String notes;
  final String concertId;
  final String concertName;
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

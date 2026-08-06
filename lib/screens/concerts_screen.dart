import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/concert.dart';
import '../services/firestore_concert_repository.dart';
import '../utils/concert_actions.dart';
import '../widgets/concert_detail_panel.dart';
import 'concert_form_screen.dart';
import '../models/app_permission.dart';
import '../providers/current_user_scope.dart';

enum _StatusFilter { all, confirmed, pending, cancelled }

enum _TimeFilter { all, upcoming, past, thisMonth }

enum _SortOrder { upcomingFirst, dateAsc, dateDesc, place, priceAsc, priceDesc }

class ConcertsScreen extends StatefulWidget {
  const ConcertsScreen({super.key});

  @override
  State<ConcertsScreen> createState() => _ConcertsScreenState();
}

class _ConcertsScreenState extends State<ConcertsScreen> {
  final _repository = FirestoreConcertRepository();
  final _searchController = TextEditingController();
  late Future<List<Concert>> _concertsFuture;
  _StatusFilter _statusFilter = _StatusFilter.all;
  _TimeFilter _timeFilter = _TimeFilter.all;
  _SortOrder _sortOrder = _SortOrder.upcomingFirst;
  Concert? _selectedConcert;

  @override
  void initState() {
    super.initState();
    _concertsFuture = _repository.getAll();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  void _refresh() => setState(() => _concertsFuture = _repository.getAll());

  Future<void> _reloadList() async {
    debugPrint('[ConcertsScreen] Recarga iniciada');
    final concerts = await _repository.getAll();
    debugPrint(
        '[ConcertsScreen] Recarga completada (${concerts.length} conciertos)');
    if (!mounted) return;
    setState(() => _concertsFuture = Future.value(concerts));
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _statusFilter = _StatusFilter.all;
      _timeFilter = _TimeFilter.all;
      _sortOrder = _SortOrder.upcomingFirst;
    });
  }

  Future<void> _createConcert() async {
    final concert = await Navigator.push<Concert>(
      context,
      MaterialPageRoute(
        builder: (_) => ConcertFormScreen(
          initialDate: DateTime.now(),
          repository: _repository,
        ),
      ),
    );
    if (!mounted || concert == null) return;

    debugPrint('[ConcertsScreen] Inicio de creación: ${concert.id}');
    try {
      await _repository.createConcert(concert);
      debugPrint('[ConcertsScreen] Creación completada: ${concert.id}');
    } catch (error, stackTrace) {
      debugPrint('[ConcertsScreen] Error al crear ${concert.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage('No se ha podido crear el concierto.', error: true);
      }
      return;
    }

    if (!mounted) return;
    try {
      await _reloadList();
    } catch (error, stackTrace) {
      debugPrint(
          '[ConcertsScreen] Error al recargar tras crear ${concert.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage(
            'El concierto se creó, pero no se pudo actualizar la vista.',
            error: true);
      }
      return;
    }
    if (mounted) {
      _showMessage('Concierto creado correctamente.');
    }
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

    var updatePublicConcert = false;
    if (concert.isPublishedOnWeb && updated.isPublishedOnWeb) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Este concierto está publicado en la web'),
          content: const Text(
            'Puedes guardar los cambios solo en la app o actualizar también '
            'la publicación visible en vaderumba.es.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'app'),
              child: const Text('Guardar solo en la app'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'web'),
              child: const Text('Guardar y actualizar web'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel' || !mounted) return;
      updatePublicConcert = choice == 'web';
    }

    debugPrint('[ConcertsScreen] Inicio de edición: ${updated.id}');
    try {
      await _repository.updateConcert(
        updated,
        updatePublicConcert: updatePublicConcert,
      );
      debugPrint('[ConcertsScreen] Edición completada: ${updated.id}');
    } catch (error, stackTrace) {
      debugPrint('[ConcertsScreen] Error al actualizar ${updated.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage('No se ha podido actualizar el concierto.', error: true);
      }
      return;
    }

    if (!mounted) return;
    try {
      await _reloadList();
    } catch (error, stackTrace) {
      debugPrint(
          '[ConcertsScreen] Error al recargar tras editar ${updated.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage(
            'El concierto se actualizó, pero no se pudo actualizar la vista.',
            error: true);
      }
      return;
    }
    if (mounted) {
      _showMessage('Concierto actualizado correctamente.');
    }
  }

  Future<void> _deleteConcert(Concert concert) async {
    final date = DateFormat("d 'de' MMMM", 'es_ES').format(concert.date);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar concierto'),
        content: Text(
            '¿Quieres eliminar el concierto de ${concert.place} del $date?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;
    try {
      await _repository.deleteConcert(concert.id);
      if (!mounted) return;
      _refresh();
      _showMessage('Concierto eliminado.');
    } catch (_) {
      if (mounted) {
        _showMessage('No se ha podido eliminar el concierto.', error: true);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFB63D4D) : null),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Concert>>(
        future: _concertsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(onRetry: _refresh);
          }
          final content = _ConcertsContent(
            canManage: CurrentUserScope.authorization.canManageModule(
              CurrentUserScope.of(context),
              AppModules.concerts,
            ),
            concerts: snapshot.data ?? const [],
            query: _searchController.text,
            searchController: _searchController,
            statusFilter: _statusFilter,
            timeFilter: _timeFilter,
            sortOrder: _sortOrder,
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onTimeChanged: (value) => setState(() => _timeFilter = value),
            onSortChanged: (value) => setState(() => _sortOrder = value),
            onReset: _resetFilters,
            onRefresh: _refresh,
            onCreate: _createConcert,
            onEdit: _editConcert,
            onDelete: _deleteConcert,
            selectedConcert: _selectedConcert,
            onSelect: (concert) => setState(() => _selectedConcert = concert),
          );
          return LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 1250) return content;
            return Row(children: [
              Expanded(child: content),
              Container(
                  width: 370,
                  decoration: const BoxDecoration(
                      border:
                          Border(left: BorderSide(color: Color(0xFFE7E7E7)))),
                  child: ConcertDetailPanel(
                      concert: _selectedConcert,
                      onClose: () => setState(() => _selectedConcert = null),
                      onEdit: () {
                        if (_selectedConcert != null) {
                          _editConcert(_selectedConcert!);
                        }
                      },
                      onDelete: () {
                        if (_selectedConcert != null) {
                          _deleteConcert(_selectedConcert!);
                        }
                      })),
            ]);
          });
        },
      );
}

class _ConcertsContent extends StatelessWidget {
  const _ConcertsContent({
    required this.concerts,
    required this.query,
    required this.searchController,
    required this.statusFilter,
    required this.timeFilter,
    required this.sortOrder,
    required this.onStatusChanged,
    required this.onTimeChanged,
    required this.onSortChanged,
    required this.onReset,
    required this.onRefresh,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.selectedConcert,
    required this.onSelect,
    required this.canManage,
  });

  final List<Concert> concerts;
  final String query;
  final TextEditingController searchController;
  final _StatusFilter statusFilter;
  final _TimeFilter timeFilter;
  final _SortOrder sortOrder;
  final ValueChanged<_StatusFilter> onStatusChanged;
  final ValueChanged<_TimeFilter> onTimeChanged;
  final ValueChanged<_SortOrder> onSortChanged;
  final VoidCallback onReset;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final ValueChanged<Concert> onEdit;
  final ValueChanged<Concert> onDelete;
  final Concert? selectedConcert;
  final ValueChanged<Concert> onSelect;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final filtered = _filterConcerts();
    final isFiltered = query.isNotEmpty ||
        statusFilter != _StatusFilter.all ||
        timeFilter != _TimeFilter.all ||
        sortOrder != _SortOrder.upcomingFirst;
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      return SingleChildScrollView(
        padding:
            EdgeInsets.fromLTRB(desktop ? 32 : 20, 18, desktop ? 32 : 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1520),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Toolbar(
                total: filtered.length,
                searchController: searchController,
                statusFilter: statusFilter,
                timeFilter: timeFilter,
                sortOrder: sortOrder,
                isFiltered: isFiltered,
                onStatusChanged: onStatusChanged,
                onTimeChanged: onTimeChanged,
                onSortChanged: onSortChanged,
                onReset: onReset,
                onRefresh: onRefresh,
                onCreate: canManage ? onCreate : null,
              ),
              const SizedBox(height: 18),
              _Summary(concerts: concerts),
              const SizedBox(height: 20),
              if (concerts.isEmpty)
                _EmptyList(onCreate: canManage ? onCreate : null)
              else if (filtered.isEmpty)
                _NoResults(onReset: onReset)
              else if (desktop)
                _ConcertsTable(
                    concerts: filtered,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    selectedConcert: selectedConcert,
                    onSelect: onSelect)
              else
                _ConcertCards(
                    concerts: filtered,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onSelect: onSelect),
            ]),
          ),
        ),
      );
    });
  }

  List<Concert> _filterConcerts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedQuery = query.trim().toLowerCase();
    final result = concerts.where((concert) {
      final matchesStatus = switch (statusFilter) {
        _StatusFilter.all => true,
        _StatusFilter.confirmed => concert.status == ConcertStatus.confirmed,
        _StatusFilter.pending => concert.status == ConcertStatus.pending,
        _StatusFilter.cancelled => concert.status == ConcertStatus.cancelled,
      };
      final matchesTime = switch (timeFilter) {
        _TimeFilter.all => true,
        _TimeFilter.upcoming => !concert.date.isBefore(today),
        _TimeFilter.past => concert.date.isBefore(today),
        _TimeFilter.thisMonth =>
          concert.date.year == now.year && concert.date.month == now.month,
      };
      final searchable =
          '${concert.place} ${concert.comments} ${concert.time} ${concert.price?.toStringAsFixed(2) ?? ''}'
              .toLowerCase();
      return matchesStatus &&
          matchesTime &&
          (normalizedQuery.isEmpty || searchable.contains(normalizedQuery));
    }).toList();
    result.sort((a, b) {
      switch (sortOrder) {
        case _SortOrder.upcomingFirst:
          final aFuture = !a.date.isBefore(today);
          final bFuture = !b.date.isBefore(today);
          if (aFuture != bFuture) return aFuture ? -1 : 1;
          return a.date.compareTo(b.date);
        case _SortOrder.dateAsc:
          return a.date.compareTo(b.date);
        case _SortOrder.dateDesc:
          return b.date.compareTo(a.date);
        case _SortOrder.place:
          return a.place.toLowerCase().compareTo(b.place.toLowerCase());
        case _SortOrder.priceAsc:
          return (a.price ?? 0).compareTo(b.price ?? 0);
        case _SortOrder.priceDesc:
          return (b.price ?? 0).compareTo(a.price ?? 0);
      }
    });
    return result;
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar(
      {required this.total,
      required this.searchController,
      required this.statusFilter,
      required this.timeFilter,
      required this.sortOrder,
      required this.isFiltered,
      required this.onStatusChanged,
      required this.onTimeChanged,
      required this.onSortChanged,
      required this.onReset,
      required this.onRefresh,
      required this.onCreate});
  final int total;
  final TextEditingController searchController;
  final _StatusFilter statusFilter;
  final _TimeFilter timeFilter;
  final _SortOrder sortOrder;
  final bool isFiltered;
  final ValueChanged<_StatusFilter> onStatusChanged;
  final ValueChanged<_TimeFilter> onTimeChanged;
  final ValueChanged<_SortOrder> onSortChanged;
  final VoidCallback onReset;
  final VoidCallback onRefresh;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Todos los conciertos',
                    style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7)),
                SizedBox(height: 4),
                Text('Gestiona y consulta toda la agenda del grupo.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF777482)))
              ])),
          IconButton(
              tooltip: 'Recargar',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
          FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo concierto')),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final search = TextField(
              controller: searchController,
              decoration: InputDecoration(
                  hintText: 'Buscar por lugar, comentario, hora o precio…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.close_rounded)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12)));
          final filters = Wrap(spacing: 10, runSpacing: 10, children: [
            _FilterMenu<_StatusFilter>(
                value: statusFilter,
                items: const {
                  _StatusFilter.all: 'Todos los estados',
                  _StatusFilter.confirmed: 'Confirmados',
                  _StatusFilter.pending: 'Pendientes',
                  _StatusFilter.cancelled: 'Cancelados'
                },
                onChanged: onStatusChanged),
            _FilterMenu<_TimeFilter>(
                value: timeFilter,
                items: const {
                  _TimeFilter.all: 'Todas las fechas',
                  _TimeFilter.upcoming: 'Próximos',
                  _TimeFilter.past: 'Pasados',
                  _TimeFilter.thisMonth: 'Este mes'
                },
                onChanged: onTimeChanged),
            _FilterMenu<_SortOrder>(
                value: sortOrder,
                items: const {
                  _SortOrder.upcomingFirst: 'Próximos primero',
                  _SortOrder.dateAsc: 'Fecha ascendente',
                  _SortOrder.dateDesc: 'Fecha descendente',
                  _SortOrder.place: 'Lugar',
                  _SortOrder.priceAsc: 'Precio ascendente',
                  _SortOrder.priceDesc: 'Precio descendente'
                },
                onChanged: onSortChanged,
                icon: Icons.sort_rounded),
            if (isFiltered)
              TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Restablecer')),
          ]);
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 10), filters])
              : Row(children: [
                  Expanded(flex: 4, child: search),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: filters)
                ]);
        }),
        const SizedBox(height: 14),
        Text('$total ${total == 1 ? 'resultado' : 'resultados'}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF777482))),
      ]);
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu(
      {required this.value,
      required this.items,
      required this.onChanged,
      this.icon = Icons.filter_list_rounded});
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final IconData icon;
  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        tooltip: 'Filtrar',
        onSelected: onChanged,
        itemBuilder: (context) => items.entries
            .map((entry) => PopupMenuItem(
                value: entry.key,
                child: Row(children: [
                  if (entry.key == value)
                    const Icon(Icons.check_rounded,
                        size: 18, color: Color(0xFF6255E7))
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(entry.value)
                ])))
            .toList(),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE3E1E9)),
                borderRadius: BorderRadius.circular(11)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: const Color(0xFF6255E7)),
              const SizedBox(width: 7),
              Flexible(
                  child: Text(items[value]!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600))),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18)
            ])),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.concerts});
  final List<Concert> concerts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming =
        concerts.where((concert) => !concert.date.isBefore(today)).length;
    final confirmed = concerts
        .where((concert) => concert.status == ConcertStatus.confirmed)
        .length;
    final pending = concerts
        .where((concert) => concert.status == ConcertStatus.pending)
        .length;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 520
              ? 2
              : 1;
      final cards = [
        _SummaryItem(
            icon: Icons.mic_none_rounded,
            value: '${concerts.length}',
            label: 'Total conciertos',
            color: const Color(0xFF6255E7),
            background: const Color(0xFFEAE8FF)),
        _SummaryItem(
            icon: Icons.event_available_rounded,
            value: '$upcoming',
            label: 'Próximos',
            color: const Color(0xFF008D75),
            background: const Color(0xFFDDF7F1)),
        _SummaryItem(
            icon: Icons.check_circle_outline_rounded,
            value: '$confirmed',
            label: 'Confirmados',
            color: const Color(0xFF297CCB),
            background: const Color(0xFFE4F1FF)),
        _SummaryItem(
            icon: Icons.pending_actions_rounded,
            value: '$pending',
            label: 'Pendientes',
            color: const Color(0xFFB66A00),
            background: const Color(0xFFFFF1D9)),
      ];
      return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 4.5 : 3.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: cards);
    });
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color,
      required this.background});
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEAE9F0))),
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: background, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(width: 7),
          Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF777482))))
        ]),
      );
}

class _ConcertsTable extends StatelessWidget {
  const _ConcertsTable(
      {required this.concerts,
      required this.onEdit,
      required this.onDelete,
      required this.selectedConcert,
      required this.onSelect});
  final List<Concert> concerts;
  final ValueChanged<Concert> onEdit;
  final ValueChanged<Concert> onDelete;
  final Concert? selectedConcert;
  final ValueChanged<Concert> onSelect;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAE9F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08262335),
                  blurRadius: 14,
                  offset: Offset(0, 5))
            ]),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          const _TableHeader(),
          ...concerts.map((concert) => _TableRow(
              concert: concert,
              onEdit: onEdit,
              onDelete: onDelete,
              selected: selectedConcert?.id == concert.id,
              onSelect: onSelect)),
        ]),
      );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFAF9FC),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: const Row(children: [
          _ColumnHeader('FECHA', flex: 11),
          _ColumnHeader('HORA', flex: 7),
          _ColumnHeader('LUGAR', flex: 14),
          _ColumnHeader('ESTADO', flex: 10),
          _ColumnHeader('PRECIO', flex: 10),
          _ColumnHeader('CONTACTO', flex: 14),
          _ColumnHeader('UBICACIÓN', flex: 16),
          _ColumnHeader('COMENTARIOS', flex: 18),
          _ColumnHeader('ACCIONES', flex: 8, align: TextAlign.right),
        ]),
      );
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader(this.label,
      {required this.flex, this.align = TextAlign.left});
  final String label;
  final int flex;
  final TextAlign align;
  @override
  Widget build(BuildContext context) => Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
              color: Color(0xFF85818E))));
}

class _TableRow extends StatefulWidget {
  const _TableRow(
      {required this.concert,
      required this.onEdit,
      required this.onDelete,
      required this.selected,
      required this.onSelect});
  final Concert concert;
  final ValueChanged<Concert> onEdit;
  final ValueChanged<Concert> onDelete;
  final bool selected;
  final ValueChanged<Concert> onSelect;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
            onTap: () => widget.onSelect(widget.concert),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              color: widget.selected
                  ? const Color(0xFFF3F3F3)
                  : (_hovering ? const Color(0xFFF9F9F9) : Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(children: [
                Expanded(
                    flex: 11,
                    child: Text(
                        DateFormat('d MMM y', 'es_ES')
                            .format(widget.concert.date),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 7,
                    child: Text(widget.concert.time,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF595560)))),
                Expanded(
                    flex: 14,
                    child: Text(widget.concert.place,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 10,
                    child: _StatusChip(status: widget.concert.status)),
                Expanded(
                    flex: 10,
                    child: Text(_price(widget.concert.price),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 14, child: _ContactCell(concert: widget.concert)),
                Expanded(
                    flex: 16, child: _LocationCell(concert: widget.concert)),
                Expanded(
                    flex: 18,
                    child: Tooltip(
                        message: widget.concert.comments,
                        child: Text(
                            widget.concert.comments.isEmpty
                                ? '—'
                                : widget.concert.comments,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF777482))))),
                Expanded(
                    flex: 8,
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: _ActionMenu(
                            concert: widget.concert,
                            onEdit: widget.onEdit,
                            onDelete: widget.onDelete))),
              ]),
            )),
      );
}

class _ConcertCards extends StatelessWidget {
  const _ConcertCards(
      {required this.concerts,
      required this.onEdit,
      required this.onDelete,
      required this.onSelect});
  final List<Concert> concerts;
  final ValueChanged<Concert> onEdit;
  final ValueChanged<Concert> onDelete;
  final ValueChanged<Concert> onSelect;
  @override
  Widget build(BuildContext context) => Column(
      children: concerts
          .map((concert) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ConcertCard(
                  concert: concert,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onSelect: onSelect)))
          .toList());
}

class _ConcertCard extends StatelessWidget {
  const _ConcertCard(
      {required this.concert,
      required this.onEdit,
      required this.onDelete,
      required this.onSelect});
  final Concert concert;
  final ValueChanged<Concert> onEdit;
  final ValueChanged<Concert> onDelete;
  final ValueChanged<Concert> onSelect;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: () => onSelect(concert),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFEAE9F0))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _DateBadge(date: concert.date),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(concert.place,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800))),
                  _StatusChip(status: concert.status)
                ]),
                const SizedBox(height: 7),
                Text('${concert.time} · ${_price(concert.price)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF595560))),
                const SizedBox(height: 6),
                _WebPublicationChip(concert: concert),
                if (concert.hasContact)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          [concert.contactPerson, concert.contactPhone]
                              .where((value) => value.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF777482)))),
                if (concert.address.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(concert.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF777482)))),
                if (concert.hasLocation)
                  Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: OutlinedButton.icon(
                          onPressed: () =>
                              ConcertActions.openLocation(context, concert),
                          icon: const Icon(Icons.map_outlined, size: 17),
                          label: const Text('Abrir mapa'))),
                if (concert.comments.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(concert.comments,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF777482)))),
              ])),
          _ActionMenu(concert: concert, onEdit: onEdit, onDelete: onDelete),
        ]),
      ));
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) => Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
          color: const Color(0xFFEFEEFF),
          borderRadius: BorderRadius.circular(11)),
      child: Column(children: [
        Text('${date.day}',
            style: const TextStyle(
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Color(0xFF584CCF))),
        const SizedBox(height: 3),
        Text(DateFormat('MMM', 'es_ES').format(date).toUpperCase(),
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF756DCC)))
      ]));
}

class _WebPublicationChip extends StatelessWidget {
  const _WebPublicationChip({required this.concert});
  final Concert concert;

  @override
  Widget build(BuildContext context) {
    final (label, color) = !concert.isPublishedOnWeb
        ? ('No publicado', AppColors.textSecondary)
        : concert.hasUnpublishedChanges
            ? ('Cambios sin publicar', AppColors.warningText)
            : ('Publicado', AppColors.successText);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

Future<void> _showWebPreview(BuildContext context, Concert concert) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vista previa web'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('d MMMM', 'es_ES')
                    .format(concert.date)
                    .toUpperCase(),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '📍${concert.publicVenue.isEmpty ? concert.place : concert.publicVenue}'
                '${concert.city.isEmpty ? '' : ', ${concert.city}'}'
                ' — ${concert.publicTime.isEmpty ? concert.time : concert.publicTime}h',
              ),
              if (concert.ticketType != 'unavailable') ...[
                const SizedBox(height: 12),
                Text(
                  switch (concert.ticketType) {
                    'free' => 'ENTRADA GRATUITA',
                    'ticketed' => 'COMPRAR ENTRADAS',
                    'invitation' => concert.ticketLabel.isEmpty
                        ? 'MÁS INFORMACIÓN'
                        : concert.ticketLabel.toUpperCase(),
                    'sold_out' => 'ENTRADAS AGOTADAS',
                    _ => '',
                  },
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

class _ActionMenu extends StatelessWidget {
  const _ActionMenu(
      {required this.concert, required this.onEdit, required this.onDelete});
  final Concert concert;
  final ValueChanged<Concert> onEdit;
  final ValueChanged<Concert> onDelete;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF777482)),
        tooltip: 'Acciones',
        onSelected: (value) {
          if (value == 'edit') {
            onEdit(concert);
          }
          if (value == 'delete') {
            onDelete(concert);
          }
          if (value == 'phone') {
            ConcertActions.copyPhone(context, concert.contactPhone);
          }
          if (value == 'map') {
            ConcertActions.openLocation(context, concert);
          }
          if (value == 'manage_web') {
            onEdit(concert);
          }
          if (value == 'preview_web') {
            _showWebPreview(context, concert);
          }
          if (value == 'open_web') {
            ConcertActions.openUrl(
              context,
              'https://vaderumba.es/#conciertos',
            );
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 9),
                Text('Ver o editar')
              ])),
          PopupMenuItem(
              value: 'manage_web',
              child: Row(children: [
                const Icon(Icons.public_rounded, size: 18),
                const SizedBox(width: 9),
                Text(concert.isPublishedOnWeb
                    ? 'Actualizar o retirar publicación'
                    : 'Publicar en la web')
              ])),
          if (concert.isPublishedOnWeb) ...[
            const PopupMenuItem(
                value: 'preview_web',
                child: Row(children: [
                  Icon(Icons.preview_outlined, size: 18),
                  SizedBox(width: 9),
                  Text('Vista previa web')
                ])),
            const PopupMenuItem(
                value: 'open_web',
                child: Row(children: [
                  Icon(Icons.open_in_new, size: 18),
                  SizedBox(width: 9),
                  Text('Abrir en la web')
                ])),
          ],
          const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFFBE4858)),
                SizedBox(width: 9),
                Text('Eliminar')
              ])),
          if (concert.contactPhone.isNotEmpty)
            const PopupMenuItem(
                value: 'phone',
                child: Row(children: [
                  Icon(Icons.content_copy_rounded, size: 18),
                  SizedBox(width: 9),
                  Text('Copiar teléfono')
                ])),
          if (concert.hasLocation)
            const PopupMenuItem(
                value: 'map',
                child: Row(children: [
                  Icon(Icons.map_outlined, size: 18),
                  SizedBox(width: 9),
                  Text('Abrir mapa')
                ])),
        ],
      );
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({required this.concert});
  final Concert concert;
  @override
  Widget build(BuildContext context) {
    if (!concert.hasContact) {
      return const Text('—', style: TextStyle(color: Color(0xFF777482)));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (concert.contactPerson.isNotEmpty)
            Text(concert.contactPerson,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          if (concert.contactPhone.isNotEmpty)
            InkWell(
                onTap: () =>
                    ConcertActions.copyPhone(context, concert.contactPhone),
                child: Text(concert.contactPhone,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6255E7)))),
        ]);
  }
}

class _LocationCell extends StatelessWidget {
  const _LocationCell({required this.concert});
  final Concert concert;
  @override
  Widget build(BuildContext context) {
    if (!concert.hasLocation) {
      return const Text('—', style: TextStyle(color: Color(0xFF777482)));
    }
    return Row(children: [
      Expanded(
          child: Tooltip(
              message: concert.address,
              child: Text(
                  concert.address.isEmpty ? 'Enlace de mapas' : concert.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF595560))))),
      IconButton(
          tooltip: 'Abrir mapa',
          onPressed: () => ConcertActions.openLocation(context, concert),
          icon: const Icon(Icons.map_outlined, size: 18)),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ConcertStatus status;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConcertStatus.pending => ('Pendiente', const Color(0xFFE49B27)),
      ConcertStatus.confirmed => ('Confirmado', const Color(0xFF25A978)),
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

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.onCreate});
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) => _EmptyPanel(
      icon: Icons.event_available_outlined,
      title: 'Todavía no hay conciertos',
      detail: 'Crea el primero para empezar a organizar la agenda.',
      action: onCreate == null
          ? null
          : FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear primer concierto')));
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => _EmptyPanel(
      icon: Icons.search_off_rounded,
      title: 'No hay resultados',
      detail: 'Prueba a cambiar la búsqueda o los filtros aplicados.',
      action: OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Restablecer filtros')));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(
      {required this.icon,
      required this.title,
      required this.detail,
      required this.action});
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAE9F0))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: const Color(0xFF8E87D8)),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF777482))),
        if (action != null) ...[
          const SizedBox(height: 18),
          action!,
        ],
      ]));
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: _EmptyPanel(
          icon: Icons.cloud_off_rounded,
          title: 'No se han podido cargar los conciertos',
          detail: 'Comprueba tu conexión e inténtalo de nuevo.',
          action: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'))));
}

String _price(double? value) => value == null
    ? 'Precio pendiente'
    : NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0)
        .format(value);

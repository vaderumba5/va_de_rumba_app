import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/concert.dart';
import '../services/firestore_concert_repository.dart';
import 'concert_form_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.embedded = false});

  /// When rendered inside [MainScreen], navigation controls are supplied by
  /// the shared application shell.
  final bool embedded;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final repo = FirestoreConcertRepository();
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();
  List<Concert> concerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await repo.getAll();
    setState(() => concerts = data);
  }

  List<Concert> forDay(DateTime day) => concerts
      .where(
        (c) => isSameDay(c.date, day),
      )
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));

  Future<void> _add() async {
    final result = await Navigator.push<Concert>(
      context,
      MaterialPageRoute(
          builder: (_) => ConcertFormScreen(
                initialDate: selectedDay,
                repository: repo,
              )),
    );
    if (result != null) {
      await repo.createConcert(result);
      await _load();
    }
  }

  Future<void> _edit(Concert concert) async {
    final result = await Navigator.push<Concert>(
      context,
      MaterialPageRoute(
          builder: (_) => ConcertFormScreen(
                initialDate: concert.date,
                concert: concert,
                repository: repo,
              )),
    );
    if (result != null) {
      await repo.updateConcert(result);
      await _load();
    }
  }

  Future<void> _delete(Concert concert) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar concierto'),
        content: Text('¿Eliminar el concierto de ${concert.place}?'),
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
    if (ok == true) {
      await repo.deleteConcert(concert.id);
      await _load();
    }
  }

  Color statusColor(ConcertStatus s) {
    switch (s) {
      case ConcertStatus.confirmed:
        return Colors.green;
      case ConcertStatus.cancelled:
        return Colors.red;
      case ConcertStatus.pending:
        return Colors.orange;
    }
  }

  String statusText(ConcertStatus s) {
    switch (s) {
      case ConcertStatus.confirmed:
        return 'Confirmado';
      case ConcertStatus.cancelled:
        return 'Cancelado';
      case ConcertStatus.pending:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayConcerts = forDay(selectedDay);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: widget.embedded
          ? null
          : AppBar(
              toolbarHeight: 72,
              elevation: 0,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VA DE RUMBA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Gestión de conciertos',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo concierto'),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo concierto'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(24, 24, 24, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9E8F0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0A262335),
                    blurRadius: 20,
                    offset: Offset(0, 8))
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: TableCalendar<Concert>(
                locale: 'es_ES',
                firstDay: DateTime.utc(2020),
                lastDay: DateTime.utc(2040),
                focusedDay: focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, selectedDay),
                eventLoader: forDay,
                calendarFormat: CalendarFormat.month,
                onDaySelected: (selected, focused) => setState(() {
                  selectedDay = selected;
                  focusedDay = focused;
                }),
                onPageChanged: (focused) => focusedDay = focused,
                calendarBuilders: CalendarBuilders(
                  selectedBuilder: (context, day, focusedDay) =>
                      AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    margin: const EdgeInsets.all(3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color(0xFF6255E7),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x446255E7),
                              blurRadius: 8,
                              offset: Offset(0, 3))
                        ]),
                    child: Text('${day.day}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                          width: 15,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                              color: isSameDay(day, selectedDay)
                                  ? Colors.white
                                  : const Color(0xFF6255E7),
                              borderRadius: BorderRadius.circular(8))),
                    );
                  },
                ),
                headerStyle: const HeaderStyle(
                  titleCentered: false,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF292632)),
                  leftChevronIcon: Icon(Icons.chevron_left_rounded,
                      color: Color(0xFF6255E7)),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF6255E7)),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF85818E)),
                  weekendStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF85818E)),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF413D48)),
                  weekendTextStyle: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF413D48)),
                  outsideTextStyle: const TextStyle(color: Color(0xFFC5C2CC)),
                  markerSize: 6,
                  markersMaxCount: 3,
                  markerDecoration: const BoxDecoration(
                      color: Color(0xFF6255E7), shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(
                      color: const Color(0xFFE9E7FF),
                      borderRadius: BorderRadius.circular(10)),
                  todayTextStyle: const TextStyle(
                      color: Color(0xFF6255E7), fontWeight: FontWeight.w800),
                  selectedDecoration: BoxDecoration(
                      color: const Color(0xFF6255E7),
                      borderRadius: BorderRadius.circular(10)),
                  selectedTextStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                  cellMargin: const EdgeInsets.all(3),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 16, 30, 12),
            child: Row(
              children: [
                Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                        color: const Color(0xFF6255E7),
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Text(
                  DateFormat("EEEE d 'de' MMMM", 'es_ES').format(selectedDay),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: dayConcerts.isEmpty
                  ? const Center(
                      child: _EmptyConcertState(),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      itemCount: dayConcerts.length,
                      itemBuilder: (_, i) {
                        final c = dayConcerts[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE9E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x08262335),
                                  blurRadius: 14,
                                  offset: Offset(0, 5))
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _edit(c),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 10, 14),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        width: 52,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 9),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFF0EFFF),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Text(c.time,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF584CCF)))),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Row(children: [
                                            Expanded(
                                                child: Text(c.place,
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(
                                                            0xFF302D38)))),
                                            _ConcertStatusChip(
                                                label: statusText(c.status),
                                                color: statusColor(c.status)),
                                          ]),
                                          if (c.price != null ||
                                              c.comments.isNotEmpty)
                                            const SizedBox(height: 7),
                                          if (c.price != null)
                                            Row(children: [
                                              const Icon(
                                                  Icons.payments_outlined,
                                                  size: 15,
                                                  color: Color(0xFF85818E)),
                                              const SizedBox(width: 5),
                                              Text(
                                                  '${c.price!.toStringAsFixed(0)} €',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF595560)))
                                            ]),
                                          if (c.comments.isNotEmpty)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 5),
                                                child: Text(c.comments,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                            0xFF777482)))),
                                        ])),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_horiz_rounded,
                                          color: Color(0xFF777482)),
                                      onSelected: (v) {
                                        if (v == 'edit') _edit(c);
                                        if (v == 'delete') _delete(c);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Eliminar'))
                                      ],
                                    ),
                                  ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConcertState extends StatelessWidget {
  const _EmptyConcertState();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(26),
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
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_available_outlined,
              size: 36, color: Color(0xFF8E87D8)),
          SizedBox(height: 11),
          Text('Agenda despejada',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF413D48))),
          SizedBox(height: 5),
          Text('No hay conciertos programados este día.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF777482))),
        ]),
      );
}

class _ConcertStatusChip extends StatelessWidget {
  const _ConcertStatusChip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );
}

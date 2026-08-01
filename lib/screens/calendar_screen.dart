import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/concert.dart';
import '../services/firestore_concert_repository.dart';
import 'concert_form_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
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

  List<Concert> forDay(DateTime day) => concerts.where(
    (c) => isSameDay(c.date, day),
  ).toList()..sort((a,b) => a.time.compareTo(b.time));

  Future<void> _add() async {
    final result = await Navigator.push<Concert>(
      context,
      MaterialPageRoute(builder: (_) => ConcertFormScreen(
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
      MaterialPageRoute(builder: (_) => ConcertFormScreen(
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
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
      case ConcertStatus.confirmed: return Colors.green;
      case ConcertStatus.cancelled: return Colors.red;
      case ConcertStatus.pending: return Colors.orange;
    }
  }

  String statusText(ConcertStatus s) {
    switch (s) {
      case ConcertStatus.confirmed: return 'Confirmado';
      case ConcertStatus.cancelled: return 'Cancelado';
      case ConcertStatus.pending: return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayConcerts = forDay(selectedDay);
    return Scaffold(
      appBar: AppBar(
        title: const Text('VA DE RUMBA', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Añadir concierto',
            onPressed: _add,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Concierto'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Padding(
              padding: const EdgeInsets.all(8),
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
                calendarStyle: const CalendarStyle(
                  markerSize: 7,
                  markersMaxCount: 3,
                  todayDecoration: BoxDecoration(
                    color: Color(0xFF9C4DCC),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Color(0xFF7B1FA2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Row(
              children: [
                Text(
                  DateFormat("EEEE d 'de' MMMM", 'es_ES').format(selectedDay),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: dayConcerts.isEmpty
              ? const Center(
                  child: Text('No hay conciertos este día',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: dayConcerts.length,
                  itemBuilder: (_, i) {
                    final c = dayConcerts[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _edit(c),
                        leading: CircleAvatar(
                          backgroundColor: statusColor(c.status).withOpacity(.15),
                          child: Icon(Icons.music_note, color: statusColor(c.status)),
                        ),
                        title: Text(c.place, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${c.time}  •  ${statusText(c.status)}'
                          '${c.price != null ? '  •  ${c.price!.toStringAsFixed(0)} €' : ''}'
                          '${c.comments.isNotEmpty ? '\n${c.comments}' : ''}',
                        ),
                        isThreeLine: c.comments.isNotEmpty,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _edit(c);
                            if (v == 'delete') _delete(c);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/concert.dart';
import '../services/firestore_concert_repository.dart';

class ConcertFormScreen extends StatefulWidget {
  final DateTime initialDate;
  final Concert? concert;
  final FirestoreConcertRepository repository;

  const ConcertFormScreen({
    super.key,
    required this.initialDate,
    required this.repository,
    this.concert,
  });

  @override
  State<ConcertFormScreen> createState() => _ConcertFormScreenState();
}

class _ConcertFormScreenState extends State<ConcertFormScreen> {
  late DateTime date;
  late TimeOfDay time;
  late TextEditingController place;
  late TextEditingController price;
  late TextEditingController comments;
  ConcertStatus status = ConcertStatus.pending;

  @override
  void initState() {
    super.initState();
    final c = widget.concert;
    date = c?.date ?? widget.initialDate;
    final parts = (c?.time ?? '23:00').split(':');
    time = TimeOfDay(hour: int.tryParse(parts[0]) ?? 23, minute: int.tryParse(parts[1]) ?? 0);
    place = TextEditingController(text: c?.place ?? '');
    price = TextEditingController(text: c?.price?.toString() ?? '');
    comments = TextEditingController(text: c?.comments ?? '');
    status = c?.status ?? ConcertStatus.pending;
  }

  @override
  void dispose() {
    place.dispose(); price.dispose(); comments.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      initialDate: date,
      locale: const Locale('es', 'ES'),
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> pickTime() async {
    final t = await showTimePicker(context: context, initialTime: time);
    if (t != null) setState(() => time = t);
  }

  void save() {
    if (place.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica el lugar del concierto')),
      );
      return;
    }
    final p = double.tryParse(price.text.replaceAll(',', '.'));
    final concert = Concert(
      id: widget.concert?.id ?? widget.repository.newId(),
      date: date,
      time: '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}',
      place: place.text.trim(),
      price: p,
      comments: comments.text.trim(),
      status: status,
    );
    Navigator.pop(context, concert);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.concert != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar concierto' : 'Nuevo concierto')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: place,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Lugar',
              hintText: 'Ej. Masía, sala, plaza...',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text('${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}'),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(
              onPressed: pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(time.format(context)),
            )),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio / caché (€)',
              prefixIcon: Icon(Icons.euro),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<ConcertStatus>(
            value: status,
            decoration: const InputDecoration(
              labelText: 'Estado',
              prefixIcon: Icon(Icons.flag_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: ConcertStatus.pending, child: Text('Pendiente')),
              DropdownMenuItem(value: ConcertStatus.confirmed, child: Text('Confirmado')),
              DropdownMenuItem(value: ConcertStatus.cancelled, child: Text('Cancelado')),
            ],
            onChanged: (v) => setState(() => status = v ?? ConcertStatus.pending),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: comments,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comentarios',
              hintText: 'Montaje, contacto, equipo, condiciones...',
              prefixIcon: Icon(Icons.notes_outlined),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check),
              label: Text(editing ? 'Guardar cambios' : 'Guardar concierto'),
            ),
          ),
        ],
      ),
    );
  }
}

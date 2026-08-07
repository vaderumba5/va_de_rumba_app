import 'package:flutter/material.dart';
import '../models/concert.dart';
import '../services/firestore_concert_repository.dart';
import '../utils/concert_actions.dart';
import '../models/app_permission.dart';
import '../models/setlist.dart';
import '../providers/current_user_scope.dart';
import '../services/setlist_repository.dart';

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
  late TextEditingController contactPerson;
  late TextEditingController contactPhone;
  late TextEditingController address;
  late TextEditingController publicTitle;
  late TextEditingController publicTime;
  late TextEditingController publicVenue;
  late TextEditingController publicCity;
  late TextEditingController publicLocation;
  late TextEditingController ticketUrl;
  late TextEditingController ticketLabel;
  late TextEditingController publicDescription;
  late TextEditingController posterUrl;
  ConcertStatus status = ConcertStatus.pending;
  late String setlistId;
  late bool isPublishedOnWeb;
  late bool featured;
  late String ticketType;
  late String publicStatus;

  @override
  void initState() {
    super.initState();
    final c = widget.concert;
    date = c?.date ?? widget.initialDate;
    final parts = (c?.time ?? '23:00').split(':');
    time = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 23,
        minute: int.tryParse(parts[1]) ?? 0);
    place = TextEditingController(text: c?.place ?? '');
    price = TextEditingController(text: c?.price?.toString() ?? '');
    comments = TextEditingController(text: c?.comments ?? '');
    contactPerson = TextEditingController(text: c?.contactPerson ?? '');
    contactPhone = TextEditingController(text: c?.contactPhone ?? '');
    address = TextEditingController(text: c?.address ?? '');
    status = c?.status ?? ConcertStatus.pending;
    setlistId = c?.setlistId ?? '';
    isPublishedOnWeb = c?.isPublishedOnWeb ?? false;
    featured = c?.featured ?? false;
    ticketType = c?.ticketType ?? 'unavailable';
    publicStatus = c?.publicStatus ?? 'scheduled';
    publicTitle = TextEditingController(text: c?.publicTitle ?? '');
    publicTime = TextEditingController(text: c?.publicTime ?? '');
    publicVenue = TextEditingController(text: c?.publicVenue ?? '');
    publicCity = TextEditingController(text: c?.city ?? '');
    publicLocation = TextEditingController(text: c?.publicLocation ?? '');
    ticketUrl = TextEditingController(text: c?.ticketUrl ?? '');
    ticketLabel = TextEditingController(text: c?.ticketLabel ?? '');
    publicDescription = TextEditingController(text: c?.publicDescription ?? '');
    posterUrl = TextEditingController(text: c?.posterUrl ?? '');
  }

  @override
  void dispose() {
    place.dispose();
    price.dispose();
    comments.dispose();
    contactPerson.dispose();
    contactPhone.dispose();
    address.dispose();
    publicTitle.dispose();
    publicTime.dispose();
    publicVenue.dispose();
    publicCity.dispose();
    publicLocation.dispose();
    ticketUrl.dispose();
    ticketLabel.dispose();
    publicDescription.dispose();
    posterUrl.dispose();
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
    debugPrint(
        '[ConcertFormScreen] Validando ${widget.concert == null ? 'creación' : 'edición'}');
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
      time:
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      place: place.text.trim(),
      price: p,
      comments: comments.text.trim(),
      status: status,
      contactPerson: contactPerson.text.trim(),
      contactPhone: contactPhone.text.trim(),
      address: address.text.trim(),
      mapsUrl: widget.concert?.mapsUrl ?? '',
      venueName: widget.concert?.venueName ?? place.text.trim(),
      googlePlaceId: widget.concert?.googlePlaceId ?? '',
      latitude: widget.concert?.latitude,
      longitude: widget.concert?.longitude,
      municipality: widget.concert?.municipality ?? '',
      organizer: widget.concert?.organizer ?? '',
      contactEmail: widget.concert?.contactEmail ?? '',
      setupTime: widget.concert?.setupTime ?? '',
      parkingNotes: widget.concert?.parkingNotes ?? '',
      setlistId: setlistId,
      isPublishedOnWeb: isPublishedOnWeb,
      publishedAt: widget.concert?.publishedAt,
      publicUpdatedAt: widget.concert?.publicUpdatedAt,
      updatedAt: widget.concert?.updatedAt,
      publishedBy: widget.concert?.publishedBy,
      publicTitle: publicTitle.text.trim(),
      publicTime: publicTime.text.trim(),
      publicVenue: publicVenue.text.trim(),
      city: publicCity.text.trim(),
      province: widget.concert?.province ?? '',
      publicLocation: publicLocation.text.trim(),
      ticketType: ticketType,
      ticketUrl: ticketUrl.text.trim(),
      ticketLabel: ticketLabel.text.trim(),
      publicDescription: publicDescription.text.trim(),
      posterUrl: posterUrl.text.trim(),
      featured: featured,
      publicStatus: publicStatus,
    );
    debugPrint(
        '[ConcertFormScreen] Devolviendo concierto ${concert.id} al llamador');
    Navigator.pop(context, concert);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.concert != null;
    return Scaffold(
      appBar:
          AppBar(title: Text(editing ? 'Editar concierto' : 'Nuevo concierto')),
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
            Expanded(
                child: OutlinedButton.icon(
              onPressed: pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton.icon(
              onPressed: pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(time.format(context)),
            )),
          ]),
          const SizedBox(height: 14),
          if (CurrentUserScope.authorization.canViewModule(
            CurrentUserScope.of(context),
            AppModules.repertoire,
          )) ...[
            const Text('Repertorio del concierto',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            StreamBuilder<List<SetlistModel>>(
              stream: SetlistRepository().watchSetlists(),
              builder: (context, snapshot) {
                final setlists = snapshot.data ?? const <SetlistModel>[];
                final availableIds =
                    setlists.map((setlist) => setlist.id).toSet();
                final selected =
                    availableIds.contains(setlistId) ? setlistId : '';
                return DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Repertorio asignado',
                    prefixIcon: Icon(Icons.queue_music_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Sin repertorio asignado'),
                    ),
                    ...setlists.map(
                      (setlist) => DropdownMenuItem(
                        value: setlist.id,
                        child: Text(setlist.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => setlistId = value ?? ''),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
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
            initialValue: status,
            decoration: const InputDecoration(
              labelText: 'Estado',
              prefixIcon: Icon(Icons.flag_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: ConcertStatus.pending, child: Text('Pendiente')),
              DropdownMenuItem(
                  value: ConcertStatus.confirmed, child: Text('Confirmado')),
              DropdownMenuItem(
                  value: ConcertStatus.reserved, child: Text('Reservado')),
              DropdownMenuItem(
                  value: ConcertStatus.cancelled, child: Text('Cancelado')),
            ],
            onChanged: (v) =>
                setState(() => status = v ?? ConcertStatus.pending),
          ),
          const SizedBox(height: 14),
          if (CurrentUserScope.authorization.canManageModule(
            CurrentUserScope.of(context),
            AppModules.concerts,
          )) ...[
            const SizedBox(height: 12),
            const Text('Publicación web',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicar en la web'),
              subtitle: Text(isPublishedOnWeb
                  ? 'Este concierto está publicado en vaderumba.es'
                  : 'Solo será visible dentro de la app'),
              value: isPublishedOnWeb,
              onChanged: (value) => setState(() => isPublishedOnWeb = value),
            ),
            if (isPublishedOnWeb) ...[
              TextField(
                controller: publicTitle,
                decoration: const InputDecoration(
                  labelText: 'Título público',
                  helperText: 'Si se deja vacío se utilizará el lugar.',
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: publicVenue,
                    decoration:
                        const InputDecoration(labelText: 'Recinto público'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: publicCity,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: publicTime,
                    decoration: const InputDecoration(
                      labelText: 'Hora pública',
                      hintText: '23:30',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: publicStatus,
                    decoration:
                        const InputDecoration(labelText: 'Estado público'),
                    items: const [
                      DropdownMenuItem(
                          value: 'scheduled', child: Text('Programado')),
                      DropdownMenuItem(
                          value: 'postponed', child: Text('Aplazado')),
                      DropdownMenuItem(
                          value: 'cancelled', child: Text('Cancelado')),
                    ],
                    onChanged: (value) =>
                        setState(() => publicStatus = value ?? publicStatus),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: publicLocation,
                decoration:
                    const InputDecoration(labelText: 'Ubicación pública'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: ticketType,
                decoration: const InputDecoration(labelText: 'Entradas'),
                items: const [
                  DropdownMenuItem(
                      value: 'free', child: Text('Entrada gratuita')),
                  DropdownMenuItem(
                      value: 'ticketed', child: Text('Comprar entradas')),
                  DropdownMenuItem(
                      value: 'invitation', child: Text('Más información')),
                  DropdownMenuItem(
                      value: 'sold_out', child: Text('Entradas agotadas')),
                  DropdownMenuItem(
                      value: 'unavailable', child: Text('Sin botón')),
                ],
                onChanged: (value) =>
                    setState(() => ticketType = value ?? ticketType),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: ticketUrl,
                    decoration:
                        const InputDecoration(labelText: 'URL de entradas'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: ticketLabel,
                    decoration:
                        const InputDecoration(labelText: 'Texto del botón'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: publicDescription,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Descripción pública'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: posterUrl,
                decoration: const InputDecoration(labelText: 'URL del cartel'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Concierto destacado'),
                value: featured,
                onChanged: (value) => setState(() => featured = value),
              ),
            ],
          ],
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
          const SizedBox(height: 28),
          const Text('Contacto y localización',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            controller: contactPerson,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Persona de contacto',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: contactPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              helperText: 'Número del promotor o responsable del evento',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: address,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Ubicación',
              hintText: 'Nombre del local o dirección',
              helperText: 'La dirección se guarda al guardar el concierto',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => ConcertActions.searchLocationInGoogleMaps(
                  context, address.text),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Buscar en Google Maps'),
            ),
          ),
          const SizedBox(height: 14),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/concert.dart';
import '../services/firestore_concert_repository.dart';
import '../utils/concert_actions.dart';

class PublicConcertsScreen extends StatefulWidget {
  const PublicConcertsScreen({super.key});

  @override
  State<PublicConcertsScreen> createState() => _PublicConcertsScreenState();
}

class _PublicConcertsScreenState extends State<PublicConcertsScreen> {
  final _repository = FirestoreConcertRepository();
  String? _savingId;

  Future<void> _configure(Concert concert) async {
    final result = await showDialog<Concert>(
      context: context,
      builder: (_) => _PublicConcertDialog(concert: concert),
    );
    if (result == null || !mounted) return;

    setState(() => _savingId = concert.id);
    try {
      await _repository.publishConcert(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(concert.isPublishedOnWeb
                ? 'Publicación actualizada.'
                : 'Concierto publicado en la web.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo publicar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _unpublish(Concert concert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar de la web'),
        content: Text(
          '¿Quieres retirar “${concert.publicTitle.isEmpty ? concert.place : concert.publicTitle}” de vaderumba.es?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _savingId = concert.id);
    try {
      await _repository.unpublishConcert(concert);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Concierto retirado de la web.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo retirar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Concert>>(
      stream: _repository.streamConcerts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child:
                Text('No se pudieron cargar los conciertos: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final concerts = [...snapshot.data!]
          ..sort((a, b) => a.date.compareTo(b.date));
        final published =
            concerts.where((concert) => concert.isPublishedOnWeb).length;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _SummaryCard(published: published, total: concerts.length),
            const SizedBox(height: 20),
            if (concerts.isEmpty)
              const _EmptyState()
            else
              ...concerts.map(
                (concert) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ConcertPublicationCard(
                    concert: concert,
                    saving: _savingId == concert.id,
                    onConfigure: () => _configure(concert),
                    onUnpublish: () => _unpublish(concert),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.published, required this.total});

  final int published;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE9F7EF),
            child: Icon(Icons.public_rounded, color: Color(0xFF247A47)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conciertos visibles en vaderumba.es',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$published publicados de $total conciertos. Los datos privados nunca se envían a la web.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcertPublicationCard extends StatelessWidget {
  const _ConcertPublicationCard({
    required this.concert,
    required this.saving,
    required this.onConfigure,
    required this.onUnpublish,
  });

  final Concert concert;
  final bool saving;
  final VoidCallback onConfigure;
  final VoidCallback onUnpublish;

  @override
  Widget build(BuildContext context) {
    final published = concert.isPublishedOnWeb;
    final title =
        concert.publicTitle.isEmpty ? concert.place : concert.publicTitle;
    final ticket = switch (concert.ticketType) {
      'free' => 'Entrada gratuita',
      'ticketed' => 'Venta de entradas',
      _ => 'Sin entrada configurada',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              published ? Icons.public_rounded : Icons.public_off_outlined,
              color:
                  published ? const Color(0xFF247A47) : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(concert.date)} · ${concert.time} · ${concert.place}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: published ? 'Publicado' : 'No publicado',
                        positive: published,
                      ),
                      if (published) _StatusChip(label: ticket),
                      if (concert.hasUnpublishedChanges)
                        const _StatusChip(label: 'Cambios sin publicar'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (saving)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  if (published)
                    IconButton(
                      tooltip: 'Abrir vaderumba.es',
                      onPressed: () => ConcertActions.openUrl(
                          context, 'https://vaderumba.es/#conciertos'),
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  OutlinedButton.icon(
                    onPressed: onConfigure,
                    icon: Icon(published ? Icons.edit_outlined : Icons.publish),
                    label: Text(published ? 'Editar publicación' : 'Publicar'),
                  ),
                  if (published)
                    TextButton(
                      onPressed: onUnpublish,
                      child: const Text('Retirar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.positive = false});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFE9F7EF) : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: positive ? const Color(0xFF247A47) : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 48),
          SizedBox(height: 12),
          Text('Todavía no hay conciertos para publicar.'),
        ],
      ),
    );
  }
}

class _PublicConcertDialog extends StatefulWidget {
  const _PublicConcertDialog({required this.concert});

  final Concert concert;

  @override
  State<_PublicConcertDialog> createState() => _PublicConcertDialogState();
}

class _PublicConcertDialogState extends State<_PublicConcertDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _venue;
  late final TextEditingController _city;
  late final TextEditingController _location;
  late final TextEditingController _time;
  late final TextEditingController _ticketUrl;
  late final TextEditingController _ticketLabel;
  late String _ticketType;

  @override
  void initState() {
    super.initState();
    final concert = widget.concert;
    _title = TextEditingController(text: concert.publicTitle);
    _venue = TextEditingController(
        text:
            concert.publicVenue.isEmpty ? concert.place : concert.publicVenue);
    _city = TextEditingController(text: concert.city);
    _location = TextEditingController(text: concert.publicLocation);
    _time = TextEditingController(
        text: concert.publicTime.isEmpty ? concert.time : concert.publicTime);
    _ticketUrl = TextEditingController(text: concert.ticketUrl);
    _ticketLabel = TextEditingController(text: concert.ticketLabel);
    _ticketType = const {'free', 'ticketed'}.contains(concert.ticketType)
        ? concert.ticketType
        : 'free';
  }

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _city.dispose();
    _location.dispose();
    _time.dispose();
    _ticketUrl.dispose();
    _ticketLabel.dispose();
    super.dispose();
  }

  bool _isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      widget.concert.copyWith(
        isPublishedOnWeb: true,
        publicTitle: _title.text.trim(),
        publicVenue: _venue.text.trim(),
        city: _city.text.trim(),
        publicLocation: _location.text.trim(),
        publicTime: _time.text.trim(),
        ticketType: _ticketType,
        ticketUrl: _ticketType == 'ticketed' ? _ticketUrl.text.trim() : '',
        ticketLabel: _ticketLabel.text.trim(),
        publicStatus: 'scheduled',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.concert.isPublishedOnWeb
          ? 'Editar publicación'
          : 'Publicar concierto'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Título público',
                    hintText: 'Concierto Va de Rumba',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _venue,
                  decoration:
                      const InputDecoration(labelText: 'Recinto o evento'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Indica dónde será el concierto.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _city,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _time,
                        decoration: const InputDecoration(
                          labelText: 'Hora',
                          hintText: '20:30',
                        ),
                        validator: (value) => !RegExp(
                          r'^([01]\d|2[0-3]):[0-5]\d$',
                        ).hasMatch(value?.trim() ?? '')
                            ? 'Usa el formato HH:mm.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación pública',
                    helperText: 'Opcional. Si se omite se usará el recinto.',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'free',
                      icon: Icon(Icons.celebration_outlined),
                      label: Text('Entrada gratuita'),
                    ),
                    ButtonSegment(
                      value: 'ticketed',
                      icon: Icon(Icons.confirmation_number_outlined),
                      label: Text('Comprar entrada'),
                    ),
                  ],
                  selected: {_ticketType},
                  onSelectionChanged: (values) =>
                      setState(() => _ticketType = values.first),
                ),
                if (_ticketType == 'ticketed') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ticketUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Enlace para comprar entradas',
                      hintText: 'https://...',
                    ),
                    validator: (value) => !_isValidUrl(value ?? '')
                        ? 'Introduce un enlace http o https válido.'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ticketLabel,
                  decoration: InputDecoration(
                    labelText: 'Texto mostrado',
                    hintText: _ticketType == 'free'
                        ? 'ENTRADA GRATUITA'
                        : 'COMPRAR ENTRADAS',
                  ),
                ),
              ],
            ),
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
          icon: const Icon(Icons.public_rounded),
          label: Text(
              widget.concert.isPublishedOnWeb ? 'Actualizar web' : 'Publicar'),
        ),
      ],
    );
  }
}

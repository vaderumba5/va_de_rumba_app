import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_permission.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import '../providers/current_user_scope.dart';
import '../services/setlist_repository.dart';
import '../services/song_repository.dart';

enum _SongFilter { all, active, archived, open, capo }

class RepertoireScreen extends StatefulWidget {
  const RepertoireScreen({super.key});

  @override
  State<RepertoireScreen> createState() => _RepertoireScreenState();
}

class _RepertoireScreenState extends State<RepertoireScreen>
    with SingleTickerProviderStateMixin {
  final _songs = SongRepository();
  final _setlists = SetlistRepository();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = CurrentUserScope.of(context);
    final canManage = CurrentUserScope.authorization
        .canManageModule(user, AppModules.repertoire);
    return Column(
      children: [
        Material(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Canciones', icon: Icon(Icons.music_note_rounded)),
              Tab(text: 'Repertorios', icon: Icon(Icons.queue_music_rounded)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _SongsView(repository: _songs, canManage: canManage),
              _SetlistsView(
                songRepository: _songs,
                repository: _setlists,
                canManage: canManage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SongsView extends StatefulWidget {
  const _SongsView({required this.repository, required this.canManage});
  final SongRepository repository;
  final bool canManage;

  @override
  State<_SongsView> createState() => _SongsViewState();
}

class _SongsViewState extends State<_SongsView> {
  final _search = TextEditingController();
  _SongFilter _filter = _SongFilter.all;
  String? _category;
  bool _savingOrder = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SongModel> _visible(List<SongModel> songs) {
    final query = normalizeSongSearch(_search.text);
    return songs.where((song) {
      final haystack = normalizeSongSearch(
        '${song.title} ${song.artist} ${song.chords.join(' ')} ${song.category}',
      );
      final matchesText = query.isEmpty || haystack.contains(query);
      final matchesFilter = switch (_filter) {
        _SongFilter.all => true,
        _SongFilter.active => !song.isArchived,
        _SongFilter.archived => song.isArchived,
        _SongFilter.open => song.capo == 0,
        _SongFilter.capo => song.capo > 0,
      };
      return matchesText &&
          matchesFilter &&
          (_category == null || song.category == _category);
    }).toList();
  }

  Future<void> _edit([SongModel? song, int nextOrder = 1]) async {
    final result = await showDialog<SongModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SongDialog(song: song, nextOrder: nextOrder),
    );
    if (result == null || !mounted) return;
    try {
      await widget.repository.save(result);
      if (mounted) {
        _message(song == null ? 'Canción creada' : 'Canción actualizada');
      }
    } on FirebaseException catch (error, stackTrace) {
      _debugFirebase(error, stackTrace, 'songs', result.id, 'save');
      if (mounted) _message(error.message ?? error.code, error: true);
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

  Future<void> _archive(SongModel song) async {
    await widget.repository.archive(song);
    if (mounted) _message('Canción archivada');
  }

  Future<void> _delete(SongModel song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar canción'),
        content: Text(
          '¿Eliminar “${song.title}”? Si está incluida en un repertorio se archivará como opción segura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.delete(song);
      if (mounted) _message('Canción eliminada');
    } on SongInUseException catch (error) {
      await widget.repository.archive(song);
      if (mounted) {
        _message(
          'La canción está en ${error.setlistCount} repertorios y se ha archivado.',
        );
      }
    }
  }

  Future<void> _import() async {
    try {
      final count = await widget.repository.importInitialSongs();
      if (mounted) {
        _message(count == 0
            ? 'Ya existen canciones; no se ha importado nada.'
            : '$count canciones importadas.');
      }
    } catch (error) {
      if (mounted) _message('No se pudo importar: $error', error: true);
    }
  }

  Future<void> _reorder(
    List<SongModel> allSongs,
    List<SongModel> visible,
    int oldIndex,
    int newIndex,
  ) async {
    if (!widget.canManage ||
        _search.text.isNotEmpty ||
        _filter != _SongFilter.all ||
        _category != null) {
      _message('Quita búsqueda y filtros para cambiar el orden.', error: true);
      return;
    }
    final reordered = [...visible];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    setState(() => _savingOrder = true);
    try {
      await widget.repository.reorder(allSongs, reordered);
      if (mounted) _message('Orden guardado');
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? AppColors.dangerText : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<SongModel>>(
        stream: widget.repository.watchSongs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('No se pudo cargar: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data!;
          final visible = _visible(songs);
          final categories = songs
              .map((song) => song.category)
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Text(
                          '${visible.length} ${visible.length == 1 ? 'canción' : 'canciones'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (widget.canManage)
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _import,
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Importar iniciales'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _edit(null, songs.length + 1),
                                icon: const Icon(Icons.add),
                                label: const Text('Nueva canción'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 330,
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Buscar título, artista, acorde…',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        DropdownButton<_SongFilter>(
                          value: _filter,
                          items: const [
                            DropdownMenuItem(
                                value: _SongFilter.all, child: Text('Todas')),
                            DropdownMenuItem(
                                value: _SongFilter.active,
                                child: Text('Activas')),
                            DropdownMenuItem(
                                value: _SongFilter.archived,
                                child: Text('Archivadas')),
                            DropdownMenuItem(
                                value: _SongFilter.open,
                                child: Text('Al aire')),
                            DropdownMenuItem(
                                value: _SongFilter.capo,
                                child: Text('Con cejilla')),
                          ],
                          onChanged: (value) =>
                              setState(() => _filter = value ?? _filter),
                        ),
                        DropdownButton<String?>(
                          value: _category,
                          hint: const Text('Categoría'),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('Todas las categorías')),
                            ...categories.map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                )),
                          ],
                          onChanged: (value) =>
                              setState(() => _category = value),
                        ),
                        if (_savingOrder)
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('No hay canciones que mostrar.'))
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                        itemCount: visible.length,
                        onReorderItem: (oldIndex, newIndex) => _reorder(
                          songs,
                          visible,
                          oldIndex,
                          newIndex,
                        ),
                        buildDefaultDragHandles: widget.canManage,
                        itemBuilder: (context, index) {
                          final song = visible[index];
                          return _SongTile(
                            key: ValueKey(song.id),
                            song: song,
                            index: index,
                            canManage: widget.canManage,
                            onOpen: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _SongDetail(
                                  songs: visible,
                                  initialIndex: index,
                                ),
                              ),
                            ),
                            onEdit: () => _edit(song),
                            onArchive: () => _archive(song),
                            onDelete: () => _delete(song),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    super.key,
    required this.song,
    required this.index,
    required this.canManage,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });
  final SongModel song;
  final int index;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onOpen,
          leading: CircleAvatar(child: Text('${song.defaultOrder}')),
          title: Text(
            song.title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              decoration: song.isArchived ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (song.artist.isNotEmpty) Text(song.artist),
              Wrap(
                spacing: 5,
                runSpacing: 3,
                children: song.chords
                    .map((chord) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(chord),
                        ))
                    .toList(),
              ),
              Text(
                '${song.capo == 0 ? 'Al aire' : 'Cejilla ${song.capo}'}'
                '${song.durationSeconds == null ? '' : ' · ${_duration(song.durationSeconds!)}'}'
                ' · ${song.category}',
              ),
            ],
          ),
          trailing: canManage
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'archive') onArchive();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    if (!song.isArchived)
                      const PopupMenuItem(
                          value: 'archive', child: Text('Archivar')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Eliminar')),
                  ],
                )
              : const Icon(Icons.chevron_right),
        ),
      );
}

class _SongDialog extends StatefulWidget {
  const _SongDialog({this.song, required this.nextOrder});
  final SongModel? song;
  final int nextOrder;

  @override
  State<_SongDialog> createState() => _SongDialogState();
}

class _SongDialogState extends State<_SongDialog> {
  late final _title = TextEditingController(text: widget.song?.title);
  late final _artist = TextEditingController(text: widget.song?.artist);
  late final _key = TextEditingController(text: widget.song?.key);
  late final _chords =
      TextEditingController(text: widget.song?.chords.join(' '));
  late final _tempo =
      TextEditingController(text: widget.song?.tempo?.toString());
  late final _duration = TextEditingController(
    text: widget.song?.durationSeconds == null
        ? ''
        : _durationInput(widget.song!.durationSeconds!),
  );
  late final _category = TextEditingController(
      text: widget.song?.category ?? 'Repertorio habitual');
  late final _notes = TextEditingController(text: widget.song?.notes);
  late int _capo = widget.song?.capo ?? 0;
  late String _status = widget.song?.status ?? 'active';
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _artist,
      _key,
      _chords,
      _tempo,
      _duration,
      _category,
      _notes
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final duration = _parseDuration(_duration.text);
    if (title.isEmpty) {
      setState(() => _error = 'El título es obligatorio.');
      return;
    }
    if (_duration.text.trim().isNotEmpty && duration == null) {
      setState(() => _error = 'Usa una duración válida, por ejemplo 3:45.');
      return;
    }
    final chords = _chords.text
        .split(RegExp(r'[\s,]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final result = SongModel(
      id: widget.song?.id ?? '',
      title: title,
      normalizedTitle: normalizeSongSearch(title),
      artist: _artist.text.trim(),
      key: _key.text.trim(),
      chords: chords,
      capo: _capo,
      tempo: int.tryParse(_tempo.text.trim()),
      durationSeconds: duration,
      notes: _notes.text.trim(),
      category: _category.text.trim().isEmpty
          ? 'Repertorio habitual'
          : _category.text.trim(),
      status: _status,
      defaultOrder: widget.song?.defaultOrder ?? widget.nextOrder,
      createdAt: widget.song?.createdAt,
      updatedAt: widget.song?.updatedAt,
      createdBy: widget.song?.createdBy ?? '',
    );
    if (widget.song == result) {
      setState(() => _error = 'No hay cambios que guardar.');
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.song == null ? 'Nueva canción' : 'Editar canción'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Título *')),
                const SizedBox(height: 10),
                TextField(
                    controller: _artist,
                    decoration: const InputDecoration(labelText: 'Artista')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                        controller: _key,
                        decoration:
                            const InputDecoration(labelText: 'Tonalidad')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _capo,
                      decoration: const InputDecoration(labelText: 'Cejilla'),
                      items: List.generate(
                        13,
                        (value) => DropdownMenuItem(
                          value: value,
                          child:
                              Text(value == 0 ? 'Al aire' : 'Cejilla $value'),
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _capo = value ?? _capo),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _chords,
                  decoration: const InputDecoration(
                    labelText: 'Acordes',
                    hintText: 'Mim Lam Re7 Sol Si7',
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _duration,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Duración',
                        hintText: '3:45',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _tempo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'BPM'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                    controller: _category,
                    decoration: const InputDecoration(labelText: 'Categoría')),
                const SizedBox(height: 10),
                TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notas')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Activa')),
                    DropdownMenuItem(
                        value: 'archived', child: Text('Archivada')),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? _status),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.dangerText)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      );
}

class _SongDetail extends StatefulWidget {
  const _SongDetail({required this.songs, required this.initialIndex});
  final List<SongModel> songs;
  final int initialIndex;

  @override
  State<_SongDetail> createState() => _SongDetailState();
}

class _SongDetailState extends State<_SongDetail> {
  late int _index = widget.initialIndex;
  bool _stage = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.songs[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(_stage ? 'MODO ESCENARIO' : song.title),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _stage = !_stage),
            icon: Icon(_stage ? Icons.close_fullscreen : Icons.fullscreen),
            label: Text(_stage ? 'Salir' : 'Modo escenario'),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(_stage ? 28 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(song.title,
                style: TextStyle(
                    fontSize: _stage ? 38 : 26, fontWeight: FontWeight.w900)),
            if (song.artist.isNotEmpty) Text(song.artist),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: song.chords
                  .map((value) => Chip(
                        label: Text(value,
                            style: TextStyle(
                                fontSize: _stage ? 25 : 18,
                                fontWeight: FontWeight.w800)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            Text(
              '${song.key.isEmpty ? 'Tonalidad pendiente' : song.key} · '
              '${song.capo == 0 ? 'Al aire' : 'Cejilla ${song.capo}'}'
              '${song.tempo == null ? '' : ' · ${song.tempo} BPM'}'
              '${song.durationSeconds == null ? '' : ' · ${_duration(song.durationSeconds!)}'}',
              style: TextStyle(fontSize: _stage ? 22 : 15),
            ),
            if (song.notes.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Notas',
                  style: TextStyle(
                      fontSize: _stage ? 20 : 14, fontWeight: FontWeight.w800)),
              Text(song.notes,
                  style: TextStyle(
                      fontSize: _stage ? 24 : 16,
                      color: AppColors.textSecondary)),
            ],
            const Spacer(),
            Text(
              '${_index + 1} de ${widget.songs.length}',
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.tonalIcon(
                  onPressed:
                      _index == 0 ? null : () => setState(() => _index--),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Anterior'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _index == widget.songs.length - 1
                      ? null
                      : () => setState(() => _index++),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetlistsView extends StatelessWidget {
  const _SetlistsView({
    required this.songRepository,
    required this.repository,
    required this.canManage,
  });
  final SongRepository songRepository;
  final SetlistRepository repository;
  final bool canManage;

  Future<void> _edit(
    BuildContext context,
    List<SongModel> songs, [
    SetlistModel? setlist,
  ]) async {
    final result = await showDialog<SetlistModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SetlistDialog(setlist: setlist, songs: songs),
    );
    if (result == null || !context.mounted) return;
    try {
      await repository.save(result);
      if (context.mounted) _message(context, 'Repertorio guardado');
    } on FirebaseException catch (error, stackTrace) {
      _debugFirebase(error, stackTrace, 'setlists', result.id, 'save');
      if (context.mounted) {
        _message(context, 'No se pudo guardar el repertorio', error: true);
      }
    }
  }

  Future<void> _delete(BuildContext context, SetlistModel setlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar repertorio'),
        content: Text('¿Eliminar “${setlist.name}”?'),
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
    if (confirmed == true) await repository.delete(setlist);
  }

  void _message(BuildContext context, String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.dangerText : null,
    ));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<SongModel>>(
        stream: songRepository.watchSongs(),
        builder: (context, songSnapshot) => StreamBuilder<List<SetlistModel>>(
          stream: repository.watchSetlists(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !songSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('No se pudo cargar: ${snapshot.error}'));
            }
            final songs = songSnapshot.data!;
            final songMap = {for (final song in songs) song.id: song};
            final setlists = snapshot.data!;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${setlists.length} repertorios',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (canManage)
                        FilledButton.icon(
                          onPressed: () => _edit(context, songs),
                          icon: const Icon(Icons.add),
                          label: const Text('Nuevo repertorio'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: setlists.isEmpty
                      ? const Center(
                          child: Text(
                              'Todavía no hay repertorios personalizados.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                          itemCount: setlists.length,
                          itemBuilder: (context, index) {
                            final setlist = setlists[index];
                            final songItems = setlist.items
                                .where((item) => !item.isSection)
                                .toList();
                            final missing = songItems
                                .where((item) =>
                                    songMap[item.songId]?.durationSeconds ==
                                    null)
                                .length;
                            final duration = estimateSetlistDuration(
                              setlist.items,
                              songMap,
                              pauseBetweenSongsSeconds:
                                  setlist.pauseBetweenSongsSeconds,
                            );
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.queue_music_rounded),
                                title: Text(setlist.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text(
                                  '${songItems.length} canciones · ${_duration(duration)}'
                                  '${missing == 0 ? '' : ' · $missing sin duración'}'
                                  '${setlist.status == 'archived' ? ' · Archivado' : ''}',
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _SetlistStage(
                                      setlist: setlist,
                                      songs: songMap,
                                    ),
                                  ),
                                ),
                                trailing: canManage
                                    ? PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _edit(
                                                context, songs, setlist);
                                          }
                                          if (value == 'duplicate') {
                                            await repository.duplicate(setlist);
                                          }
                                          if (value == 'archive') {
                                            await repository.archive(setlist);
                                          }
                                          if (value == 'delete' &&
                                              context.mounted) {
                                            await _delete(context, setlist);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Editar')),
                                          PopupMenuItem(
                                              value: 'duplicate',
                                              child: Text('Duplicar')),
                                          PopupMenuItem(
                                              value: 'archive',
                                              child: Text('Archivar')),
                                          PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Eliminar')),
                                        ],
                                      )
                                    : const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
}

class _SetlistDialog extends StatefulWidget {
  const _SetlistDialog({this.setlist, required this.songs});
  final SetlistModel? setlist;
  final List<SongModel> songs;

  @override
  State<_SetlistDialog> createState() => _SetlistDialogState();
}

class _SetlistDialogState extends State<_SetlistDialog> {
  late final _name = TextEditingController(text: widget.setlist?.name);
  late final _description =
      TextEditingController(text: widget.setlist?.description);
  late final _pause = TextEditingController(
      text: '${widget.setlist?.pauseBetweenSongsSeconds ?? 10}');
  late final List<SetlistItemModel> _items = [...?widget.setlist?.items];
  late String _status = widget.setlist?.status ?? 'active';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _pause.dispose();
    super.dispose();
  }

  void _addSong(SongModel song) {
    setState(() => _items.add(SetlistItemModel(
          type: 'song',
          songId: song.id,
          order: _items.length + 1,
        )));
  }

  Future<void> _addSection() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir bloque'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'BLOQUE RUMBA'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Añadir')),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.isNotEmpty && mounted) {
      setState(() => _items.add(SetlistItemModel(
            type: 'section',
            title: title,
            order: _items.length + 1,
          )));
    }
  }

  Future<void> _editSetlistItem(int index, SongModel song) async {
    final item = _items[index];
    final keyController =
        TextEditingController(text: item.customKey ?? song.key);
    final notesController = TextEditingController(text: item.customNotes);
    var capo = item.customCapo ?? song.capo;
    final result = await showDialog<SetlistItemModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(song.title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  decoration:
                      const InputDecoration(labelText: 'Tonalidad específica'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: capo,
                  decoration:
                      const InputDecoration(labelText: 'Cejilla específica'),
                  items: List.generate(
                    13,
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value == 0 ? 'Al aire' : 'Cejilla $value'),
                    ),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => capo = value ?? capo),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Notas específicas'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                item.copyWith(
                  customKey: keyController.text.trim(),
                  customCapo: capo,
                  customNotes: notesController.text.trim(),
                ),
              ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    keyController.dispose();
    notesController.dispose();
    if (result != null && mounted) {
      setState(() => _items[index] = result);
    }
  }

  void _save() {
    final name = _name.text.trim();
    final pause = int.tryParse(_pause.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    if (pause == null || pause < 0) {
      setState(() => _error = 'La pausa debe ser un número válido.');
      return;
    }
    final normalizedItems = [
      for (var index = 0; index < _items.length; index++)
        _items[index].copyWith(order: index + 1),
    ];
    final songMap = {for (final song in widget.songs) song.id: song};
    Navigator.pop(
      context,
      SetlistModel(
        id: widget.setlist?.id ?? '',
        name: name,
        description: _description.text.trim(),
        concertId: widget.setlist?.concertId,
        items: normalizedItems,
        estimatedDurationSeconds: estimateSetlistDuration(
          normalizedItems,
          songMap,
          pauseBetweenSongsSeconds: pause,
        ),
        pauseBetweenSongsSeconds: pause,
        status: _status,
        createdAt: widget.setlist?.createdAt,
        updatedAt: widget.setlist?.updatedAt,
        createdBy: widget.setlist?.createdBy ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addedIds = _items
        .where((item) => !item.isSection)
        .map((item) => item.songId)
        .toSet();
    final available =
        widget.songs.where((song) => !addedIds.contains(song.id)).toList();
    return AlertDialog(
      title: Text(
          widget.setlist == null ? 'Nuevo repertorio' : 'Editar repertorio'),
      content: SizedBox(
        width: 700,
        height: 620,
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nombre *')),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _pause,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Pausa (segundos)'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Descripción')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<SongModel>(
                  decoration:
                      const InputDecoration(labelText: 'Añadir canción'),
                  items: available
                      .map((song) => DropdownMenuItem(
                            value: song,
                            child: Text(song.title),
                          ))
                      .toList(),
                  onChanged: (song) {
                    if (song != null) _addSong(song);
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.segment),
                label: const Text('Bloque'),
              ),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: _items.length,
                onReorderItem: (oldIndex, newIndex) => setState(() {
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                }),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final song = item.songId == null
                      ? null
                      : widget.songs
                          .where((song) => song.id == item.songId)
                          .firstOrNull;
                  return ListTile(
                    key: ValueKey(
                        '${item.type}-${item.songId}-${item.title}-$index'),
                    leading: Icon(
                        item.isSection ? Icons.segment : Icons.drag_handle),
                    title: Text(item.isSection
                        ? item.title ?? 'BLOQUE'
                        : song?.title ?? 'Canción no disponible'),
                    subtitle: !item.isSection &&
                            (item.customKey?.isNotEmpty == true ||
                                item.customCapo != null ||
                                item.customNotes.isNotEmpty)
                        ? const Text('Con ajustes específicos')
                        : null,
                    onTap: song == null
                        ? null
                        : () => _editSetlistItem(index, song),
                    trailing: IconButton(
                      onPressed: () => setState(() => _items.removeAt(index)),
                      icon: const Icon(Icons.close),
                    ),
                  );
                },
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Activo')),
                DropdownMenuItem(value: 'archived', child: Text('Archivado')),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            if (_error != null)
              Text(_error!,
                  style: const TextStyle(color: AppColors.dangerText)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _SetlistStage extends StatefulWidget {
  const _SetlistStage({required this.setlist, required this.songs});
  final SetlistModel setlist;
  final Map<String, SongModel> songs;

  @override
  State<_SetlistStage> createState() => _SetlistStageState();
}

class _SetlistStageState extends State<_SetlistStage> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.setlist.items;
    if (items.isEmpty) {
      return const Scaffold(body: Center(child: Text('Repertorio vacío.')));
    }
    final item = items[_index];
    final song = item.songId == null ? null : widget.songs[item.songId];
    return Scaffold(
      appBar: AppBar(title: Text(widget.setlist.name)),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item.isSection)
              Expanded(
                child: Center(
                  child: Text(
                    item.title ?? 'BLOQUE',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 42, fontWeight: FontWeight.w900),
                  ),
                ),
              )
            else ...[
              Text(song?.title ?? 'Canción no disponible',
                  style: const TextStyle(
                      fontSize: 38, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: (song?.chords ?? const <String>[])
                    .map((chord) => Chip(
                          label: Text(chord,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w800)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text(
                '${item.customKey ?? song?.key ?? ''} · '
                '${(item.customCapo ?? song?.capo ?? 0) == 0 ? 'Al aire' : 'Cejilla ${item.customCapo ?? song?.capo}'}',
                style: const TextStyle(fontSize: 21),
              ),
              if (item.customNotes.isNotEmpty || song?.notes.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    item.customNotes.isNotEmpty
                        ? item.customNotes
                        : song!.notes,
                    style: const TextStyle(
                        fontSize: 23, color: AppColors.textSecondary),
                  ),
                ),
              const Spacer(),
            ],
            Text('${_index + 1} de ${items.length}',
                textAlign: TextAlign.center),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.tonal(
                    onPressed:
                        _index == 0 ? null : () => setState(() => _index--),
                    child: const Text('Anterior')),
                FilledButton.tonal(
                    onPressed: _index == items.length - 1
                        ? null
                        : () => setState(() => _index++),
                    child: const Text('Siguiente')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

int? _parseDuration(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^(\d+):([0-5]\d)$').firstMatch(trimmed);
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

String _durationInput(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remaining = seconds % 60;
  if (hours > 0) return '$hours h $minutes min';
  return remaining == 0
      ? '$minutes min'
      : '$minutes:${remaining.toString().padLeft(2, '0')}';
}

void _debugFirebase(
  FirebaseException error,
  StackTrace stackTrace,
  String collection,
  String document,
  String operation,
) {
  debugPrint(
    'Firebase error: ${error.code}; ${error.message}; '
    'collection=$collection; document=$document; operation=$operation',
  );
  debugPrintStack(stackTrace: stackTrace);
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/song.dart';

class SongInUseException implements Exception {
  const SongInUseException(this.setlistCount);
  final int setlistCount;
}

class SongRepository {
  SongRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _songs =>
      _firestore.collection('songs');

  Stream<List<SongModel>> watchSongs() => _songs.snapshots().map((snapshot) {
        final songs = snapshot.docs.map(SongModel.fromFirestore).toList();
        songs.sort((a, b) => a.defaultOrder.compareTo(b.defaultOrder));
        return songs;
      });

  Future<void> save(SongModel song) async {
    final duplicate = await _songs
        .where('normalizedTitle', isEqualTo: normalizeSongSearch(song.title))
        .get();
    if (duplicate.docs.any((document) => document.id != song.id)) {
      throw StateError('Ya existe una canción con ese título.');
    }
    final creating = song.id.isEmpty;
    final reference = creating ? _songs.doc() : _songs.doc(song.id);
    final user = FirebaseAuth.instance.currentUser;
    final value = creating
        ? SongModel(
            id: reference.id,
            title: song.title,
            normalizedTitle: normalizeSongSearch(song.title),
            artist: song.artist,
            key: song.key,
            chords: song.chords,
            capo: song.capo,
            tempo: song.tempo,
            durationSeconds: song.durationSeconds,
            notes: song.notes,
            category: song.category,
            status: song.status,
            defaultOrder: song.defaultOrder,
            createdBy: user?.uid ?? '',
          )
        : song;
    await reference.set(
      value.toFirestore(creating: creating),
      SetOptions(merge: !creating),
    );
  }

  Future<void> archive(SongModel song) => _songs.doc(song.id).update({
        'status': 'archived',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> delete(SongModel song) async {
    final usage = await _firestore
        .collection('setlists')
        .where('songIds', arrayContains: song.id)
        .get();
    if (usage.docs.isNotEmpty) {
      throw SongInUseException(usage.docs.length);
    }
    await _songs.doc(song.id).delete();
  }

  Future<void> reorder(
    List<SongModel> previous,
    List<SongModel> reordered,
  ) async {
    final previousOrder = {
      for (final song in previous) song.id: song.defaultOrder,
    };
    final batch = _firestore.batch();
    var changes = 0;
    for (var index = 0; index < reordered.length; index++) {
      final order = index + 1;
      final song = reordered[index];
      if (previousOrder[song.id] == order) continue;
      changes++;
      batch.update(_songs.doc(song.id), {
        'defaultOrder': order,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    if (changes > 0) await batch.commit();
  }

  Future<int> importInitialSongs() async {
    final existing = await _songs.limit(1).get();
    if (existing.docs.isNotEmpty) return 0;
    final batch = _firestore.batch();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    for (var index = 0; index < _initialSongs.length; index++) {
      final data = _initialSongs[index];
      final reference = _songs.doc();
      batch.set(reference, {
        'title': data.title,
        'normalizedTitle': normalizeSongSearch(data.title),
        'artist': '',
        'key': '',
        'chords': data.chords,
        'capo': data.capo,
        'tempo': null,
        'durationSeconds': null,
        'notes': '',
        'category': data.category,
        'status': 'active',
        'defaultOrder': index + 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });
    }
    await batch.commit();
    return _initialSongs.length;
  }
}

class _InitialSong {
  const _InitialSong(
    this.title, {
    this.chords = const [],
    this.capo = 0,
    this.category = 'Repertorio habitual',
  });
  final String title;
  final List<String> chords;
  final int capo;
  final String category;
}

const _initialSongs = <_InitialSong>[
  _InitialSong('Dos días', chords: ['Mim', 'Lam', 'Re7', 'Sol', 'Si7']),
  _InitialSong('Tu calorro'),
  _InitialSong('Como camarón', chords: ['Lam', 'Sol', 'Fa', 'Mi']),
  _InitialSong('Las cosas pequeñitas'),
  _InitialSong('El aire que respiro'),
  _InitialSong('Los Chichos', category: 'Popurrí'),
  _InitialSong('La isla del amor'),
  _InitialSong('La magia'),
  _InitialSong('Fuera de mí'),
  _InitialSong('Orgullo'),
  _InitialSong('Salitre'),
  _InitialSong(
    'El merengue',
    capo: 2,
    chords: ['Mim', 'Lam', 'Re7', 'Sol', 'Si7'],
  ),
  _InitialSong('Tanto la quería', chords: ['Sol', 'Do', 'Re']),
  _InitialSong(
    'La bachata',
    capo: 2,
    chords: ['Do', 'Re', 'Sim', 'Mim'],
  ),
  _InitialSong(
    'Vagabundo',
    capo: 2,
    chords: ['Sol', 'Mim', 'Lam', 'Re7'],
  ),
  _InitialSong(
    'Corazón sin alma',
    capo: 1,
    chords: ['Do', 'Lam', 'Fa', 'Sol'],
  ),
  _InitialSong('Pedacitos de ti', chords: ['Lam', 'Fa', 'Sol']),
  _InitialSong(
    'Uno x Uno',
    chords: ['Do', 'Mim', 'Fam', 'Re7', 'Mi', 'Fa', 'Sol', 'Mim', 'Lam'],
  ),
  _InitialSong(
    'Siempre conmigo',
    chords: ['Lam', 'Mim', 'Fa', 'Re7', 'Sol', 'Lam', 'Fa', 'Do', 'Sol'],
  ),
  _InitialSong('Todos los besos', chords: ['La', 'Fa#m', 'Sim', 'Mi']),
];

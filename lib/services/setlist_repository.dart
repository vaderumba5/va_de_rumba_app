import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/setlist.dart';
import '../models/song.dart';

class SetlistRepository {
  SetlistRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _setlists =>
      _firestore.collection('setlists');

  Stream<List<SetlistModel>> watchSetlists() =>
      _setlists.snapshots().map((snapshot) {
        final setlists = snapshot.docs.map(SetlistModel.fromFirestore).toList();
        setlists.sort((a, b) => a.name.compareTo(b.name));
        return setlists;
      });

  Future<void> save(SetlistModel setlist) async {
    final creating = setlist.id.isEmpty;
    final reference = creating ? _setlists.doc() : _setlists.doc(setlist.id);
    final value = setlist.copyWith(id: reference.id);
    final data = value.toFirestore(creating: creating);
    if (creating) {
      data['createdBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    await reference.set(data, SetOptions(merge: !creating));
  }

  Future<void> delete(SetlistModel setlist) =>
      _setlists.doc(setlist.id).delete();

  Future<void> archive(SetlistModel setlist) =>
      _setlists.doc(setlist.id).update({
        'status': 'archived',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> duplicate(SetlistModel source) => save(
        source.copyWith(
          id: '',
          name: '${source.name} (copia)',
          concertId: '',
          status: 'active',
        ),
      );
}

int estimateSetlistDuration(
  List<SetlistItemModel> items,
  Map<String, SongModel> songs, {
  int pauseBetweenSongsSeconds = 10,
}) {
  final songItems =
      items.where((item) => !item.isSection && item.songId != null).toList();
  final music = songItems.fold<int>(
    0,
    (total, item) => total + (songs[item.songId]?.durationSeconds ?? 0),
  );
  final pauses = songItems.length <= 1
      ? 0
      : (songItems.length - 1) * pauseBetweenSongsSeconds;
  return music + pauses;
}

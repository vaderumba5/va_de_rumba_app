import 'package:flutter_test/flutter_test.dart';
import 'package:va_de_rumba/models/setlist.dart';
import 'package:va_de_rumba/models/song.dart';
import 'package:va_de_rumba/services/setlist_repository.dart';

void main() {
  test('normaliza búsquedas sin perder sostenidos', () {
    expect(normalizeSongSearch('  DOS DÍAS  '), 'dos dias');
    expect(normalizeSongSearch('Fa#m'), 'fa#m');
  });

  test('calcula música y pausas sin inventar duraciones pendientes', () {
    const songs = {
      'one': SongModel(
        id: 'one',
        title: 'Uno',
        normalizedTitle: 'uno',
        durationSeconds: 180,
        defaultOrder: 1,
      ),
      'two': SongModel(
        id: 'two',
        title: 'Dos',
        normalizedTitle: 'dos',
        defaultOrder: 2,
      ),
    };
    const items = [
      SetlistItemModel(type: 'song', songId: 'one', order: 1),
      SetlistItemModel(type: 'section', title: 'BLOQUE', order: 2),
      SetlistItemModel(type: 'song', songId: 'two', order: 3),
    ];
    expect(
      estimateSetlistDuration(
        items,
        songs,
        pauseBetweenSongsSeconds: 10,
      ),
      190,
    );
  });
}

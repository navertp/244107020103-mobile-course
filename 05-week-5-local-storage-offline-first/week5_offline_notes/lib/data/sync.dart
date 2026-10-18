import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'local/db.dart';
import 'models/post.dart';
import 'repositories/note_repository.dart';

class PostCacheRepository {
  Future<List<Post>> readCachedPosts() async {
    final db = await openNotesDb();
    final rows = await db.query('cached_posts', orderBy: 'id');
    return rows
        .map((r) => Post.fromJson(
            jsonDecode(r['payload'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCachedPosts(List<Post> posts) async {
    final db = await openNotesDb();
    for (final p in posts) {
      await db.insert(
        'cached_posts',
        {
          'id': p.id,
          'payload': jsonEncode(p.toJson()),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}

Future<int> syncNotes(NoteRepository repo) async {
  final dirtyCount = await repo.countDirty();
  if (dirtyCount == 0) return 0;
  await Future.delayed(const Duration(seconds: 1));
  await repo.markAllSynced();
  return dirtyCount;
}
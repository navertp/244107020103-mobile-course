import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local/note.dart';
import 'repositories/note_repository.dart';

final noteRepositoryProvider =
    Provider<NoteRepository>((ref) => NoteRepository());

class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() =>
      ref.read(noteRepositoryProvider).fetchNotes();

  Future<void> add(String title) async {
    await ref.read(noteRepositoryProvider).addNote(title: title);
    ref.invalidateSelf(); // muat ulang daftar dari SQLite
  }

  Future<void> remove(int id) async {
    await ref.read(noteRepositoryProvider).deleteNote(id);
    ref.invalidateSelf();
  }
}

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new,
    retry: (retryCount, error) => null);

/// Jumlah catatan dirty untuk badge. Dihitung ulang setiap daftar berubah.
final dirtyCountProvider = FutureProvider<int>((ref) {
  ref.watch(notesProvider);
  return ref.read(noteRepositoryProvider).countDirty();
});

final noteDetailProvider = FutureProvider.autoDispose.family<Note?, int>(
  (ref, id) => ref.read(noteRepositoryProvider).fetchNoteById(id),
);
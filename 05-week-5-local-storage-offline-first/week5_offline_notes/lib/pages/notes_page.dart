import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/note_providers.dart';
import '../data/post_providers.dart';
import '../data/sync.dart';
// import 'posts_page.dart';
import '../widgets/note_tile.dart';
import 'package:go_router/go_router.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catatan baru'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await ref.read(notesProvider.notifier).add(title);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final dirtyCount = ref.watch(dirtyCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Offline'),
        actions: [
          Switch(
            value: ref.watch(forceOfflineProvider),
            onChanged: (v) => ref.read(forceOfflineProvider.notifier).set(v),
          ),
          IconButton(
            tooltip: 'Sinkronkan',
            icon: Badge(
              label: Text('$dirtyCount'),
              isLabelVisible: dirtyCount > 0,
              child: const Icon(Icons.sync),
            ),
            onPressed: () async {
              if (ref.read(forceOfflineProvider)) return;
              await syncNotes(ref.read(noteRepositoryProvider));
              ref.invalidate(notesProvider); // badge dirty ikut diperbarui
            },
          ),
          IconButton(
            tooltip: 'Posts',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () => context.push('/posts'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNote(context, ref),
        child: const Icon(Icons.add),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(child: Text('Belum ada catatan.'));
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return NoteTile(
                note: note,
                onTap: () => context.push('/note/${note.id}'),
                onDelete: () => ref.read(notesProvider.notifier).remove(note.id!),
              );
            },
          );
        },
      ),
    );
  }
}
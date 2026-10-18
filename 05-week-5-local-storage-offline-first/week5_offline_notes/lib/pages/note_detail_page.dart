import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/note_providers.dart';

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteDetailProvider(id));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Catatan #$id')),
      body: noteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (note) {
          if (note == null) {
            return const Center(child: Text('Catatan tidak ditemukan.'));
          }
          final d = note.updatedAt.toLocal();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Diperbarui ${d.day}/${d.month}/${d.year} '
                  '${d.hour}:${d.minute.toString().padLeft(2, '0')}'
                  '${note.dirty ? ' • Belum tersinkron' : ''}',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  note.body.isEmpty ? '(tanpa isi)' : note.body,
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
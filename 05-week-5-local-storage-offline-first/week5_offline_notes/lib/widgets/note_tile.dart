import 'package:flutter/material.dart';
import '../data/local/note.dart';

class NoteTile extends StatelessWidget {
  const NoteTile({
    required this.note,
    this.onTap,
    this.onDelete,
    super.key,
  });

  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(note.dirty ? Icons.cloud_upload_outlined : Icons.check),
      title: Text(note.title),
      subtitle: note.dirty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Belum tersinkron',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}
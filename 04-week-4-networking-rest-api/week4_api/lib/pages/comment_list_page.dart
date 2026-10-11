// ============================================================
// Halaman: CommentListPage
//
// Menampilkan daftar komentar dari endpoint
//   GET /comments?postId={postId}
//
// UI hanya berinteraksi dengan Provider – TIDAK pernah memanggil
// Dio secara langsung (sesuai checklist).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/comment_providers.dart';
import '../data/models/comment.dart';

/// Halaman yang menampilkan komentar untuk [postId] tertentu.
///
/// Menerima [postId] dari halaman sebelumnya (mis. tap pada post).
class CommentListPage extends ConsumerWidget {
  const CommentListPage({super.key, required this.postId});

  /// ID post yang komentarnya akan ditampilkan.
  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mengamati state dari commentListFamilyProvider(postId).
    // AsyncValue<List<Comment>> bisa berupa:
    //   - AsyncLoading → tampilkan spinner
    //   - AsyncData    → tampilkan list komentar
    //   - AsyncError   → tampilkan pesan error ramah pengguna
    final commentsAsync = ref.watch(commentListFamilyProvider(postId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Komentar Post #$postId'),
        actions: [
          // Tombol refresh – memanggil notifier.refresh() bukan Dio.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: () {
              // Notifier meng-handle loading state secara internal.
              ref
                  .read(commentListFamilyProvider(postId).notifier)
                  .refresh();
            },
          ),
        ],
      ),
      // when() adalah cara idiomatis Riverpod untuk handle 3 state:
      body: commentsAsync.when(
        // --- State: Loading ---
        loading: () => const Center(child: CircularProgressIndicator()),

        // --- State: Error ---
        // error dibuat ramah pengguna via friendlyCommentErrorMessage.
        error: (error, stackTrace) => _ErrorView(
          message: friendlyCommentErrorMessage(error),
          onRetry: () => ref
              .read(commentListFamilyProvider(postId).notifier)
              .refresh(),
        ),

        // --- State: Data ---
        data: (comments) {
          if (comments.isEmpty) {
            return const Center(
              child: Text('Tidak ada komentar untuk post ini.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: comments.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _CommentCard(comment: comments[index]),
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------
// Widget: _CommentCard
// ----------------------------------------------------------

/// Kartu yang menampilkan satu komentar.
///
/// Mengakses data dari [Comment] model, bukan dari Map/JSON langsung.
class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama komentator
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  comment.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Badge ID komentar
              Chip(
                label: Text('#${comment.id}'),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          // Email – menggunakan mailto style
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 14),
              const SizedBox(width: 4),
              Text(
                comment.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Isi komentar
          Text(comment.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------
// Widget: _ErrorView
// ----------------------------------------------------------

/// Tampilan error dengan pesan ramah dan tombol retry.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

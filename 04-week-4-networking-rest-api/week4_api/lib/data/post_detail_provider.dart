import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/post.dart';
import 'paged_posts.dart';
import 'providers.dart';

final postDetailProvider = FutureProvider.family<Post, int>(
  (ref, id) async {
    // ref.exists: cek tanpa memicu fetch list yang belum pernah dibuka.
    final listState =
        ref.exists(postListProvider) ? ref.read(postListProvider) : null;
    final fromList = switch (listState) {
      AsyncData(:final value) => value,
      _ => const <Post>[],
    };
    final fromPaged = ref.exists(pagedPostsProvider)
        ? ref.read(pagedPostsProvider).items
        : const <Post>[];

    for (final post in [...fromList, ...fromPaged]) {
      if (post.id == id) return post;
    }
    // Tidak ada di list yang termuat: ambil lewat repository.
    return ref.read(postRepositoryProvider).fetchPostById(id);
  },
  // Sama seperti provider lain: error langsung final, tanpa retry otomatis.
  retry: (retryCount, error) => null,
);
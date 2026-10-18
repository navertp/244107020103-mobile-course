import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'models/post.dart';
// import 'repositories/post_cache_repository.dart';
import 'repositories/post_repository.dart';
import 'sync.dart';

final dioProvider = Provider<Dio>((ref) => createDio());

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(ref.watch(dioProvider)),
);

final postCacheRepositoryProvider =
    Provider<PostCacheRepository>((ref) => PostCacheRepository());

class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final forceOfflineProvider =
    NotifierProvider<ForceOfflineNotifier, bool>(ForceOfflineNotifier.new);

class PostsNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    // 1. Kembalikan cache seketika.
    final cached =
        await ref.read(postCacheRepositoryProvider).readCachedPosts();
    // 2. Refresh dari jaringan di background.
    _refreshInBackground();
    return cached;
  }

  Future<void> _refreshInBackground() async {
    if (ref.read(forceOfflineProvider)) return; // simulasi offline
    final remote = ref.read(postRepositoryProvider);
    final cache = ref.read(postCacheRepositoryProvider);
    try {
      final fresh = await remote.fetchPosts();
      await cache.saveCachedPosts(fresh);
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {
      // Gagal (offline/timeout): cache tetap tampil.
    }
  }
}

final postsProvider =
    AsyncNotifierProvider<PostsNotifier, List<Post>>(PostsNotifier.new);
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/post_providers.dart';

class PostsPage extends ConsumerWidget {
  const PostsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts (cache-first)'),
        actions: [
          Switch(
            value: ref.watch(forceOfflineProvider),
            onChanged: (v) => ref.read(forceOfflineProvider.notifier).set(v),
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (posts) => ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, i) => ListTile(
            leading: CircleAvatar(child: Text('${posts[i].id}')),
            title: Text(posts[i].title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
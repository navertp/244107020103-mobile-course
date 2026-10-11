import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/post.dart';
import 'providers.dart';
import '../data/network_errors.dart';

class PagedPostsState {
  const PagedPostsState({
    this.items = const [],
    this.page = 0,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Post> items;
  final int page;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
}

class PagedPostsNotifier extends Notifier<PagedPostsState> {
  @override
  PagedPostsState build() {
    Future.microtask(loadFirstPage);
    return const PagedPostsState();
  }

  Future<void> loadFirstPage() async {
    final repository = ref.read(postRepositoryProvider);
    try {
      final items =
          await repository.fetchPostsPage(page: 1, limit: 10);
      state = PagedPostsState(
        items: items,
        page: 1,
        hasMore: items.length == 10,
      );
    } catch (e) {
      state = PagedPostsState(error: e);
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final repo = ref.read(postRepositoryProvider);
    final currentItems = state.items;
    final currentPage = state.page;
    state = PagedPostsState(
      items: currentItems,
      page: currentPage,
      isLoadingMore: true,
      hasMore: state.hasMore,
    );
    try {
      final next = currentPage + 1;
      final items =
          await repo.fetchPostsPage(page: next, limit: 10);
      state = PagedPostsState(
        items: [...currentItems, ...items],
        page: next,
        hasMore: items.length == 10,
      );
    } catch (e) {
      state = PagedPostsState(
        items: currentItems,
        page: currentPage,
        error: e,
      );
    }
  }
}

final pagedPostsProvider =
    NotifierProvider<PagedPostsNotifier, PagedPostsState>(
        PagedPostsNotifier.new);

class PagedPostPage extends ConsumerStatefulWidget {
  const PagedPostPage({super.key});

  @override
  ConsumerState<PagedPostPage> createState() =>
      _PagedPostPageState();
}

class _PagedPostPageState
    extends ConsumerState<PagedPostPage> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.pixels >=
          _controller.position.maxScrollExtent - 200) {
        ref.read(pagedPostsProvider.notifier).loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pagedPostsProvider);
    if (state.error != null && state.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Posts Paged')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyErrorMessage(state.error!)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref
                    .read(pagedPostsProvider.notifier)
                    .loadFirstPage(),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Posts Paged')),
      body: ListView.builder(
        controller: _controller,
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (!state.hasMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child:
                    Center(child: Text('Semua data termuat.')),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final post = state.items[index];
          return ListTile(
            leading: CircleAvatar(
                child: Text(post.id.toString())),
            title: Text(post.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        },
      ),
    );
  }
}
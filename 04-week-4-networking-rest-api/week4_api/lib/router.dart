import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'pages/comment_list_page.dart';
import 'pages/paged_post_page.dart';
import 'pages/post_detail_page.dart';

int? _idFrom(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

Widget _invalidId() =>
    const Scaffold(body: Center(child: Text('ID post tidak valid.')));

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const PagedPostPage()),
    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        final id = _idFrom(state);
        return id == null ? _invalidId() : PostDetailPage(id: id);
      },
      routes: [
        GoRoute(
          path: 'comments', // menjadi /post/:id/comments
          builder: (context, state) {
            final id = _idFrom(state);
            return id == null ? _invalidId() : CommentListPage(postId: id);
          },
        ),
      ],
    ),
  ],
);
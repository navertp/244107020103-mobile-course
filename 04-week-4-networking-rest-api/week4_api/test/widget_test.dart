// ============================================================
// Widget Test: Smoke test untuk MyApp
//
// Memastikan aplikasi bisa di-build dan menampilkan
// AppBar tanpa melakukan network request sungguhan.
// Provider di-override dengan stub agar test deterministik.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:week4_api/data/paged_posts.dart';
import 'package:week4_api/main.dart';

void main() {
  testWidgets('App renders tanpa crash dan menampilkan AppBar', (tester) async {
    // Override pagedPostsProvider agar tidak ada network call di test.
    // PagedPostsState kosong (isLoadingMore: false, hasMore: true)
    // sehingga tidak ada Timer yang pending.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Stub notifier: kembalikan state kosong tanpa network request.
          pagedPostsProvider.overrideWith(
            () => _StubPagedPostsNotifier(),
          ),
        ],
        child: const MyApp(),
      ),
    );
    // pump() saja – tidak pumpAndSettle karena provider mungkin async.
    await tester.pump();

    // Verifikasi MaterialApp berhasil dirender.
    expect(find.byType(MaterialApp), findsOneWidget);
    // Verifikasi AppBar dengan judul muncul.
    expect(find.text('Posts Paged'), findsOneWidget);
  });
}

/// Stub notifier yang mengembalikan state kosong tanpa network call.
/// Digunakan hanya di test untuk menghindari pending Timer dari Dio.
class _StubPagedPostsNotifier extends PagedPostsNotifier {
  @override
  PagedPostsState build() {
    // Tidak memanggil loadFirstPage() → tidak ada network request.
    return const PagedPostsState(hasMore: false);
  }
}


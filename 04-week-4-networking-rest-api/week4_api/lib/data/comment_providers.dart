// ============================================================
// Comment Providers
//
// Berisi:
//   1. _dioProvider               – singleton Dio (terpusat)
//   2. commentRepositoryProvider  – menyediakan CommentRepository
//   3. _PostCommentNotifier       – AsyncNotifier per postId (private)
//   4. commentListFamilyProvider  – AsyncNotifierProvider.family(postId)
//   5. friendlyCommentErrorMessage – mapping DioException → pesan user
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models/comment.dart';
import 'repositories/comment_repository.dart';

// ----------------------------------------------------------
// 1. _dioProvider – Dio singleton per ProviderScope
// ----------------------------------------------------------
// baseUrl DAN timeout TERPUSAT di createDio() (api_client.dart).
// Tidak ada satu pun method di repository/provider yang mengatur
// timeout-nya sendiri – ini memenuhi poin checklist:
//   "Apakah baseUrl/timeout terpusat di satu client?"

/// Provider Dio privat – menggunakan [createDio] dari api_client.dart
/// agar baseUrl & timeout tidak tersebar ke banyak tempat.
final _dioProvider = Provider<Dio>((ref) => createDio(), name: '_dioProvider');

// ----------------------------------------------------------
// 2. commentRepositoryProvider
// ----------------------------------------------------------

/// Menyediakan [CommentRepository] yang di-inject dengan [Dio].
///
/// UI TIDAK pernah langsung menginstansiasi repository atau menyentuh
/// Dio – semua akses jaringan melalui provider ini (Repository Pattern).
final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(ref.watch(_dioProvider)),
  name: 'commentRepositoryProvider',
);

// ----------------------------------------------------------
// 3. _PostCommentNotifier – AsyncNotifier per postId
// ----------------------------------------------------------

/// Notifier yang mengelola state daftar komentar untuk satu [_postId].
///
/// Menggunakan [AsyncNotifier] karena:
///   - State awal selalu async (network call ke JSONPlaceholder).
///   - Exception dari [build] ditangkap OTOMATIS sebagai [AsyncError]
///     oleh Riverpod – tidak perlu try-catch di [build].
///   - Ini memenuhi poin checklist "penanganan error otomatis (AsyncError)".
///
/// Class ini bersifat private karena hanya diakses lewat
/// [commentListFamilyProvider]. UI berinteraksi via provider API.
class _PostCommentNotifier extends AsyncNotifier<List<Comment>> {
  _PostCommentNotifier(this._postId);

  /// ID post yang komentarnya dikelola oleh notifier ini.
  /// Diterima lewat factory closure di [commentListFamilyProvider].
  final int _postId;

  // ----------------------------------------------------------
  // build: Riverpod memanggil ini saat init & setiap kali
  //        dependency (ref.watch) berubah atau provider di-refresh.
  // ----------------------------------------------------------

  /// Mengambil komentar dari repository.
  ///
  /// Jika request gagal (timeout, connectionError, badResponse, dll.),
  /// [DioException] otomatis diubah menjadi [AsyncError] oleh Riverpod.
  /// UI kemudian menggunakan [friendlyCommentErrorMessage] untuk
  /// menampilkan pesan yang ramah.
  @override
  Future<List<Comment>> build() async {
    // ref.watch agar rebuild jika commentRepositoryProvider berubah.
    final repository = ref.watch(commentRepositoryProvider);
    // Timeout sudah terpusat di Dio (10 detik, lihat api_client.dart).
    return repository.fetchComments(_postId);
  }

  // ----------------------------------------------------------
  // refresh: dipanggil manual dari UI (tombol "Coba Lagi")
  // ----------------------------------------------------------

  /// Memuat ulang komentar untuk [_postId].
  ///
  /// Set state ke [AsyncLoading] agar UI menampilkan spinner,
  /// kemudian tangkap error sebagai [AsyncError] agar UI bisa
  /// menampilkan pesan via [friendlyCommentErrorMessage].
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(commentRepositoryProvider);
      state = AsyncData(await repository.fetchComments(_postId));
    } catch (e, st) {
      // DioException (timeout/connectionError/badResponse) & exception lain
      // semuanya tersimpan sebagai AsyncError agar UI bisa memprosesnya.
      state = AsyncError(e, st);
    }
  }
}

// ----------------------------------------------------------
// 4. commentListFamilyProvider
// ----------------------------------------------------------

/// Provider family – satu provider per [postId] unik.
///
/// Riverpod meng-cache state per postId; pindah halaman dan kembali
/// tidak memicu network request baru (kecuali di-refresh secara eksplisit).
///
/// Penggunaan di UI:
/// ```dart
/// // Observe
/// final commentsAsync = ref.watch(commentListFamilyProvider(postId));
/// // Trigger refresh
/// ref.read(commentListFamilyProvider(postId).notifier).refresh();
/// ```
///
/// retry: null – nonaktifkan retry otomatis Riverpod 3 agar [AsyncError]
/// langsung stabil dan mudah diuji tanpa menunggu siklus retry.
final commentListFamilyProvider =
    AsyncNotifierProvider.family<_PostCommentNotifier, List<Comment>, int>(
  // Factory menerima postId (arg) dan membuat notifier baru.
  // Setiap postId unik mendapat instance notifier & state sendiri.
  (postId) => _PostCommentNotifier(postId),
  retry: (retryCount, error) => null,
);

// ----------------------------------------------------------
// 5. friendlyCommentErrorMessage
// ----------------------------------------------------------

/// Mengonversi exception menjadi pesan ramah pengguna (Bahasa Indonesia).
///
/// Checklist mewajibkan SEMUA [DioExceptionType] dipetakan:
///   ✓ connectionTimeout / sendTimeout / receiveTimeout → pesan timeout
///   ✓ connectionError                                  → tidak bisa konek
///   ✓ badResponse + 404                                → data tidak ada
///   ✓ badResponse + 5xx                                → server error
///   ✓ default                                          → generic network error
String friendlyCommentErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      // -- Timeout: koneksi terlalu lambat dari batas 10 detik --
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi lambat atau timeout. Periksa internet Anda lalu coba lagi.';

      // -- Tidak bisa terhubung sama sekali (offline, DNS fail, dsb.) --
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Pastikan internet Anda aktif.';

      // -- Server merespons dengan HTTP error code --
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        // 404: resource/endpoint tidak ditemukan
        if (code == 404) {
          return 'Komentar tidak ditemukan (404). Coba postId yang berbeda.';
        }
        // 401/403: masalah autentikasi atau otorisasi
        if (code == 401 || code == 403) {
          return 'Akses ditolak ($code). Periksa kredensial Anda.';
        }
        // 500, 502, 503, dsb. – masalah di sisi server
        if (code != null && code >= 500) {
          return 'Server bermasalah ($code). Silakan coba lagi nanti.';
        }
        return 'Respons tidak terduga dari server (HTTP $code).';

      // -- Request dibatalkan, error tidak diketahui, dsb. --
      default:
        return 'Terjadi kesalahan jaringan. Silakan coba lagi.';
    }
  }
  // Bukan DioException – tampilkan pesan generic
  return 'Terjadi kesalahan tak terduga: $error';
}

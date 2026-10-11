// ============================================================
// Repository: CommentRepository
//
// Bertanggung jawab PENUH atas komunikasi jaringan untuk comments.
// UI TIDAK boleh menyentuh Dio secara langsung – semua request
// harus melalui class ini (Repository Pattern).
// ============================================================

import 'package:dio/dio.dart';
import '../models/comment.dart';

/// Repository yang mengambil data komentar dari JSONPlaceholder.
///
/// Timeout sudah terpusat di [Dio] yang di-inject (lihat api_client.dart),
/// sehingga tidak perlu di-set ulang di setiap method.
class CommentRepository {
  /// [_dio] di-inject dari luar agar:
  ///   1. Mudah di-mock saat unit testing.
  ///   2. Konfigurasi (baseUrl, timeout) tetap terpusat di satu tempat.
  CommentRepository(this._dio);

  final Dio _dio;

  // ----------------------------------------------------------
  // fetchComments
  // ----------------------------------------------------------

  /// Mengambil semua komentar untuk post dengan [postId] tertentu.
  ///
  /// Endpoint: `GET /comments?postId={postId}`
  ///
  /// Timeout sudah dikonfigurasi di [Dio] (connectTimeout &
  /// receiveTimeout = 10 detik), jadi tidak perlu timeout lokal.
  ///
  /// Jika request gagal (timeout, no-connection, badResponse),
  /// [DioException] akan di-propagate ke caller (provider)
  /// yang kemudian mengubahnya menjadi [AsyncError].
  Future<List<Comment>> fetchComments(int postId) async {
    // Dio.get<List> memastikan response.data langsung bertipe List,
    // sehingga tidak perlu cast manual yang bisa crash.
    final response = await _dio.get<List>(
      '/comments',
      queryParameters: {'postId': postId}, // query string: ?postId=postId
    );

    // response.data bisa null (misalnya server return body kosong),
    // gunakan ?? [] sebagai fallback aman.
    final data = response.data ?? [];

    // whereType<Map<String,dynamic>>() memfilter elemen yang tidak valid
    // (bukan Map), kemudian setiap Map di-parse via Comment.fromJson.
    return data
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
  }
}

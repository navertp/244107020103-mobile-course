// ============================================================
// Unit Test: Comment.fromJson
//
// Menguji bahwa model Comment:
//   1. Happy path  – semua field lengkap & bertipe benar.
//   2. Edge case   – field hilang (null-safe fallback ke default).
//   3. Edge case   – nilai null eksplisit di JSON.
//   4. Edge case   – tipe num berbeda (double) tetap dikonversi ke int.
//   5. Edge case   – JSON kosong sepenuhnya (semua field hilang).
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:week4_api/data/models/comment.dart';

void main() {
  // ==========================================================
  // Group: Comment.fromJson
  // ==========================================================
  group('Comment.fromJson', () {
    // --------------------------------------------------------
    // 1. Happy Path: semua field ada dan bertipe benar
    // --------------------------------------------------------
    test('happy path – semua field lengkap', () {
      final json = {
        'postId': 1,
        'id': 5,
        'name': 'Alice',
        'email': 'alice@example.com',
        'body': 'Great post!',
      };

      final comment = Comment.fromJson(json);

      expect(comment.postId, 1);
      expect(comment.id, 5);
      expect(comment.name, 'Alice');
      expect(comment.email, 'alice@example.com');
      expect(comment.body, 'Great post!');
    });

    // --------------------------------------------------------
    // 2. Edge Case: field hilang sama sekali (kunci tidak ada)
    //    fromJson harus fallback ke nilai default, BUKAN crash.
    //    Ini adalah kasus yang paling sering membuat fromJson
    //    naive (dengan cast langsung) melempar TypeError.
    // --------------------------------------------------------
    test('edge case – semua field hilang → fallback ke default', () {
      // JSON kosong: tidak ada satu pun key yang diharapkan.
      final json = <String, dynamic>{};

      // Tidak boleh throw apapun.
      final comment = Comment.fromJson(json);

      // Semua field harus menggunakan nilai default yang aman.
      expect(comment.postId, 0, reason: 'postId harus default 0 jika hilang');
      expect(comment.id, 0, reason: 'id harus default 0 jika hilang');
      expect(comment.name, '', reason: 'name harus default "" jika hilang');
      expect(comment.email, '', reason: 'email harus default "" jika hilang');
      expect(comment.body, '', reason: 'body harus default "" jika hilang');
    });

    // --------------------------------------------------------
    // 3. Edge Case: nilai null eksplisit di JSON
    //    Berbeda dengan field hilang – di sini key ada tapi nil.
    // --------------------------------------------------------
    test('edge case – nilai null eksplisit → fallback ke default', () {
      final json = <String, dynamic>{
        'postId': null,
        'id': null,
        'name': null,
        'email': null,
        'body': null,
      };

      final comment = Comment.fromJson(json);

      expect(comment.postId, 0);
      expect(comment.id, 0);
      expect(comment.name, '');
      expect(comment.email, '');
      expect(comment.body, '');
    });

    // --------------------------------------------------------
    // 4. Edge Case: postId & id bertipe double (kadang API
    //    mengembalikan angka desimal seperti 1.0 bukan 1).
    //    Cast (as num?)?.toInt() harus menangani ini.
    // --------------------------------------------------------
    test('edge case – postId/id bertipe double → dikonversi ke int', () {
      final json = <String, dynamic>{
        'postId': 2.0, // double, bukan int
        'id': 10.0,
        'name': 'Bob',
        'email': 'bob@test.com',
        'body': 'Hello',
      };

      final comment = Comment.fromJson(json);

      // Harus 2 dan 10 sebagai int, bukan 2.0 dan 10.0.
      expect(comment.postId, 2);
      expect(comment.id, 10);
    });

    // --------------------------------------------------------
    // 5. Edge Case: sebagian field hilang, sebagian ada.
    //    Field yang ada harus diparsing benar; yang hilang fallback.
    // --------------------------------------------------------
    test('edge case – sebagian field hilang', () {
      final json = <String, dynamic>{
        'postId': 3,
        // 'id' sengaja dihilangkan
        'name': 'Charlie',
        // 'email' sengaja dihilangkan
        'body': 'Partial data',
      };

      final comment = Comment.fromJson(json);

      expect(comment.postId, 3);
      expect(comment.id, 0, reason: 'id fallback ke 0 karena tidak ada di JSON');
      expect(comment.name, 'Charlie');
      expect(comment.email, '', reason: 'email fallback ke "" karena tidak ada di JSON');
      expect(comment.body, 'Partial data');
    });

    // --------------------------------------------------------
    // 6. Verifikasi toJson → fromJson round-trip
    //    Memastikan serialisasi dan deserialisasi konsisten.
    // --------------------------------------------------------
    test('round-trip: fromJson(toJson(comment)) == comment', () {
      const original = Comment(
        postId: 7,
        id: 42,
        name: 'Diana',
        email: 'diana@example.com',
        body: 'Round-trip test body.',
      );

      final restored = Comment.fromJson(original.toJson());

      // == operator didefinisikan di Comment menggunakan semua field.
      expect(restored, original);
    });
  });
}

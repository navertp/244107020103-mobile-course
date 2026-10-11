// ============================================================
// Model: Comment
// Merepresentasikan satu item dari endpoint
//   GET /comments?postId={id}   (JSONPlaceholder)
// ============================================================

/// Model data untuk komentar dari JSONPlaceholder.
///
/// Setiap field menggunakan null-safe casting (`as Type?`)
/// diikuti operator `?? defaultValue` agar tidak crash
/// ketika server mengembalikan field yang hilang atau bertipe berbeda.
class Comment {
  const Comment({
    required this.postId,
    required this.id,
    required this.name,
    required this.email,
    required this.body,
  });

  /// ID post induk dari komentar ini.
  final int postId;

  /// ID unik komentar.
  final int id;

  /// Nama pemberi komentar.
  final String name;

  /// Email pemberi komentar.
  final String email;

  /// Isi teks komentar.
  final String body;

  // ----------------------------------------------------------
  // Factory constructor: fromJson
  // ----------------------------------------------------------

  /// Membuat [Comment] dari map JSON.
  ///
  /// **Null-safe**: setiap akses key di-cast ke tipe nullable (`as Type?`),
  /// kemudian fallback ke nilai default (`?? defaultValue`) jika null.
  /// Ini mencegah [TypeError] / cast exception saat field hilang
  /// atau tipe tidak sesuai yang bisa terjadi di production.
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      // (json['postId'] as num?) menangani int maupun double dari JSON.
      // ?.toInt() konversi ke int. ?? 0 adalah fallback jika null.
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,

      // as String? lalu ?? '' agar tidak crash jika field absen.
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
    );
  }

  // ----------------------------------------------------------
  // toJson – berguna untuk serialisasi & debugging
  // ----------------------------------------------------------

  /// Mengonversi [Comment] ke Map JSON.
  Map<String, dynamic> toJson() => {
        'postId': postId,
        'id': id,
        'name': name,
        'email': email,
        'body': body,
      };

  @override
  String toString() =>
      'Comment(postId: $postId, id: $id, name: $name, email: $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment &&
          runtimeType == other.runtimeType &&
          postId == other.postId &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          body == other.body;

  @override
  int get hashCode =>
      postId.hashCode ^ id.hashCode ^ name.hashCode ^ email.hashCode ^ body.hashCode;
}

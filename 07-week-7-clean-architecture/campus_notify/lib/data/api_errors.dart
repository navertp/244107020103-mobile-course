// lib/data/api_errors.dart
//
// Pemetaan DioException → pesan ramah pengguna (user-friendly).
//
// PRINSIP:
//   • UI hanya menerima String pesan, bukan DioException mentah.
//   • Kode HTTP spesifik (401, 403, 404, 422, 5xx) dipetakan ke pesan
//     dalam Bahasa Indonesia.
//   • Timeout & koneksi offline mendapat pesan tersendiri.
//   • Fungsi [friendlyMessage] adalah pure function → mudah diuji.

import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// Pesan-pesan standar
// ---------------------------------------------------------------------------

const _kMsgUnauthorized =
    'Sesi kamu telah berakhir. Silakan masuk kembali.';
const _kMsgForbidden =
    'Kamu tidak memiliki akses ke fitur ini.';
const _kMsgNotFound =
    'Data yang diminta tidak ditemukan.';
const _kMsgUnprocessable =
    'Data yang dikirim tidak valid. Periksa kembali isian kamu.';
const _kMsgServer =
    'Terjadi kesalahan pada server. Coba beberapa saat lagi.';
const _kMsgTimeout =
    'Koneksi terlalu lama. Periksa jaringan kamu dan coba lagi.';
const _kMsgOffline =
    'Tidak ada koneksi internet. Periksa pengaturan jaringan kamu.';
const _kMsgUnknown =
    'Terjadi kesalahan. Coba lagi atau hubungi tim kami.';

// ---------------------------------------------------------------------------
// API publik
// ---------------------------------------------------------------------------

/// Ubah [DioException] menjadi pesan singkat, ramah pengguna.
///
/// UI memanggil fungsi ini dan hanya menampilkan [String] hasilnya —
/// tidak perlu tahu detail teknis DioException.
///
/// ```dart
/// } on DioException catch (e) {
///   final msg = friendlyMessage(e);
///   showSnackBar(context, msg);
/// }
/// ```
String friendlyMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return _kMsgTimeout;

    case DioExceptionType.connectionError:
      // Termasuk SocketException (offline) dan SSL error.
      return _kMsgOffline;

    case DioExceptionType.badResponse:
      return _statusMessage(e.response?.statusCode);

    case DioExceptionType.cancel:
      // Request dibatalkan secara eksplisit; biasanya tidak perlu notifikasi.
      return _kMsgUnknown;

    case DioExceptionType.badCertificate:
      return 'Sertifikat keamanan tidak valid. Hubungi tim kami.';

    case DioExceptionType.unknown:
    default:
      return _kMsgUnknown;
  }
}

/// Ubah [DioException] menjadi [AppError] berstruktur
/// (opsional; berguna jika UI butuh kode error, bukan hanya pesan).
AppError toAppError(DioException e) => AppError(
      message: friendlyMessage(e),
      statusCode: e.response?.statusCode,
      isUnauthorized: e.response?.statusCode == 401,
      isOffline: e.type == DioExceptionType.connectionError,
    );

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Representasi terstruktur dari error API yang sudah di-parse.
/// UI consume ini; tidak perlu tahu tentang Dio.
class AppError {
  const AppError({
    required this.message,
    this.statusCode,
    this.isUnauthorized = false,
    this.isOffline = false,
  });

  /// Pesan ramah pengguna, siap ditampilkan di UI.
  final String message;

  /// Kode HTTP asli (null jika bukan badResponse / timeout / offline).
  final int? statusCode;

  /// `true` jika server mengembalikan 401 → perlu re-login.
  final bool isUnauthorized;

  /// `true` jika tidak ada koneksi internet sama sekali.
  final bool isOffline;

  @override
  String toString() => 'AppError($statusCode: $message)';
}

// ---------------------------------------------------------------------------
// Internal helper
// ---------------------------------------------------------------------------

String _statusMessage(int? code) {
  switch (code) {
    case 401:
      return _kMsgUnauthorized;
    case 403:
      return _kMsgForbidden;
    case 404:
      return _kMsgNotFound;
    case 422:
      return _kMsgUnprocessable;
    default:
      if (code != null && code >= 500) return _kMsgServer;
      return _kMsgUnknown;
  }
}

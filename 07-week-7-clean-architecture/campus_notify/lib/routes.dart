// lib/routes.dart
//
// Satu-satunya sumber kebenaran untuk semua string rute.
// Dipakai oleh:
//   • GoRouter (main.dart)       – definisi path
//   • push_service.dart          – routeFromMessage()
//   • api_errors.dart            – redirect ke /login saat 401
//   • test/auth_push_test.dart   – verifikasi tanpa Firebase
//
// ATURAN: jangan tulis string rute mentah di tempat lain.

// ─── Konstanta top-level (direkomendasikan untuk dipakai di kode baru) ────────

/// Rute beranda – hanya dapat diakses setelah login.
const kRouteHome = '/';

/// Rute halaman login.
const kRouteLogin = '/login';

/// Prefix segmen path pengumuman.
const kRouteAnnouncementPrefix = '/pengumuman';

/// Pola path GoRouter untuk halaman detail pengumuman.
const kRouteAnnouncementPattern = '/pengumuman/:id';

/// Buat rute navigasi ke pengumuman tertentu.
///
/// ```dart
/// router.push(announcementRoute('42')); // → '/pengumuman/42'
/// ```
String announcementRoute(String id) => '$kRouteAnnouncementPrefix/$id';

// ─── Fungsi murni (pure function) ─────────────────────────────────────────────

/// Ekstrak rute navigasi dari payload FCM `data` map.
///
/// Aturan:
///   1. Jika key `route` tidak ada, kembalikan [kRouteHome] (`/`).
///   2. Jika value tidak diawali `/`, tambahkan prefix `/`.
///   3. Hanya string; tidak ada akses Firebase / BuildContext.
///
/// Dapat diuji secara unit tanpa mock Firebase apapun:
/// ```dart
/// expect(routeFromMessage({}), '/');
/// expect(routeFromMessage({'route': 'pengumuman/3'}), '/pengumuman/3');
/// expect(routeFromMessage({'route': '/pengumuman/3'}), '/pengumuman/3');
/// ```
String routeFromMessage(Map<String, dynamic> data) {
  final raw = data['route'] as String?;
  if (raw == null || raw.isEmpty) return kRouteHome;
  return raw.startsWith('/') ? raw : '/$raw';
}

// ─── Kelas kompatibilitas (tetap ada agar kode lama tidak rusak) ──────────────

/// @deprecated Gunakan konstanta top-level (`kRouteHome`, `kRouteLogin`, dll.)
/// dan fungsi [announcementRoute] sebagai gantinya.
class AppRoutes {
  AppRoutes._();

  static const login = kRouteLogin;
  static const home = kRouteHome;
  static const announcementPattern = kRouteAnnouncementPattern;
  static String announcement(String id) => announcementRoute(id);
}
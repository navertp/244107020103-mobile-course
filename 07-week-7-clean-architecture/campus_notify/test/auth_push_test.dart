// test/auth_push_test.dart
//
// Unit test untuk logika di sekitar Firebase – TANPA Firebase sungguhan.
//
// Yang diuji:
//   • routeFromMessage()   – parsing payload FCM → rute (pure function)
//   • friendlyMessage()    – mapping DioException → pesan UI (pure function)
//   • FakeTokenStore       – simulasi login/logout state
//
// Tidak ada import firebase_messaging / firebase_core di sini.
// Semua yang diuji adalah fungsi murni dan model sederhana.

import 'package:campus_notify/data/api_errors.dart';
import 'package:campus_notify/routes.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fake pengganti flutter_secure_storage (tanpa plugin native) ───────────────

class FakeTokenStore {
  String? access;
  String? refresh;

  bool get isLoggedIn => access != null && access!.isNotEmpty;

  void save({required String a, required String r}) {
    access = a;
    refresh = r;
  }

  void clear() {
    access = null;
    refresh = null;
  }
}

// ─── Helper untuk membuat DioException palsu ──────────────────────────────────

DioException _fakeDioError(
  DioExceptionType type, {
  int? statusCode,
}) {
  final opts = RequestOptions(path: '/test');
  return DioException(
    requestOptions: opts,
    type: type,
    response: statusCode != null
        ? Response(requestOptions: opts, statusCode: statusCode)
        : null,
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // Group 1 – routeFromMessage (lib/routes.dart)
  // ══════════════════════════════════════════════════════════════════════════
  group('routeFromMessage', () {
    test('data kosong → kembalikan kRouteHome (/)', () {
      expect(routeFromMessage({}), equals(kRouteHome));
    });

    test("route tanpa slash awal → ditambahkan '/'", () {
      expect(
        routeFromMessage({'route': 'pengumuman/3'}),
        equals('/pengumuman/3'),
      );
    });

    test('route dengan slash awal → tidak berubah', () {
      expect(
        routeFromMessage({'route': '/pengumuman/3'}),
        equals('/pengumuman/3'),
      );
    });

    test('route string kosong → kembalikan /', () {
      expect(routeFromMessage({'route': ''}), equals('/'));
    });

    test('route null explicit → kembalikan /', () {
      // ignore: prefer_const_constructors
      expect(routeFromMessage({'route': null}), equals('/'));
    });

    test('route kRouteLogin → dikembalikan tanpa modifikasi', () {
      expect(routeFromMessage({'route': kRouteLogin}), equals('/login'));
    });

    test('data payload membawa id pengumuman', () {
      const data = {'route': '/pengumuman/3', 'id': '3'};
      expect(data['id'], '3');
      expect(routeFromMessage(data), '/pengumuman/3');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Group 2 – announcementRoute (lib/routes.dart)
  // ══════════════════════════════════════════════════════════════════════════
  group('announcementRoute', () {
    test('menghasilkan path /pengumuman/<id>', () {
      expect(announcementRoute('42'), '/pengumuman/42');
    });

    test('konsisten dengan kRouteAnnouncementPrefix', () {
      expect(announcementRoute('1').startsWith(kRouteAnnouncementPrefix), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Group 3 – FakeTokenStore (simulasi auth state)
  // ══════════════════════════════════════════════════════════════════════════
  group('FakeTokenStore – simulasi auth state', () {
    test('isLoggedIn true saat access token ada', () {
      final store = FakeTokenStore()..access = 'mock-access';
      expect(store.isLoggedIn, isTrue);
    });

    test('isLoggedIn false setelah logout (clear)', () {
      final store = FakeTokenStore()
        ..access = 'mock-access'
        ..clear();
      expect(store.isLoggedIn, isFalse);
    });

    test('isLoggedIn false saat access null', () {
      final store = FakeTokenStore();
      expect(store.isLoggedIn, isFalse);
    });

    test('refresh gagal (kosong) → sesi harus dibersihkan', () {
      final store = FakeTokenStore()
        ..access = 'old-access'
        ..refresh = '';

      // Simulasi logika api_client: refresh token kosong → clear
      final needsLogin = (store.refresh ?? '').isEmpty;
      if (needsLogin) store.clear();

      expect(store.isLoggedIn, isFalse);
      expect(needsLogin, isTrue);
    });

    test('save() menyimpan access dan refresh', () {
      final store = FakeTokenStore();
      store.save(a: 'acc', r: 'ref');
      expect(store.access, 'acc');
      expect(store.refresh, 'ref');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Group 4 – friendlyMessage / toAppError (lib/data/api_errors.dart)
  // ══════════════════════════════════════════════════════════════════════════
  group('friendlyMessage', () {
    test('401 → pesan sesi berakhir', () {
      final err = _fakeDioError(DioExceptionType.badResponse, statusCode: 401);
      expect(friendlyMessage(err), contains('Sesi'));
    });

    test('403 → pesan tidak memiliki akses', () {
      final err = _fakeDioError(DioExceptionType.badResponse, statusCode: 403);
      expect(friendlyMessage(err), contains('akses'));
    });

    test('404 → pesan data tidak ditemukan', () {
      final err = _fakeDioError(DioExceptionType.badResponse, statusCode: 404);
      expect(friendlyMessage(err), contains('tidak ditemukan'));
    });

    test('422 → pesan data tidak valid', () {
      final err = _fakeDioError(DioExceptionType.badResponse, statusCode: 422);
      expect(friendlyMessage(err), contains('tidak valid'));
    });

    test('500 → pesan kesalahan server', () {
      final err = _fakeDioError(DioExceptionType.badResponse, statusCode: 500);
      expect(friendlyMessage(err), contains('server'));
    });

    test('connectionTimeout → pesan jaringan', () {
      final err = _fakeDioError(DioExceptionType.connectionTimeout);
      expect(friendlyMessage(err), contains('jaringan'));
    });

    test('receiveTimeout → pesan jaringan', () {
      final err = _fakeDioError(DioExceptionType.receiveTimeout);
      expect(friendlyMessage(err), contains('jaringan'));
    });

    test('connectionError (offline) → pesan koneksi internet', () {
      final err = _fakeDioError(DioExceptionType.connectionError);
      expect(friendlyMessage(err), contains('internet'));
    });
  });

  group('toAppError', () {
    test('401 → isUnauthorized = true', () {
      final err = _fakeDioError(DioExceptionType.badResponse, statusCode: 401);
      final appErr = toAppError(err);
      expect(appErr.isUnauthorized, isTrue);
      expect(appErr.statusCode, 401);
    });

    test('connectionError → isOffline = true', () {
      final err = _fakeDioError(DioExceptionType.connectionError);
      final appErr = toAppError(err);
      expect(appErr.isOffline, isTrue);
      expect(appErr.isUnauthorized, isFalse);
    });

    test('message tidak kosong untuk semua tipe error', () {
      final types = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ];
      for (final t in types) {
        final appErr = toAppError(_fakeDioError(t));
        expect(appErr.message, isNotEmpty, reason: 'Tipe $t punya pesan kosong');
      }
    });
  });
}

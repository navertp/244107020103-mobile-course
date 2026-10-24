// lib/messaging/push_service.dart
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  PushService – Campus Notify                                            │
// │                                                                         │
// │  Stack  : firebase_messaging · flutter_local_notifications              │
// │           flutter_secure_storage · go_router · Riverpod                │
// │                                                                         │
// │  Platform notes:                                                        │
// │    [ANDROID 13+]  – khusus/berbeda untuk Android 13+ (API 33+)         │
// │    [iOS]          – khusus/berbeda untuk iOS                            │
// │    [NO-CONTEXT]   – tidak boleh mengakses BuildContext                  │
// └─────────────────────────────────────────────────────────────────────────┘

import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../routes.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Konstanta & singleton internal
// ---------------------------------------------------------------------------

/// Base-URL backend.  Ganti dengan env-variable nyata di produksi.
/// JANGAN hardcode URL yang mengandung secret / API key di sini.
const _kDevicesEndpoint = 'https://example-campus-api.test/api/devices';

const _kTopicKampus = 'pengumuman-kampus';

/// Channel Android untuk notifikasi pengumuman.
const _kChannelId = 'pengumuman';
const _kChannelName = 'Pengumuman Kampus';

/// Instance plugin local-notification (file-level, bukan BuildContext).
final _local = FlutterLocalNotificationsPlugin();

/// Storage untuk menyimpan FCM token terakhir (de-duplikasi POST /devices).
/// Opsi Android bawaan untuk penyimpanan terenkripsi.
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(),
);
const _kFcmTokenKey = 'fcm_device_token';

// ---------------------------------------------------------------------------
// Notifier yang aman dibaca dari UI (tanpa BuildContext)
// ---------------------------------------------------------------------------

/// Token terpotong untuk ditampilkan di Home.  JANGAN tampilkan token penuh.
final fcmTokenNotifier = ValueNotifier<String?>(null);

/// Rute pending saat app di-tap dari local notification.
String? pendingDeepLink;

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Kembalikan 12 karakter pertama token + "…" agar tidak bocor ke log/UI.
String shortToken(String? token) {
  if (token == null || token.isEmpty) return '-';
  return token.length <= 12 ? token : '${token.substring(0, 12)}…';
}

// ---------------------------------------------------------------------------
// 1. BACKGROUND HANDLER  [NO-CONTEXT]
// ---------------------------------------------------------------------------
//
// WAJIB berupa fungsi TOP-LEVEL (bukan method kelas).
// @pragma('vm:entry-point') mencegah tree-shaking saat AOT compile.
// Jangan akses BuildContext / Riverpod karena widget tree belum ada –
// Android menjalankan handler ini di Dart isolate TERPISAH.
//
@pragma('vm:entry-point') // ← WAJIB; tanpa ini handler tidak dijalankan di AOT
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // [NO-CONTEXT] – Flutter Engine di-init plugin, tapi widget tree BELUM ada.
  //
  // BOLEH: simpan data ringan ke SecureStorage / file lokal.
  // TIDAK BOLEH: BuildContext, Navigator, GoRouter, Riverpod Provider.
  //
  // Simpan rute agar bisa dikonsumsi saat pengguna tap notifikasi.
  // routeFromMessage() adalah pure function dari routes.dart – aman dipakai
  // di sini karena tidak menyentuh Firebase / BuildContext.
  final route = routeFromMessage(message.data);
  // Simpan hanya jika bukan rute default ('/') agar tidak noise.
  if (route != kRouteHome) {
    await _storage.write(key: 'pending_route', value: route);
  }
  // Log terpotong – TIDAK pernah cetak token/secret penuh.
  debugPrint('[FCM-BG] pesan diterima, topic=${message.from}');
}

/// Daftarkan background handler ke Firebase.
/// Dipanggil di main() SEBELUM runApp().  [NO-CONTEXT]
void registerBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

// ---------------------------------------------------------------------------
// 2. INISIALISASI LOCAL NOTIFICATIONS
// ---------------------------------------------------------------------------

Future<void> initLocalNotifications() async {
  // [ANDROID] '@mipmap/ic_launcher' selalu ada; ganti dengan ikon khusus
  // '@drawable/ic_notification' (putih transparan) untuk tampilan status bar.
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // [iOS] Izin ditangani oleh FCM requestPermission(); jangan minta dua kali.
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  await _local.initialize(
    settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    onDidReceiveNotificationResponse: (response) {
      // [NO-CONTEXT] Simpan ke pendingDeepLink; navigasi via _onRoute closure.
      final route = response.payload;
      if (route != null) {
        pendingDeepLink = route;
        _onRoute?.call(route);
      }
    },
    // Handler tap local notification saat app di background (Android 12+).
    onDidReceiveBackgroundNotificationResponse: _onBgNotificationTap,
  );

  // [ANDROID 13+] Buat channel SEBELUM show(); wajib ada di API 26+.
  // Di bawah API 26, panggilan ini diabaikan.
  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          description: 'Notifikasi pengumuman dari kampus',
          importance: Importance.high,
          playSound: true,
        ),
      );
}

/// Handler tap local notification background – wajib top-level.  [NO-CONTEXT]
@pragma('vm:entry-point')
void _onBgNotificationTap(NotificationResponse response) {
  final route = response.payload;
  if (route != null) pendingDeepLink = route;
}

// ---------------------------------------------------------------------------
// 3. PERMISSION & TOKEN
// ---------------------------------------------------------------------------

/// Minta izin notifikasi dari pengguna.
///
/// [ANDROID 13+] POST_NOTIFICATIONS (API 33+) di-request runtime oleh plugin.
///   Di bawah API 33, langsung granted tanpa dialog.
/// [iOS] Menampilkan popup permission standar iOS.
Future<bool> requestNotificationPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    // [iOS] provisional: true → granted tanpa dialog (silent delivery only).
    provisional: false,
    carPlay: false,
    criticalAlert: false,
    announcement: false,
  );

  // [ANDROID 13+] Status 'authorized' jika pengguna setuju dialog.
  //   Di bawah API 33, status selalu 'authorized' tanpa dialog.
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

/// Ambil token awal dan pantau pembaruan.
///
/// [iOS] Firebase otomatis tukar APNs token → FCM token.
///   Pastikan APNs key/certificate sudah dikonfigurasi di Firebase Console.
Future<void> initFcmToken({
  required Future<void> Function(String token) onToken,
}) async {
  // [iOS] getToken() bisa null jika APNs belum siap; onTokenRefresh sebagai fallback.
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) await onToken(token);

  // onTokenRefresh WAJIB ada – token berubah setelah reinstall / data-clear / rotate.
  FirebaseMessaging.instance.onTokenRefresh.listen(onToken);
}

/// Kirim token ke backend POST /devices.
/// De-duplikasi lewat SecureStorage; token TIDAK pernah di-log penuh.  [NO-CONTEXT]
Future<void> _sendTokenToBackend(String token) async {
  // Jangan POST jika token belum berubah.
  final stored = await _storage.read(key: _kFcmTokenKey);
  if (stored == token) return;

  try {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Baca access token dari secure storage untuk header Authorization.
    final accessToken = await _storage.read(key: 'access_token');

    await dio.post(
      _kDevicesEndpoint,
      data: {
        'fcm_token': token,
        // [ANDROID/iOS] Beri tahu backend tipe platform device.
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
      options: Options(
        headers: {
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Simpan token yang berhasil dikirim untuk de-duplikasi berikutnya.
    await _storage.write(key: _kFcmTokenKey, value: token);
    debugPrint('[FCM] token dikirim ke /devices (${shortToken(token)})');
  } on DioException catch (e) {
    // Gagal register tidak boleh crash app.
    debugPrint('[FCM] gagal kirim token ke /devices: ${e.message}');
  }
}

// ---------------------------------------------------------------------------
// 4. SUBSCRIBE / UNSUBSCRIBE TOPIC
// ---------------------------------------------------------------------------

/// Berlangganan topic pengumuman kampus.
Future<void> subscribeToKampusTopic() async {
  await FirebaseMessaging.instance.subscribeToTopic(_kTopicKampus);
  debugPrint('[FCM] subscribed: $_kTopicKampus');
}

/// Berhenti berlangganan (saat logout / opt-out notifikasi).
Future<void> unsubscribeFromKampusTopic() async {
  await FirebaseMessaging.instance.unsubscribeFromTopic(_kTopicKampus);
  debugPrint('[FCM] unsubscribed: $_kTopicKampus');
}

// ---------------------------------------------------------------------------
// 5. ENTRY POINT – dipanggil setelah login berhasil
// ---------------------------------------------------------------------------

/// Inisialisasi penuh: permission → token → kirim ke backend → subscribe.
/// [NO-CONTEXT] – tidak menggunakan BuildContext.
Future<void> setupPush() async {
  final granted = await requestNotificationPermission();
  if (!granted) {
    debugPrint('[FCM] izin notifikasi ditolak');
    return;
  }

  await initFcmToken(onToken: (token) async {
    fcmTokenNotifier.value = token;
    debugPrint('[FCM] token baru: ${shortToken(token)}'); // terpotong
    await _sendTokenToBackend(token); // kirim ke POST /devices
  });

  await subscribeToKampusTopic();
}

// ---------------------------------------------------------------------------
// 6. FOREGROUND LISTENER & NAVIGASI
// ---------------------------------------------------------------------------

/// Callback navigasi yang di-set dari main() setelah router siap.
/// [NO-CONTEXT] – router.push() dipanggil lewat closure bukan context.
void Function(String route)? _onRoute;

/// Daftarkan listener pesan foreground dan klik background.
///
/// [go] adalah fungsi navigasi dari GoRouter global:
///   `listenForeground((route) => router.push(route))`
///
/// [NO-CONTEXT] – navigasi lewat GoRouter, bukan BuildContext.
void listenForeground(void Function(String route) go) {
  _onRoute = go;

  // ── FOREGROUND ──────────────────────────────────────────────────────────
  // [ANDROID] FCM TIDAK menampilkan banner otomatis saat app di foreground.
  // [iOS] Secara default juga tidak tampil (kecuali presentationOptions di-set).
  // Solusi seragam: tampilkan local notification manual.
  FirebaseMessaging.onMessage.listen((message) async {
    // routeFromMessage() dari routes.dart – konsisten dengan GoRouter.
    final route = routeFromMessage(message.data);

    // [ANDROID 13+] Mulai API 33, POST_NOTIFICATIONS harus granted
    //   agar local notification tampil – sudah dijamin di requestPermission().
    // [ANDROID] channelId harus cocok dengan channel dibuat di initLocalNotifications().
    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: 'Notifikasi pengumuman dari kampus',
      importance: Importance.high,
      priority: Priority.high,
    );

    // [iOS] DarwinNotificationDetails untuk kontrol tampilan banner iOS.
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _local.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'Pengumuman',
      body: message.notification?.body ?? '',
      notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: route, // diteruskan ke onDidReceiveNotificationResponse saat tap
    );
  });

  // ── BACKGROUND → TAP ────────────────────────────────────────────────────
  // Sistem menampilkan banner sendiri.  Event ini muncul saat pengguna tap.
  // [ANDROID/iOS] Didukung sama pada kedua platform.
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    go(routeFromMessage(message.data));
  });
}

// ---------------------------------------------------------------------------
// 7. TERMINATED STATE – dipanggil SETELAH router & auth siap
// ---------------------------------------------------------------------------

/// Tangani notifikasi yang di-tap saat app terminated.
///
/// HARUS dipanggil SETELAH `authStateProvider.future` selesai agar
/// guard route tidak memblokir navigasi ke halaman yang dilindungi.
///
/// [NO-CONTEXT] – navigasi lewat GoRouter global.
Future<void> handleTerminated(void Function(String route) go) async {
  // 1. FCM: pesan yang membuka app dari terminated.
  // [ANDROID] Tersedia segera setelah Firebase.initializeApp().
  // [iOS] APNs timing bisa berbeda; getInitialMessage() tetap reliable.
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    go(routeFromMessage(initial.data));
    return; // Sudah navigasi; cegah double-navigate.
  }

  // 2. Rute disimpan background handler (data-only message).
  final storedRoute = await _storage.read(key: 'pending_route');
  if (storedRoute != null) {
    await _storage.delete(key: 'pending_route');
    go(storedRoute);
    return;
  }

  // 3. Deep link dari tap local notification sebelum app mati.
  if (pendingDeepLink != null) {
    go(pendingDeepLink!);
    pendingDeepLink = null;
  }
}
# Campus Notify – Flutter FCM Push Service

Aplikasi notifikasi kampus berbasis Flutter dengan Firebase Cloud Messaging (FCM),
`flutter_local_notifications`, `flutter_secure_storage`, `go_router`, dan Riverpod.

---

## Arsitektur Singkat

```
main()
  ├── Firebase.initializeApp()
  ├── registerBackgroundHandler()        ← SEBELUM runApp
  ├── initLocalNotifications()           ← buat channel Android 13+
  ├── runApp(...)
  ├── await authStateProvider.future     ← tunggu auth guard siap
  ├── listenForeground(router.push)      ← foreground + bg-tap listener
  └── handleTerminated(router.push)      ← terminated tap handler

HomePage.initState()
  └── setupPush()
        ├── requestNotificationPermission()
        ├── initFcmToken(onToken: _sendTokenToBackend)
        └── subscribeToKampusTopic()
```

---

## API Contract – POST /devices

Setiap kali token FCM baru diterima (baik dari `getToken()` maupun `onTokenRefresh`),
service mengirimkan:

```http
POST https://example-campus-api.test/api/devices
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "fcm_token": "<fcm_device_token>",
  "platform": "android" | "ios"
}
```

> **Catatan keamanan**: URL backend **tidak** berisi secret/API key.  
> Ganti base URL dengan environment variable di produksi (misalnya via `--dart-define`).

De-duplikasi: token hanya di-POST jika berbeda dari yang tersimpan di `flutter_secure_storage`.

---

## AI Verification Checklist

### ✅ 1 – Background handler: fungsi top-level + `@pragma`

```dart
// lib/messaging/push_service.dart – baris 70-an
@pragma('vm:entry-point')   // ← mencegah tree-shaking AOT
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Fungsi TOP-LEVEL, bukan method kelas
}
```

**Temuan**: Handler adalah fungsi top-level di file `push_service.dart`,
bukan method kelas. Dekorator `@pragma('vm:entry-point')` hadir. ✔

---

### ✅ 2 – `onTokenRefresh` benar-benar mengirim token baru ke backend

```dart
// initFcmToken():
FirebaseMessaging.instance.onTokenRefresh.listen(onToken);

// setupPush():
await initFcmToken(onToken: (token) async {
  fcmTokenNotifier.value = token;
  await _sendTokenToBackend(token);  // ← POST /devices
});
```

`_sendTokenToBackend()` melakukan `dio.post(_kDevicesEndpoint, ...)` dengan
body `{fcm_token, platform}` dan header `Authorization`.  
Token disimpan ke `SecureStorage` setelah POST berhasil (de-duplikasi).  
**Tidak hanya dicetak ke log.** ✔

---

### ✅ 3 – Foreground memakai local notification manual

```dart
// listenForeground():
FirebaseMessaging.onMessage.listen((message) async {
  await _local.show(
    message.hashCode,
    message.notification?.title ?? 'Pengumuman',
    message.notification?.body ?? '',
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: route,
  );
});
```

FCM **tidak** menampilkan banner otomatis saat app di foreground (baik Android
maupun iOS default). Banner hanya muncul karena `flutter_local_notifications`.  
Jika baris ini dihapus → tidak ada banner saat foreground. ✔

---

### ✅ 4 – Klik dari 3 state masuk ke rute yang benar

| State App | Mekanisme | Handler | Navigasi |
|---|---|---|---|
| **Foreground** | FCM → `onMessage` → `_local.show(payload: route)` → tap banner | `onDidReceiveNotificationResponse` → `_onRoute?.call(route)` | `router.push(route)` |
| **Background** | FCM → sistem tampilkan banner → tap | `onMessageOpenedApp` → `go(route)` | `router.push(route)` |
| **Terminated** | FCM → sistem tampilkan banner → tap → buka app | `getInitialMessage()` → `go(route)` | `router.push(route)` |
| **Terminated (data-only)** | BG handler simpan ke SecureStorage → app dibuka manual | `handleTerminated()` baca `pending_route` | `router.push(route)` |

> **Catatan penting**: `handleTerminated()` dipanggil **setelah**
> `await container.read(authStateProvider.future)`, sehingga guard GoRouter
> sudah siap dan tidak memblokir navigasi ke halaman pengumuman. ✔

---

### ✅ 5 – Token/secret tidak di-hardcode, tidak di-log penuh

| Hal yang diperiksa | Status |
|---|---|
| `debugPrint` selalu memanggil `shortToken(token)` (12 karakter + "…") | ✔ |
| `fcmTokenNotifier.value = token` – UI menampilkan `shortToken()` | ✔ |
| URL backend tidak mengandung API key/secret | ✔ |
| Access token diambil dari `FlutterSecureStorage`, bukan di-hardcode | ✔ |
| `flutter_secure_storage` pakai `encryptedSharedPreferences: true` (Android) | ✔ |

---

### ✅ 6 – Bagian yang BERBEDA Android 13+ vs iOS

| Fitur | Android 13+ | iOS |
|---|---|---|
| **Runtime permission** | `POST_NOTIFICATIONS` (API 33+) harus di-request dialog; di bawah API 33 langsung granted | Dialog popup standar iOS sejak iOS 10 |
| **Token** | FCM token langsung | Firebase tukar APNs token → FCM token; butuh APNs key di Firebase Console |
| **Notification channel** | Wajib buat `AndroidNotificationChannel` sebelum `show()` (API 26+) | Tidak ada konsep channel; iOS pakai kategori |
| **Foreground banner** | Tidak tampil otomatis; wajib local notification | Tidak tampil otomatis secara default (bisa di-set via `presentationOptions`) |
| **Background isolate** | Dart isolate terpisah; `@pragma` wajib | Eksekusi background lebih terbatas; handler berjalan di main isolate |
| **`DarwinInitializationSettings`** | Diabaikan | `requestAlertPermission: false` agar tidak double-request |
| **`DarwinNotificationDetails`** | Diabaikan | Mengontrol `presentAlert`, `presentBadge`, `presentSound` |

---

### ✅ 7 – Bagian yang TIDAK BOLEH mengakses BuildContext

| Lokasi | Alasan |
|---|---|
| `firebaseMessagingBackgroundHandler()` | Berjalan di isolate terpisah tanpa widget tree |
| `_onBgNotificationTap()` | Background notification tap handler, top-level |
| `setupPush()` | Dipanggil dari `initState()` – aman, tapi tidak perlu context |
| `_sendTokenToBackend()` | Async network call, tidak ada UI |
| `handleTerminated()` | Dipanggil dari `main()` sebelum widget tree stabil |
| `listenForeground()` / callback-nya | Navigasi via `GoRouter` global, bukan `Navigator.of(context)` |

---

## Subscribe / Unsubscribe Topic

```dart
// Berlangganan (dipanggil di setupPush() otomatis)
await subscribeToKampusTopic();

// Berhenti berlangganan (saat logout / pengguna opt-out)
await unsubscribeFromKampusTopic();
```

Topic: `pengumuman-kampus`

---

## Keputusan Teknis vs Saran Umum AI

| Topik | Keputusan dalam Kode Ini | Alasan |
|---|---|---|
| De-duplikasi token POST | Simpan token ke `SecureStorage`, compare sebelum POST | Mencegah spam ke backend saat app restart |
| Navigasi dari handler | GoRouter global via closure, bukan `Navigator.of(context)` | Context tidak tersedia di semua state, GoRouter global lebih reliabel |
| Background handler body | Hanya simpan `pending_route` ke `SecureStorage` | Mencegah crash dari akses Riverpod/BuildContext di isolate terpisah |
| `handleTerminated()` setelah `authStateProvider.future` | ✔ sudah diimplementasi di `main()` | Tanpa ini, GoRouter redirect `/login` memotong deep link |
| Token logging | Selalu `shortToken()` (12 char) | Mencegah token FCM bocor ke log system (dapat dibaca tools debug) |
| iOS `DarwinInitializationSettings` | `requestAlertPermission: false` | FCM sudah request permission; double-request membingungkan pengguna |

---

## Setup Minimum

1. Tambahkan `google-services.json` (Android) dan `GoogleService-Info.plist` (iOS)
   dari Firebase Console ke direktori yang tepat.
2. Android: pastikan `minSdkVersion >= 21` di `build.gradle.kts`.
3. iOS: tambahkan *Push Notifications* capability di Xcode.
4. iOS: upload APNs Authentication Key di Firebase Console > Project Settings > Cloud Messaging.
5. Ganti `_kDevicesEndpoint` dengan URL backend nyata (via `--dart-define=API_BASE_URL=...`).

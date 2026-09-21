import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:week3_todo/providers/stats_provider.dart'; // Sesuaikan path package Anda

void main() {
  test('StatsProvider menangani state loading transisi ke data atau error', () async {
    // 1. ProviderContainer bertindak sebagai penyimpan state terisolasi khusus untuk testing.
    final container = ProviderContainer();
    addTearDown(container.dispose); // Membersihkan memori setelah test selesai.

    // 2. Saat pertama kali dibaca, provider harus berada dalam state AsyncLoading.
    final initialState = container.read(statsProvider);
    expect(initialState, isA<AsyncLoading<List<String>>>());

    // 3. Menunggu eksekusi Future di dalam method build() provider selesai.
    // Karena ada kemungkinan 30% gagal, kita bungkus dengan try-catch agar test tidak crash.
    try {
      await container.read(statsProvider.future);
    } catch (_) {
      // Exception diabaikan karena kita hanya ingin memvalidasi state akhirnya.
    }

    // 4. Setelah Future selesai, state akhir harus berupa keberhasilan (data) atau kegagalan (error).
    final finalState = container.read(statsProvider);
    expect(
      finalState.hasValue || finalState.hasError, 
      true,
      reason: 'State harus beralih ke AsyncData jika sukses, atau AsyncError jika masuk rate 30% gagal.',
    );
  });
}
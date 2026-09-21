import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// AsyncNotifier adalah kelas modern dari Riverpod untuk mengelola state asinkron.
// Kita mendefinisikan tipe kembaliannya sebagai List<String>.
class StatsNotifier extends AsyncNotifier<List<String>> {
  
  // Method build() adalah titik awal di mana data pertama kali dimuat.
  @override
  Future<List<String>> build() async {
    return _fetchStatistics();
  }

  // Method privat untuk mensimulasikan pemanggilan API/Database
  Future<List<String>> _fetchStatistics() async {
    // 1. Mensimulasikan delay jaringan selama 2 detik
    await Future.delayed(const Duration(seconds: 2));

    // 2. Mensimulasikan kemungkinan gagal sebesar 30%
    final random = Random().nextDouble();
    if (random < 0.3) {
      // Jika masuk ke dalam 30%, lempar Exception. 
      // Riverpod akan otomatis menangkap ini dan mengubah state menjadi AsyncError.
      throw Exception('Gagal mengambil data statistik dari server.');
    }

    // 3. Jika berhasil (70% kemungkinan), kembalikan data baru secara immutable.
    return [
      'Total Mahasiswa: 1,245',
      'Tingkat Kehadiran: 92%',
      'Tugas Terkumpul: 450'
    ];
  }
}

// Mendeklarasikan provider secara eksplisit.
// Provider ini bersifat global namun aman karena state-nya dikelola oleh Riverpod.
final statsProvider = AsyncNotifierProvider<StatsNotifier, List<String>>(
  StatsNotifier.new,
);
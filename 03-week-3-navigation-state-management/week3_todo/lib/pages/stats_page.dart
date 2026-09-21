import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart'; // Sesuaikan path jika berbeda

// Menggunakan ConsumerWidget agar widget ini bisa mendengarkan perubahan state Riverpod
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch dipanggil di dalam build untuk mendengarkan perubahan statsProvider.
    // statsAsync akan bertipe AsyncValue<List<String>>.
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Statistik')),
      
      // AsyncValue.when memaksa kita menangani ketiga kemungkinan state dengan aman.
      body: statsAsync.when(
        
        // Kondisi 1: State sedang proses pengambilan data (Loading)
        loading: () => const Center(child: CircularProgressIndicator()),
        
        // Kondisi 2: State mengalami kegagalan (Error)
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Terjadi Kesalahan:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                // ref.invalidate menghapus state saat ini dan memicu build() ulang di provider.
                // Pemanggilan diletakkan di dalam callback (onPressed), bukan di method build.
                onPressed: () => ref.invalidate(statsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        
        // Kondisi 3: State berhasil mendapatkan data (Success)
        data: (stats) => ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.analytics, color: Colors.indigo),
                title: Text(
                  stats[index],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
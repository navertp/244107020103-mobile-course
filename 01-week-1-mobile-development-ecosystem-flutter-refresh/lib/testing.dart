void main() {
  String nama = 'Alya';
  int semester = 3;
  final bool aktif = true;
  print(sapa(nama, semester));
  final mahasiswa = Mahasiswa(nama: nama, aktif: aktif);
  print(mahasiswa.status());
}

String sapa(String nama, int semester) => 'Halo $nama, semester $semester';

class Mahasiswa {
  Mahasiswa({required this.nama, required this.aktif});
  final String nama;
  final bool aktif;
  String status() => aktif ? '$nama aktif' : '$nama tidak aktif';
}
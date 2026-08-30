double hitungLuasPersegiPanjang(double panjang, double lebar) {
  return panjang * lebar;
}

class Profil {
  String nama;
  int nim;
  String? email;

  Profil(this.nama, this.nim, [this.email]);
}

void main() {
  double panjang = 5.0;
  double lebar = 3.0;
  double luas = hitungLuasPersegiPanjang(panjang, lebar);
  print('Luas persegi panjang: $luas');

  Profil profil = Profil('Soni', 123456);
  print('Nama: ${profil.nama}');
  print('NIM: ${profil.nim}');
  print('Email: ${profil.email?.toUpperCase() ?? 'Email tidak diisi'}');
}
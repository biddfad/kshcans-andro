# 📱 KsHcans - Flagship Indonesian Manga & Manhwa Reader (Android)

**KsHcans** adalah aplikasi pembaca manga, manhwa, dan manhua berbahasa Indonesia modern berbasis Flutter dengan performa tinggi, tampilan OLED dark mode, dan fitur pembaca tanpa jeda (*Infinity Continuous Chapter Reader*).

---

## ✨ Fitur Utama

- 📖 **Infinity Continuous Chapter Scrolling**: Pengalaman membaca tanpa batas — saat menggulir ke bawah, bab berikutnya otomatis disambung langsung di bawah bab sebelumnya tanpa perlu menekan tombol 'Next'.
- 🌐 **Dukungan Multi-Sumber (7 Ekstensi Aktif)**:
  - **MangaDex** (Multi-bahasa & Indonesia resmi)
  - **Shinigami** (Manhwa & Action update tercepat)
  - **KomikIndo** (Koleksi manga komplit)
  - **BacaKomik** (Manhwa & Manga populer)
  - **Komiku** (Koleksi klasik dan ongoing)
  - **Kiryuu** (Update harian manhwa & manhua)
  - **DoujinDesu** (Khusus mode dewasa / 18+ terisolasi)
- 🔒 **Privasi & Keamanan Tingkat Tinggi**:
  - **App Lifecycle Auto-Lock**: Otomatis mengunci aplikasi saat berpindah ke background (*recent apps*).
  - **PIN Kriptografi SHA-256**: PIN 4-digit terenkripsi dengan salt unik.
  - **Incognito Reading Mode**: Membaca tanpa menyimpan jejak riwayat bacaan.
  - **Isolasi Konten Dewasa**: Komik 18+ tidak tampil di riwayat jika mode dewasa dimatikan.
- 💾 **Download Offline Aman & Anti-Korup**:
  - Unduhan atomik dengan ekstensi sementara `.part` dan verifikasi integritas file.
  - Dukungan auto-retry jika koneksi terputus.
- ⚡ **Auto-Scroll Pintar**: Gulir otomatis dengan kontrol kecepatan responsif.
- 🎨 **Desain Modern Flagship**: Tema Gelap OLED dengan aksen warna Cyan & Ungu neon yang memanjakan mata.

---

## 🛠️ Kompilasi & Build

### Prasyarat
- Flutter SDK `>=3.13.7`
- Android SDK (API level 33+)
- Java JDK 17

### Perintah Build APK
```bash
# Ambil dependensi
flutter pub get

# Jalankan uji otomatis
flutter test

# Build APK Release dengan arsitektur split (Ukuran hemat ~19MB)
flutter build apk --release --split-per-abi
```
File APK rilis ARM64 akan berada di: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

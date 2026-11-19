# DOKUMENTASI SPESIFIKASI FITUR KSHCANS

Dokumen ini memuat spesifikasi teknis dan panduan operasional fitur-fitur aplikasi KsHcans.

---

## 1. FITUR IN-APP AUTO-UPDATER (OTA UPDATE)

### Deskripsi
Mekanisme pembaruan aplikasi langsung dari dalam antarmuka aplikasi tanpa perlu membuka browser atau melalui Google Play Store.

### Spesifikasi Teknis
- Layanan Utama: `lib/core/services/app_update_service.dart`.
- Integrasi Native:
  - Saluran MethodChannel: `kshcans/installer`.
  - Android FileProvider: `androidx.core.content.FileProvider`.
  - Jalur Penyimpanan: `android/app/src/main/res/xml/file_paths.xml` (cache-path & external-cache-path).
  - Izin Manifest: `android.permission.REQUEST_INSTALL_PACKAGES`.
- Sumber Manifest:
  - Manifest Statis: `https://raw.githubusercontent.com/biddfad/kshcans-andro/main/version.json`.
  - GitHub Releases API: `https://api.github.com/repos/biddfad/kshcans-andro/releases/latest`.
- Antarmuka Dialog:
  - Dialog modal modern dengan tema OLED gelap dan aksen cyan.
  - Ringkasan catatan rilis (changelog).
  - Progress bar streaming unduhan real-time (persentase & ukuran MB).
  - Pemicu otomatis paket installer Android saat unduhan tuntas.

---

## 2. FITUR INFINITY CONTINUOUS CHAPTER SCROLLING

### Deskripsi
Pengalaman membaca manhwa/komik mode webtoon berkesinambungan tanpa jeda, di mana bab berikutnya otomatis disambung langsung di bawah bab sebelumnya.

### Spesifikasi Teknis
- Prefetching otomatis pada sisa jarak gulir 1500px.
- Transisi pemisah bab dengan kartu cyan neon dinamis.
- Pembaruan dinamis judul bab pada App Bar dan indikator nomor halaman.
- Pencatatan otomatis status selesai baca ke SQLite.

---

## 3. FITUR KEAMANAN DAN PRIVASI (SECURITY HARDENING)

### Deskripsi
Sistem perlindungan privasi pengguna saat membaca komik di tempat umum atau meminjamkan perangkat.

### Spesifikasi Teknis
- Lifecycle Auto-Lock: Layar otomatis terkunci saat aplikasi masuk ke background / recent apps.
- Hashing Kriptografis PIN SHA-256 dengan salt lokal unik.
- Mode Penyamaran (Incognito Reading): Membaca tanpa mencatat jejak ke SQLite riwayat.
- Isolasi Konten Dewasa: Penyaringan otomatis komik 18+ saat mode dewasa dimatikan.

---

## 4. FITUR DYNAMIC REMOTE DOMAIN RESOLVER (ANTI-DOMAIN DRIFT)

### Deskripsi
Mekanisme resolusi domain dan endpoint API dinamis untuk 7 penyedia komik (Shinigami, KomikIndo, Kiryuu, BacaKomik, Komiku, DoujinDesu, MangaDex). Ketika situs komik melakukan rotasi domain atau pemblokiran ISP, konfigurasi domain dapat diperbarui secara terpusat di repositori GitHub tanpa memerlukan build ulang atau instalasi ulang APK oleh pengguna.

### Spesifikasi Teknis
- Layanan Utama: `lib/core/services/source_config_service.dart`.
- Remote Manifest: `https://raw.githubusercontent.com/biddfad/kshcans-andro/main/sources_config.json`.
- Mekanisme Penyimpanan:
  - Cache Lokal: SQLite (`app_settings` via `DBHelper.instance.getSetting('remote_sources_config')`).
  - Fallback Aman: Hardcoded domain defaults jika perangkat offline atau sinkronisasi awal gagal.
- Siklus Sinkronisasi:
  - Inisialisasi awal saat aplikasi dijalankan via `main()`.
  - Silent background sync di `initState()` layar utama tanpa memblokir render UI pengguna.
- Sentralisasi Header Gambar:
  - `SourceConfigService.getImageHeaders(sourceId, imageUrl)` menghasilkan `Referer` dan `User-Agent` yang disesuaikan secara dinamis dengan domain aktif masing-masing sumber komik.
- Cakupan Modul Scraper:
  - Seluruh scraper (`ShinigamiService`, `KomikIndoService`, `KiryuuService`, `BacaKomikService`, `KomikuService`, `DoujinDesuService`, `MangaDexService`) menggunakan getter dinamis menggantikan konstanta statis.


---

## 5. FITUR EKSPANSI SUMBER KOMIK MANDIRI: IKIRU & MAK LUVYA

### Deskripsi
Penambahan dua sumber komik populer Indonesia ke dalam ekosistem aplikasi KsHcans, meningkatkan jumlah total penyedia katalog komik menjadi 9 sumber aktif (Komiku, KomikIndo, Shinigami, BacaKomik, Kiryuu, MangaDex, DoujinDesu, Ikiru, dan Mak Luvya).

### Spesifikasi Teknis
1. **Sumber Ikiru (`lib/core/services/ikiru_service.dart`)**:
   - Backend: REST API publik berkecepatan tinggi (`https://09.ikiru.wtf/api/public/...`).
   - Ekstraksi Lembaran: SSR HTML reader parsing dengan penyaringan regex direct CDN WebP (`cdn.ikiru.id`).
   - Warna Akses UI: Hijau Zamrud / Emerald Green (`#00E676`).
2. **Sumber Mak Luvya / Luvyaa (`lib/core/services/luvyaa_service.dart`)**:
   - Backend: CMS MangaThemesia WordPress (`https://v5.luvyaa.co`).
   - Ekstraksi Lembaran: Ekstraksi kontainer `div#readerarea img` beresolusi tinggi format WebP (`img2.cdn-nyaa.link`).
   - Deteksi Bab VIP: Evaluasi regex `lockedUrls = [...]` untuk menyematkan penanda bab berbayar/terkunci (`🔒`).
   - Warna Aksen UI: Merah Muda / Magenta (`#FF4081`).
3. **Integrasi Lintas Modul**:
   - `ChapterFetcher`: Menangani pemuatan bab untuk `'ikiru'` dan `'luvyaa'`.
   - `DownloadService`: Mendukung unduhan offline atomik lembaran bab dari kedua sumber.
   - `GlobalSearchScreen` & `UpdatesScreen`: Pencarian global dan rilis bab terbaru mencakup 9 sumber secara paralel.
   - `SourceConfigService`: Resolusi domain dinamis terpusat melalui `sources_config.json`.

---

## 6. FITUR PEMBACA KOMIK KOMPREHENSIF (ADVANCED READER ENGINE)

### Deskripsi
Mesin pembaca komik (*comic reading engine*) yang dirancang khusus untuk kenyamanan membaca berbagai jenis konten (Manga Jepang, Manhwa Korea Webtoon, dan Manhua China) dengan performa tinggi, proteksi memori, dan kontrol interaktif lengkap.

### Spesifikasi Teknis
1. **Pilihan 3 Mode Baca**:
   - **Mode Webtoon**: Continuous vertical stream tanpa sekat antar-halaman. Dilengkapi infinity scroll antar-bab otomatis.
   - **Mode Manga (RTL)**: Geser horizontal dari kanan ke kiri sesuai format komik Jepang asli.
   - **Mode Standar (LTR)**: Geser horizontal dari kiri ke kanan sesuai format buku/komik barat.
   - Persistensi preferensi membaca disimpan per pengguna ke SQLite (`reading_mode`).
2. **Auto-Scroll Otomatis**:
   - Pengguliran otomatis tanpa sentuh dengan 5 opsi kecepatan (`0.5x`, `1.0x`, `1.5x`, `2.0x`, `3.0x`).
   - Kontrol melayang (*floating pill*) untuk jeda, lanjut, dan percepat. Layar otomatis berhenti scroll saat disentuh.
3. **True Fullscreen Immersive Mode**:
   - Menggunakan mode sistem Android `SystemUiMode.immersiveSticky`.
   - Menghilangkan notch, status bar, dan navigation bar untuk area baca 100% tanpa distraksi. Kontrol muncul kembali saat layar tengah disentuh.
4. **Interaksi Zoom Pintar (Zoomable Page)**:
   - Double-tap untuk zoom instan 2.5x dengan transisi kurva halus. Double-tap kedua untuk mereset ke skala 1.0x.
   - Pinch-to-zoom mendukung skala bebas 1.0x hingga 4.0x.
   - Penguncian gesture horizontal saat dalam posisi zoom untuk mencegah halaman berganti secara tidak sengaja saat digeser.
5. **Navigasi Bab & Halaman Cepat**:
   - Tombol bab sebelumnya (`_prevChapter`) dan bab berikutnya (`_nextChapter`).
   - Scrubber slider interaktif di bilah bawah untuk melompat langsung ke nomor halaman tertentu.
   - Bottom sheet modal daftar bab lengkap dengan penanda bab aktif dan indikator riwayat baca (centang hijau).
6. **Manajemen Memori & Caching (Anti-OOM)**:
   - Pembatasan lebar decode gambar via `memCacheWidth: 1080` pada jaringan dan `cacheWidth: 1080` pada berkas lokal offline.
   - Mencegah force close akibat kehabisan memori (*Out Of Memory*) pada bab manhwa panjang beresolusi 4K/8K.
7. **Sinkronisasi Riwayat Baca Otomatis**:
   - Penyimpanan progres halaman terakhir dan status baca komik secara real-time ke tabel `reading_history` SQLite.
   - Pengecualian otomatis saat mode penyamaran (*Incognito*) aktif.

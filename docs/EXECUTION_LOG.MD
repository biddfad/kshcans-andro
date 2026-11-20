# EXECUTION LOG AUDIT

Jejak audit kronologis implementasi dan perencanaan teknis proyek KsHcans.

---

## 2026-11-01: Perencanaan dan Analisis Persyaratan Publikasi Google Play Store

1. Analisis Konfigurasi Android:
   - Target SDK: TargetSdkVersion mengacu pada Flutter SDK terkini (Target API 34).
   - Application ID: `com.abid.komik.aplikasibacakomik`.
   - Izin Manifest: Bersih dari izin berisiko tinggi (hanya INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS).
   - Release Keystore: Konfigurasi `key.properties` telah tersedia pada direktori android.
2. Analisis Kebijakan Google Play (Policy & Content Risk):
   - Risiko DMCA dan penutupan akun jika mendistribusikan scraper komik berhak cipta (Shinigami, KomikIndo, BacaKomik, Kiryuu, Komiku).
   - Larangan mutlak konten seksual/dewasa (DoujinDesu).
   - Opsi strategi arsitektur: Pure Reader vs Direct Distribution (Sideloading).
3. Penyusunan Rencana dan Dokumentasi:
   - Membuat artifak rencana_persyaratan_dan_publikasi_playstore.md.
   - Membuat berkas dokumentasi proyek docs/PANDUAN_PUBLISH_PLAYSTORE.MD.

---

## 2026-11-01: Perencanaan Strategi Distribusi Mandiri & In-App Auto-Updater

1. Analisis Kebutuhan:
   - Evaluasi kompleksitas Play Store (20 tester 14 hari, risiko DMCA/NSFW ban, $25 fee).
   - Perumusan solusi jalur mandiri mengadopsi standar industri (Tachiyomi / Mihon).
2. Perancangan Fitur In-App Auto-Updater:
   - Desain layanan AppUpdateService berbasis GitHub Releases API.
   - Rencana pengintegrasian ke tombol Cek Pembaruan di Pengaturan dan silent check saat startup.
3. Pembuatan Dokumentasi:
   - Artifak: rencana_strategi_distribusi_alternatif_dan_in_app_updater.md.
   - Dokumen Proyek: docs/PANDUAN_DISTRIBUSI_MANDIRI.MD.

---

## 2026-11-01: Penyusunan Rencana Teknis In-App Auto-Updater (OTA)

1. Analisis Native Android:
   - Persiapan FileProvider AndroidX dan file_paths.xml untuk menghindari FileUriExposedException.
   - Perancangan MethodChannel kshcans/installer pada MainActivity.kt.
   - Penambahan izin REQUEST_INSTALL_PACKAGES pada AndroidManifest.xml.
2. Perancangan Layanan Flutter:
   - Pembuatan skema AppUpdateService untuk streaming download dan progress bar.
   - Desain integrasi UI pada settings_screen.dart dan background check di main.dart.
3. Dokumentasi:
   - Artifak: rencana_implementasi_in_app_updater.md.

---

## 2026-11-01: Implementasi Fitur In-App Auto-Updater (OTA)

1. Konfigurasi Native Android:
   - Membuat `android/app/src/main/res/xml/file_paths.xml` untuk FileProvider paths.
   - Menambahkan izin `REQUEST_INSTALL_PACKAGES` dan `<provider>` pada `AndroidManifest.xml`.
   - Mengintegrasikan MethodChannel `kshcans/installer` pada `MainActivity.kt`.
2. Implementasi Layanan Flutter:
   - Membuat `lib/core/services/app_update_service.dart` dengan fitur semver check, stream download, dan dialog modal beranimasi.
   - Mengintegrasikan manual check pada dialog Tentang Aplikasi di `settings_screen.dart`.
   - Mengintegrasikan silent check otomatis pada `main.dart`.
   - Membuat berkas manifest `version.json`.
3. Verifikasi & Pengujian:
   - Membuat skrip pengujian `test/app_update_test.dart` (3/3 lulus 100%).
   - Menjalankan `flutter analyze` (0 issues found).
   - Sinkronisasi modul ke repositori `kshcans-andro` dan `kshcans-ios`.
   - Dokumentasi proyek: `docs/FEATURES.MD`, `docs/ARCHITECTURE.MD`, `docs/PANDUAN_DISTRIBUSI_MANDIRI.MD`.

---

## 2026-11-01: Analisis Sinkronisasi Pembaruan Web & Rencana Dynamic Source Domain

1. Analisis Real-Time Scraping:
   - Evaluasi arsitektur scraper live (ShinigamiService, KomikIndoService, BacaKomikService, dll.).
   - Verifikasi bahwa daftar bab dan komik terbaru diambil secara live HTTP GET tanpa hardcoded data di aplikasi.
   - Analisis kasus pergantian domain (domain migration / ISP blocking).
2. Perancangan Fitur Dynamic Source Domain:
   - Skema sources.json daring di GitHub untuk mengubah base URL tanpa rebuild APK.
   - Mekanisme fail-safe fallback ke domain lokal.
3. Dokumentasi:
   - Artifak: rencana_sinkronisasi_update_web_dan_dynamic_domain.md.

---

## 2026-11-01: Perencanaan Fitur Dynamic Remote Domain Resolver

1. Identifikasi Kerentanan Domain Hardcoded:
   - Evaluasi konstanta `baseUrl` dan `apiUrl` statis pada 7 service scraper.
   - Fakta teknis: Jika situs target (seperti Shinigami atau KomikIndo) ganti domain dan domain lama mati tanpa redirect, aplikasi saat ini akan gagal koneksi.
2. Perancangan Arsitektur Dynamic Remote Domain:
   - Desain file `sources_config.json` di GitHub.
   - Desain `SourceConfigService` dengan persistensi SQLite lokal dan fail-safe fallback.
   - Perancangan migrasi konstanta statis menjadi getter dinamis.
3. Dokumentasi:
   - Artifak: rencana_dynamic_remote_domain_resolver.md.

---

## 2026-11-01: Perencanaan Detail Dynamic Remote Domain Resolver & Klarifikasi Sumber Keiyoushi

1. Klarifikasi Arsitektur Sumber:
   - Sumber KsHcans 100% mandiri (pure native Dart scraper), bukan ekstensi APK eksternal Keiyoushi.
   - Kompatibel dengan Android dan iOS tanpa dependensi pihak ketiga.
2. Rencana Implementasi Resolver:
   - Pembuatan sources_config.json pada root repositori.
   - Pembuatan SourceConfigService dengan cache lokal SQLite dan silent background sync.
   - Refactoring getter dinamis pada 7 service scraper.
3. Dokumentasi:
   - Artifak: rencana_eksekusi_dynamic_domain_resolver.md.

---

## 2026-11-01: Implementasi Dynamic Remote Domain Resolver & Kompilasi Rilis

1. Implementasi Berkas Konfigurasi & Layanan:
   - Membuat `sources_config.json` di root `src` dan `src_ios`.
   - Mengembangkan `lib/core/services/source_config_service.dart` dengan SQLite caching, silent background sync, dan fallback defaults.
   - Refactoring 7 layanan scraper ke getter dinamis: `ShinigamiService`, `KomikIndoService`, `KiryuuService`, `BacaKomikService`, `KomikuService`, `DoujinDesuService`, `MangaDexService`.
   - Refactoring `DownloadService`, `MangaCard`, `MangaDetailScreen`, `UpdatesScreen`, dan `ReaderScreen` menggunakan `SourceConfigService.getImageHeaders`.
   - Inisialisasi pada `lib/main.dart` (`main()` dan `initState()`).
2. Pengujian dan Verifikasi:
   - `flutter test test/source_config_test.dart` (3/3 lulus 100%).
   - `flutter test test/app_update_test.dart` (3/3 lulus 100%).
   - `flutter analyze` bersih (0 issues found).
3. Sinkronisasi Git:
   - Commit dan push ke `biddfad/kshcans-andro` (branch `main`).
   - Commit dan push ke `biddfad/kshcans-ios` (branch `main`).
4. Kompilasi Produksi:
   - Eksekusi `flutter build apk --release --split-per-abi` untuk menghasilkan binary rilis terbaru.
   - Penyalinan artefak APK arsitektur ARM64 ke `E:\aplikasibacakomik\KsHcans.apk`.


---

## 2026-11-07: Implementasi Sumber Baru Ikiru (Source 8) & Mak Luvya (Source 9)

1. Riset & Analisis Arsitektur Sumber:
   - Evaluasi Softkomik: Teridentifikasi obfuscation Next.js dengan enkripsi AES CryptoJS (`_stk`) dan dynamic session token.
   - Evaluasi Ikiru: Terverifikasi REST API publik aktif (`09.ikiru.wtf`).
   - Evaluasi Mak Luvya: Terverifikasi CMS MangaThemesia aktif (`v5.luvyaa.co`) dengan direct CDN image.
2. Pembuatan Modul Layanan Baru:
   - `lib/core/services/ikiru_service.dart` (REST API parser & SSR HTML extractor).
   - `lib/core/services/luvyaa_service.dart` (MangaThemesia scraper & VIP locked chapter detector).
3. Pembaruan Dynamic Domain & Header Config:
   - Menambahkan domain Ikiru dan Luvyaa pada `sources_config.json`.
   - Menambahkan getter dan referer resolver pada `lib/core/services/source_config_service.dart`.
4. Integrasi Komponen UI & Core Engine:
   - `chapter_fetcher.dart`: Pemuatan bab Ikiru & Mak Luvya.
   - `download_service.dart`: Pengunduhan atomik bab offline dari Ikiru & Mak Luvya.
   - `source_logo.dart`: Ikon & palet warna khas (#00E676 untuk Ikiru, #FF4081 untuk Mak Luvya).
   - `browse_screen.dart`, `source_catalog_screen.dart`, `global_search_screen.dart`, `updates_screen.dart`, `reader_screen.dart`.
5. Pengujian & Verifikasi Kualitas:
   - Pembuatan unit test `test/ikiru_service_test.dart` dan `test/luvyaa_service_test.dart`.
   - Pembaruan `test/source_config_test.dart`.
   - Eksekusi 12 automated unit tests: 12/12 Lulus (100%).
   - Eksekusi `flutter analyze`: Bersih (0 issues found).
6. Sinkronisasi Git & Kompilasi Rilis:
   - Commit & push ke `biddfad/kshcans-andro` (commit `d6b42af`).
   - Commit & push ke `biddfad/kshcans-ios` (commit `b690b75`).
   - Kompilasi APK rilis `flutter build apk --release --split-per-abi`.
   - Penyalinan APK release ARM64 ke `E:\aplikasibacakomik\KsHcans.apk`.
7. Pemasangan Langsung ke Perangkat Fisik (Live Deployment):
   - Deteksi perangkat target Android via ADB (`6TKZ89GIEE4H6XPV`, model `M2101K7BNY`).
   - Eksekusi instalasi pembaruan: `adb install -r KsHcans.apk` (Status: Success).
   - Verifikasi package dan peluncuran aktivitas: `am start -n com.abid.komik.aplikasibacakomik/.MainActivity`.
   - Verifikasi fokus tampilan: `mCurrentFocus=Window{... MainActivity}` (Aplikasi berjalan aktif di layar HP).

---

## 2026-11-08: Perbaikan FormatException Daftar Bab Mak Luvya & Pemasangan Langsung ke HP

1. Investigasi Defek Bab Kosong pada Mak Luvya:
   - Uji penelusuran exception menemukan kesalahan CSS pseudo-selector `:contains("Status")` yang tidak didukung parser DOM Dart (`FormatException`).
   - Akibatnya blok ekstraksi gugur dan mengembalikan peta kosong sehingga daftar bab tidak tampil di aplikasi.
2. Implementasi Solusi Teknis:
   - Mengganti selector status di `luvyaa_service.dart` dengan iterasi DOM standar.
   - Menambahkan parser JSON `ts_reader.run` untuk ekstraksi lembaran gambar WebP yang bersih dan berurutan.
3. Pengujian Kualitas:
   - Verifikasi langsung pada komik *The Remarried Empress*: seluruh 251 bab berhasil dimuat dan 59 gambar WebP terurai rapi.
   - Eksekusi `flutter test`: 54/54 uji lulus 100%.
   - Eksekusi `flutter analyze`: 0 issues found.
4. Sinkronisasi Git & Kompilasi Ulang:
   - Sinkronisasi commit dan push pada repositori Android (`46abacf`) dan iOS (`e437cde`).
   - Kompilasi biner rilis `flutter build apk --release --split-per-abi`.
   - Penyalinan ke `E:\aplikasibacakomik\KsHcans.apk`.
5. Pemasangan ke HP Pengguna (Live Update):
   - `adb -s 6TKZ89GIEE4H6XPV install -r KsHcans.apk` (Status: Success).
   - `am start -n com.abid.komik.aplikasibacakomik/.MainActivity` (Aplikasi aktif di layar HP).

---

## 2026-11-19: Investigasi dan Pembaruan Infrastruktur Domain Shinigami

1. Investigasi Pembaruan Domain Shinigami:
   - Domain website lama `https://shinigami.asia` dialihkan secara otomatis ke mirror aktif baru `https://s1.shinigami.mx/`.
   - Domain API lama `https://api.shngm.io` terdeteksi nonaktif (502 Bad Gateway).
   - Penelusuran bundle JavaScript Vite menemukan infrastruktur baru:
     - Base API: `https://api.shinigami.io` (v1 endpoints aktif dan kompatibel).
     - Storage CDN Gambar: `https://cdn.shinigami.gg`.
2. Verifikasi Endpoint Baru:
   - Eksekusi pengujian live Dart: katalog populer (12 komik), pencarian komik, daftar bab, dan lembaran gambar terunduh sukses (200 OK).
3. Pembaruan Konfigurasi Dinamis:
   - Pembaruan remote manifest `sources_config.json` (versi 3) di GitHub.
   - Pembaruan fallback default & image referer di `SourceConfigService`.
   - Pembaruan unit test `test/source_config_test.dart` (lulus 100%).
4. Sinkronisasi Git:
   - Commit & push ke `biddfad/kshcans-andro` (`7ea3c9d`) dan `biddfad/kshcans-ios` (`861bfa4`).
5. Perbaikan Cache SQLite & Penanganan CI/CD:
   - Penambahan `bundledConfigVersion = 3` dan metode `deleteSetting` di `DBHelper` (`2751528`).
   - Penjelasan kegagalan build sementara pada GitHub Actions: commit perantara `cbeb1b8` sempat memicu build sebelum definisi `deleteSetting` di-push, yang langsung teratasi pada commit `2751528`.
6. Pemasangan Langsung ke HP (Live ADB Streamed Install):
   - Perangkat target terotorisasi: Redmi Note 10S (`6TKZ89GIEE4H6XPV` / `M2101K7BNY`).
   - Eksekusi pemasangan biner terbaru: `adb install -r KsHcans.apk` (Status: Success).
   - Peluncuran aplikasi: `am start -n com.abid.komik.aplikasibacakomik/.MainActivity`.
   - Aplikasi aktif berjalan dengan domain baru Shinigami (`api.shinigami.io` & `cdn.shinigami.gg`).
7. Pengaktifan Sukses Akses Publik Remote Config:
   - Pengguna mengubah repositori `biddfad/kshcans-andro` menjadi Public.
   - Endpoint `https://raw.githubusercontent.com/biddfad/kshcans-andro/main/sources_config.json` terverifikasi sukses diakses tanpa autentikasi (HTTP 200 OK).
   - Eksekusi `SourceConfigService.syncRemoteConfig()` menghasilkan `true`, mengonfirmasi bahwa seluruh pembaruan domain di masa depan akan tersinkronisasi 100% otomatis ke aplikasi HP.
8. Perbaikan Paginasi Offset & Batas Bab Shinigami:
   - Identifikasi akar masalah: API baru `api.shinigami.io` menggunakan `offset` dan `limit` (mengabaikan `page` dan `page_size`).
   - Migrasi parameter di `ShinigamiService`: `offset=(page-1)*20` dan `limit=20` untuk katalog/pencarian, serta `limit=1000` untuk bab.
   - Uji unit live terverifikasi: Page 1 (20 komik), Page 2 (20 komik berikutnya), dan 938 bab komik panjang termuat sempurna.
   - Sinkronisasi commit `21b7a7f` (Android) dan `e9a559d` (iOS).
   - Kompilasi ulang APK rilis `KsHcans.apk` (22:31 WIB).
9. Pemasangan Pembaruan ke HP (Live ADB Streamed Install):
   - Perangkat target: Redmi Note 10S (`6TKZ89GIEE4H6XPV` / `M2101K7BNY`).
   - Status instalasi APK: Success.
   - Peluncuran aktivitas utama: `am start -n com.abid.komik.aplikasibacakomik/.MainActivity`.
   - Hasil: Katalog Shinigami kini dapat dimuat bertahap secara kontinu (infinite scroll) dan seluruh bab tampil lengkap.
10. Audit Fitur Pembaca Komik (Reader Screen) & Pengujian Otomatis:
   - Peninjauan menyeluruh terhadap seluruh arsitektur dan kontrol pembaca:
     - 3 Mode Pembaca: Webtoon (vertikal kontinu), Manga (RTL / kanan-ke-kiri), Standar (LTR / kiri-ke-kanan).
     - Kontrol Auto-Scroll: 5 preset kecepatan (0.5x hingga 3.0x), start/pause/stop via floating pill & tap gesture.
     - True Fullscreen Immersive Mode: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`.
     - Zoomable Page: Double-tap 2.5x dengan animasi halus, pinch-to-zoom 1.0x hingga 4.0x, dan pan lock saat zoom.
     - Navigasi & Scrubber Bar: Bab sebelumnya, bab berikutnya, modal daftar bab, dan scrubber slider nomor halaman.
     - Pelacakan Riwayat & Progres: Pencatatan posisi halaman dan status bab selesai ke SQLite secara otomatis.
   - Perbaikan Defek Tampilan:
     - Memperbaiki RenderFlex overflow 3.5px pada bottom sheet pengaturan mode baca dengan membungkus modal menggunakan `SingleChildScrollView`.
   - Pengujian Kualitas:
     - Pembuatan automated widget tests di `test/reader_features_test.dart` (4 uji: render kontrol, daftar bab, pengaturan mode baca, double-tap zoom).
     - Eksekusi `flutter test test/reader_features_test.dart`: 4/4 Lulus (100%).
     - Eksekusi `flutter test` seluruh proyek: 58/58 Lulus (100%).
     - Eksekusi `flutter analyze`: Bersih (No issues found).
   - Sinkronisasi Kode:
     - Commit & push ke `biddfad/kshcans-andro` (`3c2b81e`) dan `biddfad/kshcans-ios` (`2cda9b7`).
11. Optimasi Ukuran Berkas APK Rilis (Split-Per-ABI):
   - Klarifikasi Ukuran APK: Build universal menghasilkan APK 56.6 MB karena menggabungkan pustaka mesin C++ dari 4 arsitektur prosesor (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`) dalam satu file tunggal.
   - Eksekusi Kompilasi Ramping: Menjalankan `flutter build apk --release --split-per-abi`.
   - Hasil Kompilasi:
     - `app-arm64-v8a-release.apk`: **20.5 MB** (Arsitektur smartphone modern 64-bit seperti Redmi Note 10S).
     - `app-armeabi-v7a-release.apk`: **18.2 MB** (Arsitektur 32-bit).
     - `app-x86_64-release.apk`: **22.0 MB** (Emulator/PC).
   - Penempatan Berkas: Menyalin `app-arm64-v8a-release.apk` ke `E:\aplikasibacakomik\KsHcans.apk`.
   - Pemasangan Langsung: `adb -s 6TKZ89GIEE4H6XPV install -r KsHcans.apk` (Status: Success).
   - Peluncuran: Aplikasi aktif di layar ponsel pengguna.
12. Resolusi 3 Domain Error (DoujinDesu CDN, Ikiru, Mak Luvya) & Riset Komik Noblesse:
   - Investigasi Defek Domain Pengguna:
     - Ditemukan 3 sumber yang bermasalah: DoujinDesu (CDN gambar diblokir ISP), Ikiru (rotasi domain 301 ke `11.ikiru.wtf` + DNS poisoning), dan Mak Luvya (rotasi domain 301 ke `v6.luvyaa.co` + DNS poisoning).
   - Implementasi Solusi:
     - Pembaruan remote manifest `sources_config.json` ke versi 4 (Ikiru: `https://11.ikiru.wtf`, Mak Luvya: `https://v6.luvyaa.co`).
     - Pembaruan `source_config_service.dart` (bundledConfigVersion = 4, default fallbacks).
     - Peningkatan `app_http_overrides.dart`: pemetaan DoH untuk `amz-ch.desu.pics`, `desu.pics`, `ikiru.wtf`, `luvyaa.co` dan penambahan mekanisme Universal DoH Auto-Fallback jika terjadi kegagalan handshake akibat DNS poisoning sinkhole ISP lokal.
   - Verifikasi Kualitas:
     - Pengujian `test/full_9_sources_audit.dart`: Seluruh 9 sumber (Shinigami, KomikIndo, Kiryuu, BacaKomik, Komiku, DoujinDesu, MangaDex, Ikiru, Mak Luvya) lulus 100%.
     - `flutter analyze`: 0 issues found.
   - Riset Komik Noblesse:
     - Analisis alasan tidak ada di 9 sumber saat ini: Noblesse adalah komik berlisensi resmi LINE Webtoon Indonesia (544 chapter lengkap tamat). Agregator umum lokal dan MangaDex men-takedown chapter karena hak cipta.
     - Analisis Softkomik: Domain sekundernya down (521), rute API sering dirombak (404), dan enkripsi token sering berganti.
     - Penemuan platform terbaik: LINE Webtoon Indonesia menyediakan seluruh 544 chapter resmi sub Indo dengan CDN gambar Akamai yang sangat cepat (200 OK). Siap diintegrasikan sebagai Sumber ke-10 jika disetujui pengguna.
   - Sinkronisasi & Kompilasi:
     - Commit & push ke `biddfad/kshcans-andro` (`89cd60e`) dan `biddfad/kshcans-ios` (`cf977f3`).
     - Kompilasi biner rilis ARM64 terbaru: `KsHcans.apk` (20.5 MB).

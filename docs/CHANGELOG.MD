# CHANGELOG KSHCANS

Riwayat kronologis pembaruan dan rilis aplikasi KsHcans.

---

## [1.0.6] - 2026-11-20

### Diperbaiki (Fixed)
- **Rotasi Domain Ikiru & Mak Luvya**:
  - Memperbarui endpoint upstream Ikiru ke mirror aktif baru `https://11.ikiru.wtf` (menggantikan `09.ikiru.wtf` yang 301).
  - Memperbarui endpoint upstream Mak Luvya ke mirror aktif baru `https://v6.luvyaa.co` (menggantikan `v5.luvyaa.co` yang 301).
  - Memperbarui `sources_config.json` ke versi 4 di remote manifest GitHub.
- **Bypass Keracunan DNS ISP (DoH Auto-Fallback) & CDN DoujinDesu**:
  - Memperluas filter `AppHttpOverrides` mencakup host gambar DoujinDesu (`amz-ch.desu.pics`, `desu.pics`), Ikiru (`ikiru.wtf`), dan Mak Luvya (`luvyaa.co`, `cdn-nyaa.link`).
  - Menerapkan mekanisme **Universal DoH Auto-Fallback**: jika terjadi kegagalan handshake akibat DNS poisoning sinkhole ISP lokal (`Hostname mismatch`), koneksi secara otomatis beralih menggunakan Cloudflare/Google DoH asli.

---

## [1.0.5] - 2026-11-19

### Diperbaiki (Fixed)
- **Paginasi & Katalog Komik Shinigami**:
  - Migrasi parameter paginasi dari `page`/`page_size` ke `offset`/`limit` pada API v1 Shinigami (`api.shinigami.io`).
  - Mengatasi kendala komik mentok 12 item pada tab Populer dan Terbaru, kini infinite scroll memuat halaman berikutnya secara kontinu.
  - Memperbaiki batasan chapter yang terpotong 12 bab menjadi memuat utuh seluruh bab (termasuk 938 bab pada *Demonic Emperor*).
- **Tampilan Pengaturan Pembaca (Reader Screen Modal)**:
  - Mengatasi pesan `RenderFlex overflowed by 3.5 pixels on the bottom` pada dialog pemilihan mode baca dengan membungkus modal dalam `SingleChildScrollView`.
- **Akses Remote Manifest Domain Publik**:
  - Konfigurasi repositori Android menjadi Public memastikan sinkronisasi domain otomatis (OTA) tanpa autentikasi berjalan sempurna dengan status HTTP 200 OK.

### Diubah (Changed)
- Pembaruan domain resmi Shinigami ke infrastruktur terbaru:
  - Base API: `https://api.shinigami.io` (menggantikan `api.shngm.io` yang telah tidak aktif/502).
  - Assets / CDN Gambar: `https://cdn.shinigami.gg` (menggantikan `assets.shngm.id`).
  - Web & Referer: `https://s1.shinigami.mx/` (menggantikan `shinigami.asia` yang kini dialihkan otomatis).
- Sinkronisasi remote manifest `sources_config.json` (versi 3) di GitHub.
- Pembaruan default fallback dan image headers pada `SourceConfigService`.
- Pengujian live verifikasi katalog, bab, dan unduhan gambar lembaran sukses (200 OK).
- Penambahan test suite otomatis komprehensif `test/reader_features_test.dart` (4/4 uji lulus 100%).

---

## [1.0.4] - 2026-11-07

### Ditambahkan (Added)
- Layanan scraper murni Dart untuk sumber ke-8: `IkiruService` berbasis REST API publik (`https://09.ikiru.wtf`).
- Layanan scraper murni Dart untuk sumber ke-9: `LuvyaaService` (Mak Luvya) berbasis tema MangaThemesia (`https://v5.luvyaa.co`).
- Deteksi otomatis bab berbayar/terkunci VIP (`lockedUrls`) pada Mak Luvya dengan badge gembok `🔒`.
- Penambahan konfigurasi domain dan CDN referer Ikiru & Mak Luvya pada `sources_config.json` dan `SourceConfigService`.
- Integrasi Ikiru dan Mak Luvya ke dalam `BrowseScreen`, `SourceCatalogScreen`, `GlobalSearchScreen`, `UpdatesScreen`, `ReaderScreen`, dan `DownloadService`.
- Pengujian unit otomatis baru: `test/ikiru_service_test.dart` dan `test/luvyaa_service_test.dart`.
- Pembaruan unit test `test/source_config_test.dart` dengan rasio kelulusan 12/12 uji (100% Lulus).

---

## [1.0.3] - 2026-11-01

### Ditambahkan (Added)
- Layanan terpusat `SourceConfigService` untuk resolusi domain dinamis 7 penyedia komik.
- Berkas remote manifest `sources_config.json` di root repositori untuk update domain instan tanpa rebuild APK.
- Cache konfigurasi domain lokal berbasis SQLite dengan fallback bawaan anti-offline.
- Sentralisasi pembuatan HTTP header gambar (`SourceConfigService.getImageHeaders`) untuk referer anti-hotlinking.
- Pengujian unit otomatis `test/source_config_test.dart` (3/3 lulus 100%).

### Diubah (Changed)
- Seluruh 7 layanan scraper (`ShinigamiService`, `KomikIndoService`, `KiryuuService`, `BacaKomikService`, `KomikuService`, `DoujinDesuService`, `MangaDexService`) dimigrasikan dari URL statis ke getter dinamis.
- Modul `DownloadService`, `MangaCard`, `MangaDetailScreen`, `UpdatesScreen`, dan `ReaderScreen` dimigrasikan ke pemanggilan `SourceConfigService.getImageHeaders`.

---

## [1.0.2] - 2026-11-01

### Ditambahkan (Added)
- Fitur In-App Auto-Updater (OTA Update) berbasis Android FileProvider dan MethodChannel `kshcans/installer`.
- Berkas konfigurasi jalur penyimpanan pembaruan `android/app/src/main/res/xml/file_paths.xml`.
- Izin sistem `REQUEST_INSTALL_PACKAGES` pada `AndroidManifest.xml`.
- Modul layanan `AppUpdateService` dengan perbandingan semver dan streaming download dialog.
- Pengecekan versi manual via menu Pengaturan dan silent check otomatis saat startup.
- Berkas manifest pembaruan `version.json`.
- Pengujian unit otomatis `test/app_update_test.dart` (3/3 lulus 100%).

### Diperbaiki (Fixed)
- Resolusi cover gambar Shinigami dengan evaluasi fallback string kosong (`.isEmpty`) dan prefix domain CDN `assets.shngm.id`.
- Filter bab lisensi eksternal MangaDex (`externalUrl != null` dan `pages <= 0`).
- Pencegahan crash OOM di mode Webtoon dengan pembatasan resolusi cache decoding 1080px.

---

## [1.0.1] - 2026-10-26

### Ditambahkan
- Modul keamanan `SecurityService` dengan hashing PIN kriptografis SHA-256 dan salt lokal unik.
- Auto-lock siklus hidup aplikasi saat berpindah ke background atau saat layar mati.
- Mode baca penyamaran (Incognito Reading) tanpa jejak riwayat SQLite.
- Penyaringan otomatis komik dewasa di tab Riwayat saat mode dewasa nonaktif.
- Mekanisme unduhan atomik dengan file sementara `.part` dan verifikasi integritas ukuran file.

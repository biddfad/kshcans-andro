# LOG DEFEK DAN PERBAIKAN (BUG LOG) KSHCANS

Dokumen pencatatan defek logika fungsional, parsing kesalahan modul, atau perilaku tak terduga sistem beserta solusi perbaikannya.

---

## 2026-11-08: FormatException Selector CSS pada Detail Mak Luvya (Daftar Chapter Tidak Muncul)

- **Modul Terdampak**: `lib/core/services/luvyaa_service.dart` (Metode `getMangaDetails`).
- **Gejala Masalah**: Saat pengguna membuka detail komik dari sumber Mak Luvya (misalnya *The Remarried Empress* / *The Second Marriage*), daftar chapter tidak muncul (kosong) dan aplikasi tidak dapat memuat bab komik.
- **Akar Masalah (Root Cause)**:
  - Pada baris ekstraksi status komik, digunakan pemanggilan selector:
    `document.querySelector('.tsinfo .imptdt:contains("Status") i')`
  - Paket parser DOM Dart (`package:html/src/query_selector.dart`) tidak mendukung pseudo-selector CSS `:contains(...)`, sehingga melempar unhandled exception `FormatException: expected CSS expression, but found )`.
  - Exception tersebut ditangkap oleh blok fallback `catch (_) { return {}; }`, menyebabkan seluruh proses ekstraksi bab (251 chapter) gugur dan mengembalikan peta kosong `{}`.
- **Solusi Perbaikan**:
  1. Mengganti query `:contains` dengan iterasi elemen standar:
     ```dart
     String status = 'Ongoing';
     for (final el in document.querySelectorAll('.tsinfo .imptdt')) {
       if (el.text.contains('Status')) {
         status = el.querySelector('i')?.text.trim() ?? el.text.replaceFirst('Status', '').trim();
         break;
       }
     }
     ```
  2. Menambahkan parser JSON `ts_reader.run` pada metode `getChapterPages` untuk memastikan seluruh lembaran gambar komik diekstraksi secara presisi dan terurut tanpa membawa elemen ikon atau banner website.
- **Hasil Verifikasi**:
  - `test/test_detail_live.dart`: Seluruh 251 bab *The Remarried Empress* berhasil dimuat secara instan dan 59 lembaran gambar WebP bab 1 diekstraksi sempurna.
  - `flutter test`: 54/54 uji otomatis lulus (100%).
  - `flutter analyze`: 0 issues found.
  - Rilis APK berhasil dikompilasi dan dipasang langsung ke perangkat HP pengguna via ADB.

---

## 2026-11-19: Parameter Paginasi Usang pada API Shinigami Baru (Komik Mentok 12 & Infinite Scroll Tidak Bertambah)

- **Modul Terdampak**: `lib/core/services/shinigami_service.dart` (`getPopularManga`, `getLatestUpdates`, `searchManga`, `getMangaChapters`).
- **Gejala Masalah**:
  - Pada katalog sumber Shinigami (baik tab Populer maupun Terbaru), hanya tampil 12 komik.
  - Saat layar digulir ke bawah (*infinite scroll*), komik tidak bertambah dan daftar tidak memuat halaman berikutnya.
  - Saat membuka komik panjang (misal *Demonic Emperor* yang memiliki 900+ bab), hanya tampil 12 bab pertama.
- **Akar Masalah (Root Cause)**:
  - Infrastruktur API baru Shinigami (`api.shinigami.io`) tidak lagi menggunakan parameter `page` dan `page_size`.
  - Jika klien mengirim `?page=2&page_size=20`, server mengabaikan parameter tersebut dan selalu mengembalikan halaman awal (`offset=0`) dengan default `limit=12`.
  - Sistem deduplikasi di UI aplikasi mendeteksi 12 item pada page 2 identik dengan page 1, sehingga 0 komik baru ditambahkan ke layar.
  - Demikian pula endpoint bab mengabaikan `page_size=3000` dan mengembalikan default 12 bab.
- **Solusi Perbaikan**:
  1. Mengubah perhitungan parameter pada `getPopularManga`, `getLatestUpdates`, dan `searchManga`:
     ```dart
     final offset = (page - 1) * 20;
     final url = Uri.parse('$apiUrl/v1/manga/list?offset=$offset&limit=20&sort=popularity');
     ```
  2. Mengubah query endpoint daftar bab menjadi:
     ```dart
     final url = Uri.parse('$apiUrl/v1/chapter/$mangaId/list?limit=1000');
     ```
- **Hasil Verifikasi**:
  - `shinigami_pagination_test.dart`:
    - Page 1 (Offset 0): 20 komik unik dimuat.
    - Page 2 (Offset 20): 20 komik unik baru berikutnya dimuat (0 duplikasi).
    - Daftar bab *Demonic Emperor*: Seluruh **938 bab** berhasil dimuat utuh.
  - `flutter analyze`: 0 issues found.
  - Repositori git Android (`21b7a7f`) dan iOS (`e9a559d`) telah disinkronkan ke `main`.
  - Biner APK rilis telah selesai dikompilasi ulang ke `KsHcans.apk`.

---

## 2026-11-19: RenderFlex Overflow pada Modal Pengaturan Pembaca (Reader Settings Bottom Sheet)

- **Modul Terdampak**: `lib/features/reader/screens/reader_screen.dart` (Metode `_showReaderSettings`).
- **Gejala Masalah**: Saat pengguna membuka bottom sheet pengaturan mode baca (ikon gear di pojok kanan atas layar baca), muncul pesan error debug Flutter: `A RenderFlex overflowed by 3.5 pixels on the bottom`.
- **Akar Masalah (Root Cause)**:
  - Dialog pengaturan pembaca menampilkan 3 pilihan mode baca (Webtoon, Manga RTL, Manga LTR) beserta deskripsi masing-masing di dalam kontainer `Column(mainAxisSize: MainAxisSize.min)` yang dibungkus oleh `Padding`.
  - Pada layar dengan resolusi vertikal tertentu atau saat keyboard/sistem insets aktif, tinggi agregat konten melebihi batas batas vertikal bawah modal sebesar 3.5 piksel.
- **Solusi Perbaikan**:
  - Mengganti pembungkus modal dari `Padding` menjadi `SingleChildScrollView` dengan mempertahankan padding horizontal 20 dan vertikal 16:
    ```dart
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // ...
      ),
    );
    ```
- **Hasil Verifikasi**:
  - Uji otomatis `test/reader_features_test.dart` ("ReaderScreen can open reader settings bottom sheet modal"): Lulus 100% tanpa exception RenderFlex overflow.
  - Seluruh fitur pembaca (Mode Webtoon, Mode Manga RTL, Mode Manga LTR, Auto-scroll, Fullscreen immersive, Zoomable Page, Scrubber slider, Bottom sheet daftar bab, Sinkronisasi riwayat baca ke SQLite) terverifikasi berfungsi sempurna.

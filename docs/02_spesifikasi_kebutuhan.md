# 02. Spesifikasi Kebutuhan Perangkat Lunak (SRS)

Dokumen ini mendefinisikan kebutuhan fungsional (*Functional Requirements*) dan non-fungsional (*Non-Functional Requirements*) untuk aplikasi pembaca komik.

---

## 1. Kebutuhan Fungsional (Functional Requirements)

### FR-01: Manajemen Pustaka (Library Management)
* **FR-01.1:** Pengguna dapat menambahkan atau menghapus komik ke/dari Pustaka Pribadi (*Personal Library*).
* **FR-01.2:** Pengguna dapat membuat kategori khusus (misalnya: *Membaca*, *Rencana Baca*, *Selesai*, *Favorit*).
* **FR-01.3:** Tampilan komik di perpustakaan memiliki indikator jumlah bab yang belum dibaca (*Unread Badge*).
* **FR-01.4:** Sistem melakukan pengecekan bab baru secara otomatis di latar belakang dengan jeda waktu yang aman (*throttling*).

### FR-02: Pencarian & Eksplorasi Sumber (Browse & Search)
* **FR-02.1:** Pengguna dapat mencari judul komik pada satu sumber spesifik atau melakukan pencarian global (*Global Search*) lintas semua ekstensi yang terpasang.
* **FR-02.2:** Filter pencarian mendukung pemilihan genre, status komik (Ongoing/Completed), dan urutan popularitas/terbaru.
* **FR-02.3:** Menampilkan detail komik lengkap: sinopsis, sampul (cover), pengarang/artis, dan daftar bab berurutan.

### FR-03: Reader Engine (Penampil Komik)
* **FR-03.1:** Mendukung mode baca **Webtoon** (continuous vertical scroll tanpa jeda).
* **FR-03.2:** Mendukung mode baca **Paged Right-to-Left (RTL)** untuk manga Jepang standar.
* **FR-03.3:** Mendukung mode baca **Paged Left-to-Right (LTR)** untuk komik barat/webcomic.
* **FR-03.4:** Fitur *Pinch-to-Zoom* yang halus dengan kemampuan mengunci arah scroll saat zoom aktif.
* **FR-03.5:** Pengaturan orientasi layar (Portrait, Landscape, atau Auto-Rotate).
* **FR-03.6:** Penyimpanan posisi baca otomatis: saat bab dibuka kembali, pembaca langsung diarahkan ke halaman terakhir yang dibaca.

### FR-04: Manajemen Unduhan Offline (Download Manager)
* **FR-04.1:** Pengguna dapat mengunduh satu bab atau beberapa bab sekaligus (batch download).
* **FR-04.2:** Antrian unduhan (*Download Queue*) memiliki opsi Pause, Resume, dan Cancel.
* **FR-04.3:** Bab yang sudah diunduh dapat dibaca secara penuh tanpa koneksi internet aktif.
* **FR-04.4:** Fitur auto-delete bab yang sudah selesai dibaca untuk menghemat kapasitas memori internal.

### FR-05: Sinkronisasi Pelacak (Tracker Sync)
* **FR-05.1:** Integrasi OAuth2 dengan layanan pelacak pihak ketiga: **AniList**, **MyAnimeList**, dan **Kitsu**.
* **FR-05.2:** Pembaruan nomor bab dan status baca secara otomatis ke akun pelacak pengguna begitu bab selesai dibaca.

### FR-06: Cadangan & Pemulihan (Backup & Restore)
* **FR-06.1:** Ekspor seluruh data perpustakaan, riwayat, dan kategori ke dalam file cadangan lokal berformat JSON.
* **FR-06.2:** Impor file cadangan untuk memulihkan seluruh data pada perangkat baru.

---

## 2. Kebutuhan Non-Fungsional (Non-Functional Requirements)

### NFR-01: Performa & Konsumsi Memori
* Waktu peluncuran aplikasi (*cold start*) tidak boleh melebihi 2 detik.
* Frame rate saat melakukan scrolling gambar pada mode Webtoon harus stabil di angka 60 FPS (atau 120 FPS pada layar berkemampuan refresh tinggi).
* Konsumsi RAM saat membaca bab komik panjang harus dibatasi maksimal 250 MB dengan memanfaatkan pembersihan memori agresif (*garbage collection & bitmap recycling*).

### NFR-02: Keamanan & Privasi
* Seluruh skrip ekstensi wajib dijalankan di dalam lingkungan terisolasi (*sandbox*).
* Kredensial login tracker wajib disimpan menggunakan enkripsi perangkat keras (*Android KeyStore*).
* Aplikasi menyediakan opsi penguncian biometrik (Fingerprint/Face Unlock/PIN).

### NFR-03: Kompatibilitas Perangkat
* Versi Android Minimum: Android 7.0 (API Level 24 / Nougat).
* Versi Android Target: Android 14 / 15 (API Level 34+).

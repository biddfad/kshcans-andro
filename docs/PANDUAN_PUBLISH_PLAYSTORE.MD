# PANDUAN DAN PERSYARATAN PUBLIKASI APLIKASI KE GOOGLE PLAY STORE

Dokumen ini memuat ringkasan persyaratan dan regulasi Google Play Store untuk pengembang Android dan aplikasi KsHcans.

---

## 1. PERSYARATAN AKUN PENGEMBANG (GOOGLE PLAY CONSOLE)

1. Biaya Pendaftaran: Sekali bayar sebesar $25 USD (seumur hidup) menggunakan kartu kredit/debit internasional 3D Secure.
2. Verifikasi Identitas (KYC):
   - Akun Personal: Verifikasi KTP/SIM/Paspor, alamat tempat tinggal, nomor telepon, dan email.
   - Akun Organisasi: Nomor D-U-N-S (Dun & Bradstreet) dan dokumen legalitas badan hukum.
3. Kewajiban Closed Testing 20 Tester (Aturan Akun Personal Pasca 13 November 2023):
   - Wajib menjalankan Uji Tertutup (Closed Testing) dengan minimal 20 akun tester independen.
   - Seluruh tester wajib mendaftar (opt-in) dan memasang aplikasi minimal 14 hari berturut-turut.
   - Mengisi kuesioner ringkasan pengujian sebelum opsi pengajuan rilis publik (Production) dibuka oleh Google.

---

## 2. KEPATUHAN KEBIJAKAN KONTEN DAN HAK CIPTA (POLICY COMPLIANCE)

1. Kebijakan Kekayaan Intelektual (Intellectual Property / DMCA):
   - Google melarang keras aplikasi yang memuat atau memfasilitasi scraping komik/manga berhak cipta tanpa lisensi resmi.
   - Scraper bawaan ke situs komik tidak boleh di-hardcode di dalam aplikasi Play Store karena berisiko suspend akun langsung.
2. Kebijakan Konten Dewasa (Sexual Content Policy):
   - Sumber komik dewasa (seperti DoujinDesu / konten 18+) dilarang total di Google Play Store.
3. Solusi Arsitektur Standar Industri (Model Tachiyomi / Mihon):
   - Aplikasi di Google Play Store didaftarkan sebagai Pure Reader (pembaca berkas lokal CBZ/CBR/ZIP/PDF atau sumber berlisensi bebas).
   - Ekstensi pihak ketiga diinstal secara eksternal oleh pengguna melalui URL repositori daring di luar aplikasi Play Store.

---

## 3. PERSYARATAN TEKNIS DAN FORMAT RILIS

1. Format Berkas: Wajib format Android App Bundle (.aab), bukan .apk.
   - Perintah build: `flutter build appbundle --release`.
2. Target SDK: Wajib menargetkan API Level 34 (Android 14) atau lebih baru.
3. Kunci Penandatanganan: Menggunakan keystore rilis produksi dan Google Play App Signing.
4. Izin Sistem: Hanya meminta izin yang relevan (INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS).

---

## 4. PERSYARATAN ASET HALAMAN TOKO (STORE LISTING)

1. Ikon Aplikasi: Resolusi 512 x 512 piksel, 32-bit PNG, ukuran maksimal 1 MB.
2. Gambar Fitur (Feature Graphic): Resolusi 1024 x 500 piksel, format JPG atau PNG.
3. Tangkapan Layar (Screenshots): Minimal 4 tangkapan layar ponsel rasio 16:9 atau 9:16.
4. Teks Informasi:
   - Nama Aplikasi: Maksimal 30 karakter.
   - Deskripsi Singkat: Maksimal 80 karakter.
   - Deskripsi Lengkap: Maksimal 4000 karakter.
5. Kebijakan Privasi (Privacy Policy): Wajib memiliki URL kebijakan privasi publik yang aktif.
6. Deklarasi Keamanan Data (Data Safety) dan Kuesioner Rating Usia (IARC).

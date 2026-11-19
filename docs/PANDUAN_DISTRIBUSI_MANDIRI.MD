# PANDUAN DAN STRATEGI DISTRIBUSI MANDIRI KSHCANS

Dokumen ini menjelaskan strategi distribusi mandiri (sideloading) untuk aplikasi KsHcans sebagai alternatif Google Play Store.

---

## 1. MENGAPA DISTRIBUSI MANDIRI DIPILIH?

1. Bebas Sensor dan Larangan Kebijakan:
   - Sumber komik aggregator (Shinigami, KomikIndo, BacaKomik, Kiryuu, Komiku) dan mode dewasa (DoujinDesu) tetap dapat dinikmati 100% oleh pengguna tanpa risiko pemblokiran akun Google Play.
2. Bebas Biaya dan Birokrasi:
   - Tidak memerlukan biaya registrasi $25 USD.
   - Tidak memerlukan syarat 20 penguji selama 14 hari.
   - Pembaruan aplikasi dapat dirilis secara instan dalam hitungan detik melalui GitHub push.

---

## 2. ARSITEKTUR IN-APP OTA AUTO-UPDATER

Untuk memberikan kenyamanan maksimal bagi pengguna, aplikasi dilengkapi dengan sistem auto-updater:
1. Endpoint Pemeriksaan: GitHub Releases API `biddfad/kshcans-andro`.
2. Alur Pengguna:
   - Aplikasi memeriksa tag versi terbaru saat startup atau via tombol Cek Pembaruan di menu Pengaturan.
   - Jika versi baru tersedia, dialog modal menampilkan changelog dan tombol unduh.
   - Aplikasi mengunduh APK terbaru langsung ke folder unduhan/cache dan memicu instalasi pembaruan.

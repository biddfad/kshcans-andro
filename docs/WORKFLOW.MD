# WORKFLOW SISTEM KSHCANS

Dokumen ini memuat alur kerja eksekusi modul utama pada aplikasi KsHcans.

---

## 1. ALUR PEMBARUAN IN-APP (OTA LIFECYCLE)

```
[Pengguna Buka Aplikasi]
           |
           v
  [Startup Initializer]
           |
           v
[Background Silent Check (3s Delay)]
           |
           v
 [Query version.json / GitHub]
           |
     +-----+-----+
     |           |
(Ada Update) (Versi Terbaru)
     |           |
     v           v
[Tampilkan     [Tidak Melakukan Aksi]
 SnackBar
 Bawah]
     |
(Klik 'Perbarui')
     |
     v
[Dialog Modal OTA]
     |
(Klik 'Perbarui Sekarang')
     |
     v
[Streaming Download ke Cache]
     |
(Persentase 0-100%)
     |
     v
[Panggil MethodChannel installer]
     |
     v
[FileProvider -> PackageInstaller]
```

---

## 2. ALUR MEMBACA INFINITY CONTINUOUS READER

```
[Buka Bab Komik Mode Webtoon]
           |
           v
[Render Lembaran Bab Aktif]
           |
           v
[Pengguna Scroll ke Bawah]
           |
           v
[Sisa Scroll < 1500px?]
           |
         (Ya)
           |
           v
[Prefetch Bab Berikutnya di Latar Belakang]
           |
           v
[Sambungkan Lembaran ke Bawah List]
           |
           v
[Tampilkan Pemisah Cyan Neon Transition Header]
           |
           v
[Update Judul Bab di App Bar & Reset Indikator Halaman]
           |
           v
[Tandai Bab Lama Selesai di SQLite]
```

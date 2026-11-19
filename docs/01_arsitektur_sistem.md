# 01. Arsitektur Sistem & Alur Runtime

Dokumen ini menjelaskan rancangan arsitektur tingkat tinggi (*High-Level Architecture*), cara kerja modul ekstensi, dan bagaimana komponen sistem saling berinteraksi.

---

## 1. Konsep Arsitektur Terdesentralisasi (Decoupled Architecture)

Aplikasi dibangun dengan prinsip pemisahan total antara **Core Reader Engine** dan **Content Providers (Extensions)**:

```mermaid
flowchart TD
    subgraph UI_Layer["1. Lapisan Presentasi (UI Layer)"]
        LibView["Library Screen"]
        BrowseView["Browse / Sources Screen"]
        ReaderView["Reader Canvas (Webtoon/Paged)"]
    end

    subgraph Core_Layer["2. Lapisan Inti Aplikasi (Core Logic)"]
        StateMan["State Management (Bloc / ViewModel)"]
        Downloader["Background Download Queue"]
        CacheMgr["Dual-Tier Image Cache (RAM + Disk)"]
        Sandbox["JS Extension Sandbox Runtime (QuickJS)"]
    end

    subgraph Data_Layer["3. Lapisan Penyimpanan Lokal (Data Layer)"]
        SQLiteDB[("SQLite Database")]
        SecureStore["Hardware Secure Storage (KeyStore)"]
        LocalFiles["File Storage (.cbz / Cached Images)"]
    end

    subgraph Network_Layer["4. Jaringan & Pihak Ketiga (External)"]
        GitHubRepo["GitHub Repo (Katalog Ekstensi)"]
        RealWebsites["Situs Web Komik Asli (CDN)"]
        Trackers["Tracking API (AniList / MAL)"]
    end

    UI_Layer --> Core_Layer
    Core_Layer --> Data_Layer
    Sandbox -->|Unduh Skrip| GitHubRepo
    Sandbox -->|Scraping & Streaming Gambar| RealWebsites
    Core_Layer -->|Update Riwayat| Trackers
```

---

## 2. Peran GitHub Repository vs Website Sumber Komik

Ada perbedaan sangat penting antara peran **GitHub** dan peran **Website Komik**:

```mermaid
sequenceDiagram
    autonumber
    actor Pengguna
    participant App as Aplikasi Kita
    participant GitHub as Repositori GitHub
    participant Website as Website Komik (CDN)

    Pengguna->>App: Buka menu Browse -> Pilih "Install KomikIndo"
    App->>GitHub: GET /extensions/komikindo.js
    GitHub-->>App: File skrip scraper (Hanya teks ~15 KB)
    
    Pengguna->>App: Buka komik "Solo Leveling" Bab 10
    App->>App: Eksekusi komikindo.js di sandbox
    App->>Website: Request daftar halaman ke server sumber
    Website-->>App: URL gambar [page1.jpg, page2.jpg]
    
    App->>Website: Download & stream gambar langsung ke layar HP
    Note over App,Website: Gambar mengalir langsung dari CDN komik ke HP, bukan lewat GitHub!
```

### Mengapa Pola Ini Wajib Digunakan?
1. **Bebas Masalah Hak Cipta (DMCA Compliant):** Repositori GitHub Anda bersih dari konten berhak cipta (hanya kode open-source).
2. **Nol Biaya Server:** Gambar komik ditanggung langsung oleh server penyedia sumber.
3. **Pembaruan Instan:** Jika website komik mengganti layout atau domain, Anda hanya perlu mengedit file script `.js` di GitHub tanpa harus merilis ulang aplikasi di Play Store.

---

## 3. High-Performance Reader Pipeline (Anti-Lag & Anti-OOM)

Bab komik format Webtoon bisa memiliki 50+ potongan gambar berukuran panjang. Untuk mencegah HP kehabisan RAM (*Out of Memory*):

```mermaid
flowchart LR
    Prev["Gambar N-1<br/>(Dibersihkan dari RAM)"]
    Current["Gambar N<br/>(Aktif di Layar / RAM)"]
    Next1["Gambar N+1<br/>(Pre-fetched di RAM)"]
    Next2["Gambar N+2<br/>(Siap di Disk Cache)"]

    Prev -.->|Recycle| Current
    Current --> Next1
    Next1 --> Next2
```

1. **Virtual List Windowing:** Hanya 2-3 elemen gambar yang dialokasikan dalam RAM secara aktif pada satu waktu.
2. **Auto Pre-Fetching:** Sistem secara cerdas mengunduh 2 gambar di depan posisi scroll pengguna secara senyap di background.
3. **Decoded Bitmap Downsampling:** Gambar di-downsample sesuai resolusi layar perangkat sebelum dirender, menghemat pemakaian memori hingga 70%.

---

## 4. Penanganan Cloudflare & Bot Protection

Banyak situs komik menggunakan proteksi Cloudflare Turnstile / Bot Fight.
1. Saat aplikasi menerima respon status `HTTP 403 Forbidden` atau mendeteksi halaman Cloudflare:
2. Aplikasi mengaktifkan **In-App Headless Webview** (jendela browser internal).
3. Webview menyelesaikan tantangan Cloudflare secara otomatis atau dengan interaksi sekali ketuk pengguna.
4. Cookie `cf_clearance` dan nilai `User-Agent` diambil dan disimpan ke dalam session cache.
5. Permintaan data berikutnya menggunakan cookie tersebut sehingga akses langsung lancar.

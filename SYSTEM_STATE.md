# 🧭 System State & Living Context: LarisAI Ecosystem

> **Terakhir Diperbarui**: 2026-10-05 08:30 WIB  
> **Status Build**: Passing (Flutter Mobile & Windows x64, Pure-Dart Excel Engine, SQLite Offline POS, Inno Setup Installer, Go Backend, FastAPI AI Engine)  
> **Root Workspace**: `d:\porto\larisAi`  
> **Ecosystem Scope**: Multi-repo ecosystem (Backend Go, AI Engine, Web Frontend, Desktop App, Mobile App, Cloud HF Monolith)

---

## 🏗️ 1. Peta Ekosistem & Matriks Sub-Project

| Sub-Project | Tipe Aplikasi | Tech Stack Utama | Port / Status Deployment | Remote GitHub |
| :--- | :--- | :--- | :--- | :--- |
| **`LarisAi-Cloud (HF)`**| Monolith Cloud API | Go POS + FastAPI AI + WA + Nginx | ☁️ https://rfahrur6045-sentimentanalysist.hf.space | Hugging Face Space |
| **`LarisAi-Mobile`** | Mobile & Desktop POS | Flutter 3.47, Dart 3.13, sqflite FFI, excel 4.0, pdf, printing, share_plus | 📱 Android (OPPO CPH1933) & 💻 Windows Desktop x64 / Inno Setup Installer | `git@github.com:rfahur11/LarisAi-Mobile.git` |
| **`LarisAi-backend`**| Core Microservices | Golang 1.22 (POS), Node.js (Baileys WA), MongoDB 7.0 / Atlas | ⚙️ Port 8080 (POS), Port 8002 (WA), MongoDB Atlas Cloud | `git@github.com:rfahur11/LarisAi-backend.git` |
| **`LarisAi-AI`**     | AI Inference & ML   | FastAPI, Python 3.11, MLflow, Scikit-Learn, Motor | 🧠 Port 8001 (Stockout Forecasting & RFM Clustering) | `git@github.com:rfahur11/LarisAi-AI.git` |
| **`LarisAi-frontend`**| Web Dashboard & POS | Next.js 15, React 19, TypeScript, TailwindCSS | 🌐 Port 3000 / Netlify | `git@github.com:rfahur11/LarisAi-frontend.git` |
| **`LarisAi-Desktop`** | Windows Desktop App | Electron 34, Node.js (Offline-first POS) | 💻 Windows x64 NSIS Executable | `git@github.com:rfahur11/LarisAi-Desktop.git` |

---

## 🌟 2. Detail Sub-Project (Per Komponen)

### A. LarisAi-Mobile & Desktop (Aplikasi Kasir Multi-Platform)
- **Direktori**: `d:\porto\larisAi\LarisAi-Mobile`
- **Arsitektur & Tech Stack**: 
  - Flutter 3.47.5 (Channel stable), Dart 3.13.4
  - Dual-Engine Architecture: **Local SQLite Engine (`sqflite` + `sqflite_common_ffi`)** untuk Mode Lifetime + **REST API (`dio`)** untuk Mode Cloud SaaS.
  - State Management: `provider` (MultiProvider: ThemeProvider, PosProvider, AiProvider) + `StoreProfileService` (ChangeNotifier).
  - Hardware Kamera Barcode: `mobile_scanner`
  - Charting: `fl_chart` untuk grafik pendapatan harian
  - Thermal Receipt & PDF Engine: `pdf` & `printing` (Format 58mm roll & 80mm roll)
  - Native Spreadsheet Engine: `excel: ^4.0.6` (Pure-Dart XLSX generator)
  - Data Export & Sharing: `path_provider`, `share_plus`, `file_picker`, `crypto`
  - Formatting: `intl` untuk format Rupiah otomatis
- **Fitur Utama**:
  1. **Dual Operational Modes**:
     - 📦 **Mode Lifetime (100% Offline)**: Seluruh database (katalog, transaksi, struk, analitik, dan AI forecasting burn-rate) tersimpan lokal di SQLite HP/PC (`larisai_offline.db`), beroperasi penuh tanpa internet.
     - ☁️ **Mode Subscription (Cloud SaaS)**: Terhubung ke backend MongoDB Atlas & AI Engine Hugging Face.
  2. **Harmonisasi Desktop Bento-Box Experience ($\ge$ 800px)**:
     - **Top Modern Navbar**: Logo LarisAI, badge Smart POS, live pulse "Kasir Aktif: Siap Melayani", Mode Switcher chip, Dark Mode toggle (Sun/Moon), Settings Dialog, dan Kasir Profile dinamis.
     - **Top Navigation Tabs**: Navigasi cepat horizontal antara `[ 🛒 Kasir POS ]`, `[ 📦 Katalog Produk ]`, `[ 🧠 AI Insights & Radar ]`, dan `[ 📊 Laporan & Analitik ]`.
     - **4 Clickable Bento-Box Cards (Interactive Shortcuts)**:
       - `UANG MASUK HARI INI` ➔ Langsung membuka tab **Laporan & Analitik (Tab 3)**.
       - `TOTAL TRANSAKSI` ➔ Membuka modal popup cepat **Riwayat Transaksi & Nota (`OrderHistoryDialog`)** tanpa mengganggu keranjang kasir aktif.
       - `STOK MENIPIS` ➔ Langsung melompat ke tab **Katalog Produk (Tab 1)** untuk memeriksa inventori.
       - `AI STOCKOUT RADAR` ➔ Langsung melompat ke tab **AI Insights & Radar (Tab 2)**.
     - **Split-Screen POS**: Grid katalog kiri (3-5 kolom) dan sticky sidebar checkout kanan (400px) dengan shortcut keyboard kasir (`F1` Search, `F2` Tambah Produk, `F7` Tunai, `F8` QRIS, `F9` Selesai Bayar, `Esc` Reset).
  3. **CRM Customer History & Dual-Mode Input (`CustomerSelectorWidget`)**:
     - Pencarian instan autocomplete pelanggan lama dari SQLite lokal (dengan frekuensi belanja & status loyalitas).
     - Input pelanggan baru dengan 2 kolom terpisah: Nama Pelanggan & Nomor WhatsApp (otomatis tersimpan ke tabel `customers`).
     - Pembersihan filter data agar label transfer/e-wallet tidak mengotori database pelanggan.
  4. **AI Radar & WhatsApp Message Studio (Executive Tactile UI)**:
     - *Stockout Radar*: Prediksi barang yang akan habis dalam 1–4 hari berdasarkan daily burn rate.
     - *Customer Segmentation (RFM)*: Segmentasi Loyal VIP vs Berisiko Churn.
     - *Executive Campaign Action Cards*: Kartu aksi VIP Loyalty Booster & Churn Win-Back yang tactile, bebas AI-slop visual.
     - *WhatsApp Message Studio Modal*: Pratinjau speech bubble WhatsApp otentik (dengan timestamp dan centang biru ganda ✓✓), mode kustomisasi teks draf, dan tombol 1-tap WhatsApp Launcher responsif anti-overflow (tombol primer vertikal + tombol sekunder `Expanded`).
     - *Anti-Overflow Responsive Layout*: Penerapan `LayoutBuilder` pada kartu aksi kampanye (stack vertikal pada layar < 360px) serta `Expanded` + `TextOverflow.ellipsis` pada judul "Daftar Pelanggan Tersegmentasi" dan baris pelanggan.
     - *1-Tap WhatsApp Chat*: Tombol rapi `[ 💬 Chat WA ]` per pelanggan untuk direct chat via `url_launcher`.
  5. **Laporan & Analitik (Time Range Selector & Adaptive Scaling)**:
     - Filter rentang waktu 4-pilihan: `[ Semua Waktu ]`, `[ 📅 Hari Ini ]`, `[ 📊 7 Hari ]`, `[ 🗓️ Bulan Ini ]`.
     - Skala sumbu Y (`maxY`) BarChart adaptif otomatis mengikuti penjualan tertinggi harian (+25%).
     - Urutan data grafik penjualan harian kronologis terbaru dari SQLite lokal.
  6. **Tactile Thermal Paper Receipt & PDF Sharing**:
     - Desain nota struk thermal otentik dengan pemisah dashed divider rapi.
     - Rincian belanja (daftar item, qty, harga) transparan sebelum konfirmasi pembayaran di `CheckoutSheet`.
     - Dynamic divider length (28 karakter untuk 58mm, 40 karakter untuk 80mm) mencegah divider patah menjadi 2 baris di printer thermal.
  7. **Mobile Layout (< 800px) & Zero-Scroll Filter**:
     - Filter stok 4-arah responsif (`Semua`, `🔴 Habis`, `🟡 Menipis ≤5`, `🟢 Aman >5`) yang pas di semua lebar smartphone.
     - Top Mobile AppBar interaktif: Menampilkan nama toko UMKM dinamis, nama kasir aktif, serta badge status koneksi (`OFFLINE` / `CLOUD`).
     - Settings Dialog Multi-Tab & Dark/Bright Mode: TabBar scrollable (`isScrollable: true`) dalam pill capsule container dengan ikon taktil (`Profil UMKM`, `Tema / Tampilan`, `Mode Server`, `Data & Backup`, `Lisensi`), quick theme toggle button di header dialog, serta tab visual kartu taktil Mode Terang (Bright) dan Mode Gelap (Dark) dengan auto-persist `SharedPreferences`.
     - Multi-Tenant Cloud & LAN Store Account Hub: Integrasi `AuthService` dan JWT Bearer injection otomatis pada `Dio` client, dukungan multi-toko (Toko Demo 1 & Toko Demo 2) untuk pengujian sinkronisasi multi-perangkat real-time tanpa data bercampur.
     - Smart Inventory Input Form: Auto thousand-separator formatting Rupiah (`ThousandsSeparatorInputFormatter`), default/placeholder `0`, serta validasi field wajib (`*`).
     - Tombol tambah compact squircle icon button tanpa redundansi.
  8. **Windows Single-File Installer (`.exe`)**:
     - Skrip Inno Setup (`installer.iss`) yang mengompilasi rilis x64 menjadi `LarisAI_Kasir_Setup_v1.0.exe` (14MB).

### B. LarisAi-backend (Core POS & WhatsApp Service)
- **Direktori & Repository**: `d:\porto\larisAi\LarisAi-backend` (`git@github.com:rfahur11/LarisAi-backend.git`)
- **Services**:
  - `pos`: Golang REST API (Port 8080)
    - `GET /api/v1/products`: Daftar produk aktif
    - `GET /api/v1/products/scan/{barcode}`: Cari produk by barcode
    - `POST /api/v1/products`: Tambah produk
    - `POST /api/v1/checkout`: Proses transaksi kasir & kurangi stok
    - `GET /api/v1/transactions`: Riwayat transaksi
    - `GET /api/v1/analytics/summary`: Ringkasan omset & metode pembayaran
  - `whatsapp`: Node.js Baileys service (Port 8002)
    - `POST /api/v1/whatsapp/send`: Pengiriman pesan otomatis WA

### C. LarisAi-AI (AI Engine Service)
- **Direktori & Repository**: `d:\porto\larisAi\LarisAi-AI` (`git@github.com:rfahur11/LarisAi-AI.git`)
- **Tech Stack**: Python FastAPI, Uvicorn (Port 8001)
- **Endpoints**:
  - `GET /api/v1/ai/forecasting/stockouts`: Prediksi kehabisan stok barang
  - `GET /api/v1/ai/clustering/customers`: Pengelompokan RFM pelanggan (Loyal, Churn, Reguler)
  - `POST /api/v1/ai/promo/send`: Background task integrasi promo blast ke WhatsApp service

### D. LarisAi-frontend (Web POS & Portal)
- **Direktori & Repository**: `d:\porto\larisAi\LarisAi-frontend` (`git@github.com:rfahur11/LarisAi-frontend.git`)
- **Tech Stack**: Next.js (App Router), TypeScript, TailwindCSS

### E. LarisAi-Desktop (Offline-First Desktop App)
- **Direktori & Repository**: `d:\porto\larisAi\LarisAi-Desktop` (`git@github.com:rfahur11/LarisAi-Desktop.git`)
- **Tech Stack**: Electron 34, electron-builder (NSIS target)

---

## ⚙️ 3. Environment & Konfigurasi Jaringan Mobile

| Komponen | Default Port | Mode USB (adb reverse) | Mode Wi-Fi LAN |
| :--- | :--- | :--- | :--- |
| **POS Go Service** | `8080` | `http://localhost:8080` | `http://192.168.1.3:8080` |
| **FastAPI AI Engine** | `8001` | `http://localhost:8001` | `http://192.168.1.3:8001` |
| **Baileys WhatsApp** | `8002` | `http://localhost:8002` | `http://192.168.1.3:8002` |
| **MongoDB** | `27017` | `mongodb://localhost:27017` | - |

---

## ⚠️ 4. Known Issues, Gotchas & Solusi Teruji

1. **Cross-Drive Compilation Kotlin di Windows (`C:\` vs `D:\`)**:
   - *Masalah*: Proyek di drive `D:\`, namun pub cache di `C:\Users\black\AppData\Local\Pub\Cache`. Kompiler Kotlin memunculkan `IllegalArgumentException: this and base files have different roots`.
   - *Solusi Teruji*:
     - Setel environment variable permanen `PUB_CACHE=D:\flutter_pub_cache`.
     - Tambahkan di `android/gradle.properties`:
       ```properties
       kotlin.incremental=false
       kotlin.incremental.useClasspathSnapshot=false
       ```
2. **Konektivitas HP Fisik ke Localhost Laptop**:
   - *Masalah*: HP Android menganggap `localhost` adalah dirinya sendiri.
   - *Solusi Teruji*: Gunakan `adb reverse tcp:8080 tcp:8080` dan `adb reverse tcp:8001 tcp:8001` sehingga kabel USB menjadi tunnel transparan.
3. **Android Cleartext Traffic (HTTP vs HTTPS)**:
   - *Masalah*: Android 9+ memblokir panggilan API lokal berprotokol `http://`.
   - *Solusi Teruji*: Tambahkan `android:usesCleartextTraffic="true"` pada tag `<application>` di `AndroidManifest.xml`.
4. **Developer Mode Windows untuk Symlink Flutter**:
   - *Masalah*: Plugin Flutter membutuhkan hak symlink Windows.
   - *Solusi Teruji*: Aktifkan switch **Developer Mode = ON** di pengaturan Windows.

---

## 🚀 5. Quick Runbook Menjalankan Ekosistem LarisAi

```powershell
# 1. Nyalakan Backend LarisAi (Go, AI, Mongo, WA)
cd d:\porto\larisAi\LarisAi-backend\services
docker compose up -d

# 2. Buka Jembatan Port USB ke HP Android
adb reverse tcp:8080 tcp:8080
adb reverse tcp:8001 tcp:8001

# 3. Jalankan Aplikasi Mobile (Hot Reload aktif dengan menekan 'r')
cd d:\porto\larisAi\LarisAi-Mobile
flutter run

# 4. Jalankan Aplikasi di Desktop Windows (Mode Native PC POS)
$env:PUB_CACHE = "D:\flutter_pub_cache"
flutter run -d windows

# 5. Build Installer Windows Setup EXE & Portable ZIP Otomatis
```

---

## 📱 6. Verifikasi Pengujian Multi-Device Fisik (Physical Hardware Concurrency)

> **Tanggal Uji**: 10 Oktober 2026  
> **Perangkat**:
> - 📱 **Device A**: OPPO CPH1933 (Android 11, Serial: `3e893788`) — Tema: **Dark Mode**
> - 📱 **Device B**: OPPO CPH2473 (Android 14, Serial: `ed81fac5`) — Tema: **Light Mode**
> - ☁️ **Cloud Backend**: Hugging Face Spaces (`https://rfahrur6045-sentimentanalysist.hf.space`) + MongoDB Atlas

### Hasil Pengujian:
1. **Skenario 1 (Cloud SaaS Multi-Device Concurrency & Real-Time Stock Sync)**: **PASSED (100%)**
   - Kedua perangkat terhubung ke akun toko Cloud (`admin@larisai.com`) dengan badge **`CLOUD`** aktif.
   - **Device A** membeli 1 pcs Aqua Air Mineral (40 ➔ 39) dan 2 pcs Beras Ramos Super 5kg (8 ➔ 6) via invoice `INV-20261010-2374`.
   - **Device B** membeli 1 pcs Beras Ramos Super 5kg (6 ➔ 5).
   - Katalog pada **Device A** dan **Device B** tersinkronisasi dua arah seketika: stok Beras Ramos menjadi 5 pcs dengan badge warning oranye serempak di kedua layar.
   - Zero race conditions, konsistensi data transaksi dan stok terverifikasi 100%.

2. **Skenario 4 (Offline Fallback & Dual-Engine Independence)**: **PASSED (100%)**
   - **Device A** dialihkan ke **📦 Lifetime Mode** (SQLite lokal di memori internal HP), badge berubah menjadi **`OFFLINE`**.
   - **Device B** tetap aktif dalam mode **`CLOUD`**.
   - Transaksi kasir offline di **Device A** dan perhitungan AI burn-rate forecasting berjalan mandiri tanpa internet dan tanpa saling mengganggu.

---

## 🛠️ 7. RCA & Fix: Mobile Header Badge & Sinkronisasi LAN Multi-Device

> **Log Dokumentasi Obsidian**: `d:\porto\knowledge-base\02-Bug-RCA-Logs\2026-10-10-lan-badge-and-host-sync.md`

### Perbaikan yang Diimplementasikan:
1. **Header Badge Reaktif & Dinamis (`pos_screen.dart` & `desktop_header.dart`)**:
   - Menghapus ternary hardcoded `isOffline ? 'OFFLINE' : 'CLOUD'`.
   - Mengintegrasikan `ApiConstants.modeNotifier`, `ApiConstants.modeBadgeText`, dan `ApiConstants.modeColor`.
   - Status badge kini menampilkan secara akurat dan instan:
     - 📦 **`OFFLINE`** (Teal) untuk Mode Lifetime SQLite lokal.
     - ☁️ **`CLOUD`** (Indigo) untuk Mode Cloud SaaS HF Spaces + MongoDB Atlas.
     - 📶 **`LAN`** (Orange) untuk Mode Wi-Fi LAN lokal kantor / toko.
     - 🔌 **`DEV USB`** (Blue) untuk Mode ADB reverse USB debugging.
2. **Persistence Endpoint Kustom (`settings_dialog.dart`)**:
   - Kustomisasi URL backend POS/AI kini tersimpan secara konsisten tanpa tergantung status accordion dropdown.

---

## 🧪 8. Multi-Mode Testing Protocol & Autonomous Skill Suite (`larisai-testing-protocol`)

- **Skill File**: `C:\Users\black\.gemini\config\skills\larisai-testing-protocol\SKILL.md`
- **Cheatsheet Vault**: `d:\porto\knowledge-base\03-Snippets-Cheatsheets\larisai-testing-guide.md`
- **Helper Scripts**:
  - `d:\porto\larisAi\scripts\verify_lan_host.ps1`
  - `d:\porto\larisAi\scripts\capture_dual_screens.ps1`
- **Fast Execution**:
  ```powershell
  # Probe Host PC Port 8080 & REST endpoints
  powershell -ExecutionPolicy Bypass -File d:\porto\larisAi\scripts\verify_lan_host.ps1

## 🛠️ 9. RCA & Fix: Pengurangan Stok Checkout Mode LAN PC-HP & Self-Healing

- **Log Dokumentasi Obsidian**: `d:\porto\knowledge-base\02-Bug-RCA-Logs\2026-10-11-lan-checkout-stock-reduction.md`
- **Root Cause**: `Product.toJson()` kehilangan field `id`, menyebabkan request checkout HP mengirim `product_id: ""`. Akibatnya `UPDATE products SET stock = MAX(0, stock - ?) WHERE id = ''` di SQLite PC gagal mengupdate produk asli (stok PC tetap), sedangkan HP melakukan in-memory reduction lokal. Selain itu, client & PC sebelumnya masih mengeksekusi binary lama (pre-fix 07:28 AM).
- **Solusi Permanen & Self-Healing**:
  1. `Product.toJson()`: Menyertakan `id` dan `is_archived`.
  2. `CartItem.toCheckoutJson()`: Menyertakan `barcode`, `name`, `price`, dan `quantity` sebagai rich payload.
  3. `LocalDbService.insertTransaction()`: Resilient lookup 4-tier (ID ➔ Barcode ➔ pId as Barcode ➔ Name case-insensitive & LIKE), menjamin stok pada `actualId` di SQLite PASTI berkurang meskipun client lama mengirim request tanpa ID.
  4. `LocalDbService.insertProduct()`: Cek eksistensi barcode sebelum generate ID baru untuk mencegah duplikasi.
  5. SQLite `onOpen`: Menjalankan query deduplikasi otomatis untuk membersihkan data lama.
  6. Unit Test: `test/lan_checkout_stock_sync_test.dart` (2 Test Cases Passed 100%: Normal Flow & Self-Healing Name Fallback).
  7. Binary Distribution: Windows Release EXE & Portable ZIP terupdate, shortcut desktop pengguna diarahkan ke build Release, APK Android rilis terbaru (83.1 MB) dipush ke HP (`/sdcard/Download/LarisAI_Mobile_v1.0.0.apk`).

---

## 🎨 10. RCA & Fix: Mobile Inventory Screen Overflow & Card Overlap

- **Log Dokumentasi Obsidian**: `d:\porto\knowledge-base\02-Bug-RCA-Logs\2026-10-11-mobile-inventory-overflow-fix.md`
- **Gejala**: Pada smartphone, 3 kartu header ringkasan terhimpit horizontal sehingga teks terpotong (`Total Pro...`, `Nilai Ase...`), dan nomor barcode 13 digit mendorong chip kategori tumpang tindih langsung ke badge stok.
- **Solusi**:
  1. `_buildMobileMetricCard` dengan `SingleChildScrollView(scrollDirection: Axis.horizontal)` pada layar mobile (< 700px), menampilkan seluruh label dan nominal angka secara utuh dan dapat digeser mulus.
  2. Bungkus `product.barcode` dan `product.category` dengan `Flexible` dan `TextOverflow.ellipsis`, serta tambahkan `SizedBox(width: 8)` pemisah aman dari badge stok.
  3. Verifikasi live screenshot via ADB pada fisik OPPO (720x1600) membuktikan tampilan 100% rapi dan bebas overlap.

---

## 🚀 11. SaaS Cloud Mode v2.0 & Weboz Centralized Payment Engine

> **Tanggal Rilis**: 11 Oktober 2026  
> **Status**: 🟢 Production Ready (Dual-Engine Strict Isolation + Automated Unit Tests 19/19 Passed)

### Fitur & Arsitektur Utama yang Diterapkan:
1. **Strict Database Isolation & Anti-Illusion (`api_service.dart` & `local_db_service.dart`)**:
   - Menghapus fallback diam-diam ke `larisai_offline.db` saat koneksi Cloud terputus.
   - Mengalokasikan file database cache tenant terpisah: `larisai_cloud_store_<storeId>.db`.
   - Menginisiasi custom exceptions: `CloudConnectionException` dan `LanConnectionException`.
   - Menampilkan alert non-intrusif di UI dengan tombol "Coba Sambungkan Lagi" tanpa memanipulasi database offline mandiri.
2. **Merchant Onboarding & 14-Day Free Trial Engine (`auth_service.dart` & `settings_dialog.dart`)**:
   - Tab ganda bersih di Settings Dialog: `[ 🔑 Masuk Akun ]` vs `[ 📝 Daftar Toko Baru (Free Trial 14 Hari) ]`.
   - Store Profile Card: Menampilkan Store ID, Email Owner, Status Badge (`🎉 Free Trial (Sisa 14 Hari)`), Live Latency Indicator, dan tombol Upgrade.
   - Accordion Sandbox: Tombol Toko Demo 1 & 2 dipindahkan ke collapsible accordion paling bawah (*"🧪 Sandbox / Evaluasi Fitur"*).
3. **In-App Tactile SaaS Payment Sheet (`saas_payment_sheet.dart`)**:
   - 3 kartu pilihan paket: Bulanan Rp 49rb, Tahunan Rp 399rb (Diskon 33%), dan Lifetime LAN Resto Rp 599rb.
   - Integrasi 1-klik salin nomor rekening BCA `8930847403` a.n. `Fahrur Rozi`.
   - Tombol "Bayar Otomatis via QRIS Weboz" (`https://weboz.my.id/larisai?plan=...#checkout`) dengan 0% komisi toko aplikasi.
   - Tombol konfirmasi WhatsApp CS resmi `0888-1264-995` dan tombol instan "Cek Status Pembayaran".
4. **Backend SaaS Engine & Azure FinOps Deployment (`LarisAi-backend`)**:
   - Endpoint Go POS:
     - `POST /api/v1/auth/register-merchant`: Registrasi owner + tenant + store dengan 14 hari free trial & JWT token.
     - `GET /api/v1/subscription/status`: Status langganan real-time (sisa hari, status grace period 3 hari, kuota outlet).
     - `POST /api/v1/subscription/sync`: Webhook billing dari Weboz untuk perpanjangan langganan instan.
   - Template Azure Container Apps (`azure-container-apps.bicep` & `deploy-azure.ps1`) di region `southeastasia` dengan scale-to-zero serverless ($100 Student Cap protection).
   - Mediafire distribution runbook untuk installer Windows (`.exe`) dan Android (`.apk`).






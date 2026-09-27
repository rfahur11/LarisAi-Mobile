# 🧭 System State & Living Context: LarisAI Ecosystem

> **Terakhir Diperbarui**: 2026-09-27 21:05 WIB  
> **Status Build**: Passing (Flutter Mobile, Go POS, FastAPI AI, Next.js Web, Electron Desktop)  
> **Root Workspace**: `d:\porto\larisAi`  
> **Ecosystem Scope**: Multi-repo ecosystem (Backend Go, AI Engine, Web Frontend, Desktop App, Mobile App)

---

## 🏗️ 1. Peta Ekosistem & Matriks Sub-Project

| Sub-Project | Tipe Aplikasi | Tech Stack Utama | Port / Status Deployment | Remote GitHub |
| :--- | :--- | :--- | :--- | :--- |
| **`LarisAi-Mobile`** | Mobile POS & AI App | Flutter 3.47, Dart 3.13, Provider, Dio, MobileScanner, fl_chart | 📱 Running on OPPO CPH1933 (Android 11) | `git@github.com:rfahur11/LarisAi-Mobile.git` (Pending Push) |
| **`LarisAi-backend`**| Core Microservices | Golang 1.22 (POS), Node.js (Baileys WA), MongoDB 7.0 | ⚙️ Port 8080 (POS), Port 8002 (WA), Port 27017 (Mongo) | `git@github.com:rfahur11/LarisAi-backend.git` |
| **`LarisAi-AI`**     | AI Inference & ML   | FastAPI, Python 3.11, MLflow, Scikit-Learn, Motor | 🧠 Port 8001 (Stockout Forecasting & RFM Clustering) | `git@github.com:rfahur11/LarisAi-AI.git` |
| **`LarisAi-frontend`**| Web Dashboard & POS | Next.js 15, React 19, TypeScript, TailwindCSS | 🌐 Port 3000 / Netlify | `git@github.com:rfahur11/LarisAi-frontend.git` |
| **`LarisAi-Desktop`** | Windows Desktop App | Electron 34, Node.js (Offline-first POS) | 💻 Windows x64 NSIS Executable | `git@github.com:rfahur11/LarisAi-Desktop.git` |

---

## 🌟 2. Detail Sub-Project (Per Komponen)

### A. LarisAi-Mobile (Aplikasi Kasir & AI Mobile)
- **Direktori**: `d:\porto\larisAi\LarisAi-Mobile`
- **Arsitektur & Tech Stack**: 
  - Flutter 3.47.5 (Channel stable), Dart 3.13.4
  - State Management: `provider` (MultiProvider: PosProvider, AiProvider)
  - HTTP Network: `dio` dengan configurable Base URL & Mock fallback
  - Hardware Kamera Barcode: `mobile_scanner`
  - Charting: `fl_chart` untuk grafik pendapatan harian
  - Formatting: `intl` untuk format Rupiah otomatis
- **Fitur Utama**:
  1. **Layar Kasir (POS)**: Katalog produk grid, search & filter kategori, cart sticky bottom bar, kalkulator kembalian uang cepat (Quick cash), struk digital (ESC/POS).
  2. **Pemindai Barcode**: Scanner kamera live fullscreen dengan viewfinder box dan toggle flash.
  3. **Manajemen Inventori**: List stok dengan badge urgensi (Aman, Menipis, Habis) dan modal tambah produk baru via kamera barcode.
  4. **AI Intelligence**:
     - *Stockout Radar*: Prediksi barang yang akan habis dalam 1–4 hari berdasarkan daily burn rate.
     - *Customer Segmentation (RFM)*: Segmentasi Loyal VIP vs Berisiko Churn.
     - *1-Tap WhatsApp Campaign*: Trigger pengiriman promo broadcast via WhatsApp Engine.
  5. **Analitik Penjualan**: Ringkasan omset, order count, dan breakdown pembayaran (QRIS, Tunai, Debit).
  6. **Pengaturan Backend**: Switcher mode koneksi (USB `adb reverse` vs Wi-Fi LAN vs Cloud).

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
```

# 🛒 Kirana Store Management App

A production-grade, offline-first mobile and web application built with **Flutter & Drift (SQLite)** tailored specifically for Indian Kirana & General Stores.

---

## ✨ Features

- **⚡ Fast POS Billing Engine**:
  - Barcode scanner integration with camera + manual loose-item quick lookup.
  - Reverse weight calculation (e.g., enter ₹50 of sugar $\rightarrow$ automatically calculates exact weight based on rate).
  - Mixed GST calculation (0%, 5%, 12%, 18%, 28%) with automatic Half-Up round-off and CGST/SGST splitting.
  - GST Tax Invoice vs. Non-GST Standard Bill toggle.
  - Multi-payment support: Cash, UPI / QR, Card, and Credit (Khata).

- **📒 Khatabook-Style Customer Ledger (खाता)**:
  - 4-column ledger table: `Date` | `Debit(-)` | `Credit(+)` | `Balance (Dr/Cr)`.
  - Color-coded transaction cells (Pink `#FFF5F5` for Debit/Udhaar, Green `#F0FDF4` for Credit/Payment).
  - Summary KPI Card with Total Debit, Total Credit, and Net Balance badge.
  - One-tap WhatsApp Statement sharing and customer calling/number copy.
  - Dual action buttons: **YOU GAVE ₹ (Debit)** & **YOU GOT ₹ (Credit)** with instant debounced updates.

- **📦 Smart Inventory & OpenFoodFacts Barcode Lookup**:
  - Local database with instant search, category filtering, and low stock threshold alerts.
  - Automatic product lookup via **OpenFoodFacts API** with bilingual English & Hindi product names.
  - Unit support (kg, g, L, ml, pcs, packet, box).

- **🌐 100% Bilingual (English & हिंदी)**:
  - Instant one-tap language switcher throughout the application.

- **🔒 Offline-First Architecture & Defensive UX**:
  - Local SQLite database powered by **Drift** (with Wasm / Web worker fallback on web).
  - Hardened input validation at the keystroke level with custom `TextInputFormatter`s and domain validators.
  - Financial math powered by arbitrary-precision `Decimal` to eliminate IEEE 754 floating-point errors.

---

## 🛠 Tech Stack

- **Framework**: Flutter (Dart 3.x)
- **State Management**: Riverpod (2.5+)
- **Database**: Drift (SQLite) with WebAssembly (`sqlite3.wasm` + web worker)
- **Math & Precision**: `decimal` package
- **Barcode & Scanner**: `mobile_scanner`, `barcode_widget`
- **External API**: OpenFoodFacts REST API

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.16.0 or later)

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/zaidinabeel/kirana-store.git
   cd kirana-store
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the automated test suite:
   ```bash
   flutter test
   ```

4. Run the app:
   - **Chrome / Web**:
     ```bash
     flutter run -d chrome
     ```
   - **macOS Desktop**:
     ```bash
     flutter run -d macos
     ```
   - **Android / iOS Device**:
     ```bash
     flutter run
     ```

---

## 🧪 Testing

The codebase includes full unit and integration tests covering:
- Mixed GST tax calculations and invoice round-off math.
- Khatabook chronological running balance computation.
- Decimal precision & reverse quantity algorithms.
- Keystroke formatters & input validators.
- Debounced button multi-tap defense.

```bash
flutter test
```

---

## 📱 Phone install (Android) / फ़ोन में डालें

```bash
flutter build apk --release --split-per-abi
```

- Most phones (2017+): `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~26 MB)
- Very old / cheap phones: `app-armeabi-v7a-release.apk`
- Send the APK on WhatsApp, open it on the phone, allow "install unknown apps".

### Data & backup / डेटा और बैकअप
- All data stays **on the phone** (SQLite in the app's private storage). No internet needed except the optional barcode name lookup.
- A backup is made **automatically once a day** in `Documents/KiranaStore/Backups` (kept even if the app is uninstalled; last 10 kept).
- Settings → बैकअप: back up & send to WhatsApp / Google Drive, or restore from a backup file (current data is backed up first).

### Printer / प्रिंटर
- Any 58mm/80mm **Bluetooth ESC/POS** thermal printer. Pair it in phone Bluetooth settings, then Settings → प्रिंटर → प्रिंटर खोजें.
- Receipts print as an image, so Hindi and ₹ print correctly. Settings → रसीद पर क्या छपे turns each line on/off (with live preview) and can print automatically after each bill.

### Reports, expenses, PIN / हिसाब, खर्च, PIN
- Home → हिसाब / मुनाफ़ा: sales, bills, net profit (sales profit minus expenses), payment split, udhaar given/collected, who owes most, best sellers, daily chart — for today, yesterday, this week, this month or last month.
- Profit uses each item's optional purchase price (खरीद का दाम), frozen on the bill at sale time.
- Home → खर्च लिखें: rent, electricity, wages, transport, tea and other expenses.
- Settings → PIN लॉक: 4-digit app lock. The PIN is stored outside the database, so it is not in backups; a forgotten PIN is solved by reinstalling and restoring a backup.

### Help / मदद
- Home → मदद: Hindi step-by-step guides and an offline "ask a question" box (Hindi, Hinglish or English).

---

## 📄 License

MIT License. Free for open source and commercial use.


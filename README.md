# Rekordbox Explorer

**Rekordbox Explorer** is a lightweight desktop tool for browsing and exporting Rekordbox USB libraries **without installing Rekordbox**.

It lets DJs and music collectors open a Rekordbox-exported USB drive, inspect tracks and playlists, search metadata, and export the library to CSV or JSON — all **locally**, with **no uploads and no cloud**.

---

## ✨ Features

- 📂 Open a Rekordbox USB drive or exported folder
- 🔍 Browse and search tracks by title, artist, album, genre, BPM, rating, etc.
- 📑 View Rekordbox playlists and folders
- 📊 Sort columns (BPM, duration, date added, etc.)
- 📤 Export the current view to **CSV** or **JSON**
- 🔒 Runs fully offline — your files never leave your machine

---

## 📀 Supported Rekordbox Data

- Reads `export.pdb`
- Uses `exportExt.pdb` automatically when present (for album metadata)
- Compatible with standard Rekordbox USB exports

---

## 🖥 Platforms

### macOS
- Native SwiftUI macOS app
- Sandboxed and App Store–compatible
- Supports direct USB access and file export

### iOS (in progress)
- iPhone/iPad support planned
- Will allow selecting `export.pdb` from external USB drives via the Files app

---

## 📤 Export

You can export **exactly what you’re viewing** (including search filters and sort order):

- **CSV** — ideal for Excel, Numbers, Google Sheets, printing, or PDF export
- **JSON** — ideal for scripts, data processing, or custom tools

> Note: The CSV export includes an ordered `row` column (1…N).  
> The JSON export remains clean and data-only.

---

## 🔐 Privacy & Security

- No uploads
- No analytics
- No cloud sync
- All parsing happens locally on your device

---

## 🛠 Built With

- Swift & SwiftUI
- Native Rekordbox database parsing (binary `.pdb`)
- macOS App Sandbox–compliant file access

---

## 🚧 Status

- macOS version: **working MVP**
- iOS version: **planned / in progress**

---

## 📄 License

This project is provided as-is for educational and personal use.  
Rekordbox® is a trademark of AlphaTheta / Pioneer DJ.  
This project is not affiliated with or endorsed by them.

---

## 🙌 Acknowledgements

Inspired by the need to inspect Rekordbox USB libraries quickly, without heavyweight software or online tools.

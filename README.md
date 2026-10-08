# Mira 🧾

A beautiful, freelancer-first invoice application for macOS, built with SwiftUI.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-lightgrey)](LICENSE)

## Features

- 📝 **Invoicing** — Create, edit, and track invoices with status workflow (Draft → Sent → Paid)
- 👥 **Client Management** — Organize clients with all their details
- 💶 **Multi-Currency** — EUR, USD, GBP, CHF with exchange rate tracking
- 📊 **Dashboard** — Revenue charts, stats, and recent activity
- 📄 **PDF Export** — Native generation with German/English templates
- 🎨 **Theming** — Custom JSON themes, brand colors, and logo customization
- 🇩🇪 **German Tax Compliance** — VAT IDs, Steuernummer, Kleinunternehmerregelung (§19 UStG)

## Installation

### PKG Installer (Recommended)
Download `Mira-Installer.pkg` from [Releases](../../releases) and run the installer.

### DMG
Download `Mira-x.x.x-macOS.dmg` from [Releases](../../releases) and drag to Applications.

### From Source
```bash
swift build -c release
./run.sh
```

> ⚠️ **First Launch**: macOS may show a security warning since Mira is self-signed. Go to **System Settings → Privacy & Security** and click **Open Anyway**. See the [Wiki](../../wiki) for details.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘K` | Shortcut List |
| `⌘N` | New Invoice |
| `⌘⇧N` | New Client |
| `⌘1/2/3` | Dashboard / Invoices / Clients |
| `⌘,` | Settings |

## Development checks

```bash
swift test
./script/build_and_run.sh --ui-review
```

The UI review mode opens an isolated, in-memory sample store with invoices in multiple currencies. It does not open the saved invoice database, run migration, or check for updates. Changes to demo invoices and company settings are discarded when the app quits. Appearance preferences still use the normal app preferences.

Invoice and client lists support selection, double-click or Return to open, and contextual actions. Invoice columns can be sorted by clicking their headers. Dashboard cards open the corresponding invoice filters; collected revenue uses payment dates and lists amounts that cannot be converted separately.

## Documentation

📚 **[Visit the Wiki](../../wiki)** for full documentation, including:
- Detailed setup guide
- Development & contributing
- Release workflow
- Roadmap & changelog

## Data Storage

All data stays local:
```
~/Library/Application Support/Mira/
```

## License

Private project. All rights reserved.

---

Made with 💕 by Nyanjou 🐱

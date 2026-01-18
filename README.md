# Mira 🧾

A beautiful, freelancer-first invoice application built with SwiftUI.

## Features ✨

- **Clean Onboarding**: Step-by-step setup wizard with full keyboard navigation (Tab/Enter)
- **Client Management**: Add and manage your clients with all their details
- **Invoice Creation**: Fast, keyboard-friendly invoice editor with line items
- **Multi-Currency Support**: Create invoices in EUR, USD, GBP, or CHF with per-invoice currency selection
- **Exchange Rate Tracking**: Auto-fetches live rates when marking foreign invoices as paid (manual fallback)
- **Status Tracking**: Draft → Sent → Paid workflow with overdue detection
- **Dashboard**: Revenue charts, stats, top clients, recent invoices (all in base currency)
- **PDF Export**: Native PDF generation with German/English templates (separate templates per language)
- **Email Integration**: Open in mail client with customizable German/English templates
- **Invoice Templates**: Save and reuse invoice configurations
- **German Tax Compliance**: VAT IDs, Steuernummer, Kleinunternehmerregelung (§19 UStG)
- **Theming**: System theme or Catppuccin (Mocha/Latte) with accent color picker
- **Brand Customization**: Custom brand color and logo on invoices
- **Template Editor**: Resizable text editors with clickable placeholder insertion
- **Atomic Placeholders**: Template placeholders delete as a whole unit

## Installation

### From DMG
Download the latest `Mira-x.x.x-macOS.dmg` from [Releases](../../releases) and drag to Applications.

> ⚠️ **First Launch:** macOS will show an "unidentified developer" warning. See [Why the Warning?](#why-the-unidentified-developer-warning) below.
>
> **To open the app:**
> - **Right-click** (or Control-click) the app → **Open** → **Open**
> - Or run in Terminal: `xattr -cr /Applications/Mira.app`

---

## Why the "Unidentified Developer" Warning?

Mira is **self-signed** rather than notarized with Apple. Here's why:

### 💰 Apple Developer Program costs $99/year
To remove this warning, developers must pay for the Apple Developer Program ($99/year) to get a Developer ID certificate and notarize apps with Apple.

### 🧑‍💻 This is a personal/hobby project
Mira is developed as a side project for personal use and shared freely. The annual fee isn't justified for a free, open-source tool that I maintain in my spare time.

### ✅ The app is safe
- The source code is fully available in this repository
- You can build it yourself: `swift build -c release`
- The app is code-signed (just not with an Apple-issued certificate)
- No data is sent anywhere - everything stays on your Mac

### 🔓 How to open it anyway
1. **Right-click** the app → **Open** → Click **Open** in the dialog
2. Or run: `xattr -cr /Applications/Mira.app`

macOS remembers your choice, so you only need to do this once.

---

### From Source
```bash
cd Mira
./run.sh
```

### Create DMG Installer (locally)
```bash
./create-dmg.sh
# Creates Mira-x.x.x.dmg
```

## Releasing 🚀

Releases are automated via GitHub Actions. To create a new release:

1. Update version in `bundle.sh` and `create-dmg.sh`
2. Commit with `[release x.x.x]` in the message:
   ```bash
   git add -A
   git commit -m "feat: new feature [release 0.2.5]"
   git push
   ```
3. GitHub Actions will automatically:
   - Build the app for macOS
   - Create a signed DMG
   - Create a GitHub Release with the DMG attached

**Example commit messages:**
- `fix: bug fix [release 0.2.5]`
- `feat: new feature [release 0.3.0]`
- `chore: update deps [release 1.0.0]`

The version in `[release x.x.x]` must follow semver format (e.g., `1.0.0`, `0.2.5`).

## Development Setup (VSCode) 🛠️

### Prerequisites

1. **Swift 5.9+** and **macOS 14+**
   ```bash
   swift --version
   ```

2. **VSCode Extensions** (optional):
   - [Swift](https://marketplace.visualstudio.com/items?itemName=sswg.swift-lang)
   - [CodeLLDB](https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb)

### Building

```bash
# Build
swift build

# Build release
swift build -c release

# Create app bundle and run
./run.sh
```

### Project Structure

```
Mira/
├── Package.swift
├── README.md
├── run.sh                    # Build & run app bundle
├── bundle.sh                 # Create .app bundle
├── create-dmg.sh             # Create DMG installer
└── Sources/Mira/
    ├── App/
    │   ├── MiraApp.swift     # App entry point & state
    │   └── ContentView.swift
    ├── Models/
    │   ├── CompanyProfile.swift
    │   ├── Client.swift
    │   ├── Invoice.swift
    │   ├── InvoiceTemplate.swift
    │   └── AppTheme.swift
    ├── Views/
    │   ├── Onboarding/       # Setup wizard
    │   ├── Dashboard/        # Stats & overview
    │   ├── Invoices/         # List, editor, detail
    │   ├── Clients/          # Client management
    │   └── Settings/         # App settings
    ├── Services/
    │   └── PDFGenerator.swift
    ├── Components/
    │   └── BrandColorPicker.swift
    └── Utils/
        ├── ColorExtensions.swift
        └── AdaptiveColors.swift
```

## Keyboard Shortcuts ⌨️

| Shortcut | Action |
|----------|--------|
| `⌘K` | Show Shortcutlist |
| `⌘N` | New Invoice |
| `⌘⇧N` | New Client |
| `⌘1` | Dashboard |
| `⌘2` | Invoices |
| `⌘3` | Clients |
| `⌘,` | Settings |

## Roadmap 🗺️

### Completed ✅
- [x] Company profile setup
- [x] Client management
- [x] Invoice creation & editing
- [x] Status tracking (draft/sent/paid/overdue/cancelled)
- [x] Dashboard with revenue chart & stats
- [x] Native PDF generation (German/English)
- [x] Email integration (opens mail client)
- [x] Invoice templates
- [x] VAT exemption (Kleinunternehmerregelung §19 UStG)
- [x] Search & filter invoices
- [x] Sort by date/amount/client
- [x] Customizable email template with placeholders (German/English)
- [x] Theme support (System / Catppuccin)
- [x] Brand color & logo customization
- [x] JSON file storage
- [x] Keyboard shortcuts (layout-independent)
- [x] DMG installer
- [x] Multi-currency per invoice (EUR, USD, GBP, CHF)
- [x] Base currency selection
- [x] Exchange rate tracking with auto-fetch

### Next 🚧
- [ ] Recurring invoices
- [ ] Payment reminders (dunning)
- [ ] CSV/data export
- [ ] VAT summary reports
- [ ] Backup/restore

### Future 🔮
- [ ] ZUGFeRD/XRechnung export
- [ ] Stripe/PayPal payment links
- [ ] Client portal
- [ ] Bank reconciliation
- [ ] iOS companion app

## Tech Stack

- **SwiftUI** - Declarative UI
- **Swift Package Manager** - Build system
- **CoreGraphics/PDFKit** - Native PDF generation
- **JSON Files** - Data persistence (`~/Library/Application Support/Mira/`)

## Data Location

All data is stored locally:
```
~/Library/Application Support/Mira/
├── profile.json      # Company profile
├── clients.json      # Client list
├── invoices.json     # Invoices
└── templates.json    # Invoice templates
```

## License

Private project. All rights reserved.

---

Made with 💕 by Nyanjou 🐱

# Invoice App 🧾

A beautiful, freelancer-first invoice application built with SwiftUI.

## Features ✨

- **Clean Onboarding**: Step-by-step setup wizard for your business profile
- **Client Management**: Add and manage your clients with all their details
- **Invoice Creation**: Fast, keyboard-friendly invoice editor with line items
- **Status Tracking**: Draft → Sent → Paid workflow with overdue detection
- **Dashboard**: At-a-glance overview of your invoicing status
- **German Tax Compliance**: Built-in support for VAT IDs, Steuernummer, and proper invoice numbering

## Development Setup (VSCode) 🛠️

### Prerequisites

1. **Install Swift**: Make sure you have Swift installed
   ```bash
   # Check Swift version
   swift --version
   ```

2. **Install VSCode Extensions**:
   - [Swift](https://marketplace.visualstudio.com/items?itemName=sswg.swift-lang) - Official Swift extension
   - [CodeLLDB](https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb) - For debugging

### Building

```bash
# Navigate to the project
cd InvoiceApp

# Build the project
swift build

# Run (for CLI testing - note: SwiftUI needs a proper app bundle for GUI)
swift run
```

### For Full GUI Development

While you can edit code in VSCode, building a proper macOS/iOS app with GUI requires Xcode for:
- Creating the app bundle
- Code signing
- Running on simulator/device

**Hybrid Workflow (Recommended)**:
1. Edit code in VSCode (better for text editing)
2. Build and run with Xcode when needed

### Project Structure

```
InvoiceApp/
├── Package.swift              # Swift Package definition
├── README.md                  # This file
└── Sources/
    └── InvoiceApp/
        ├── App/               # App entry point & state
        │   ├── InvoiceAppMain.swift
        │   └── ContentView.swift
        ├── Models/            # Data models
        │   ├── CompanyProfile.swift
        │   ├── Client.swift
        │   └── Invoice.swift
        ├── Views/
        │   ├── Onboarding/    # Onboarding flow
        │   ├── Dashboard/     # Main dashboard
        │   ├── Invoices/      # Invoice list, editor, detail
        │   ├── Clients/       # Client management
        │   └── Settings/      # App settings
        ├── ViewModels/        # (Future) View models
        ├── Services/          # (Future) Business logic
        ├── Utils/             # (Future) Utilities
        ├── Components/        # (Future) Reusable components
        └── Resources/         # Assets
```

## Converting to Xcode Project

If you need a proper .xcodeproj:

```bash
# Generate Xcode project from Package.swift
swift package generate-xcodeproj

# Or open directly in Xcode (Xcode can read Package.swift)
open Package.swift
```

## Roadmap 🗺️

### MVP (Current)
- [x] Company profile setup
- [x] Client management
- [x] Invoice creation & editing
- [x] Status tracking (draft/sent/paid/overdue)
- [x] Dashboard overview
- [ ] PDF generation
- [ ] Email sending

### Next
- [ ] Recurring invoices
- [ ] Payment reminders (dunning)
- [ ] Stripe payment links
- [ ] CSV/data export
- [ ] VAT summary reports

### Future
- [ ] Multi-currency support
- [ ] ZUGFeRD/XRechnung export
- [ ] Client portal
- [ ] Bank reconciliation

## Tech Stack

- **SwiftUI** - Modern declarative UI
- **Swift Package Manager** - Dependency management
- **UserDefaults** - Local data persistence (MVP; consider SwiftData/CoreData for production)

## License

Private project. All rights reserved.

---

Made with 💕 by Nyanjou 🐱

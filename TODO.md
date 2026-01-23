# Mira - TODO

## Completed ✅

### Core Features
- [x] Company profile setup (onboarding)
- [x] Client management (CRUD)
- [x] Invoice creation & editing
- [x] Line items with VAT
- [x] Status tracking (draft/sent/paid/overdue/cancelled)
- [x] Dashboard with revenue chart & stats
- [x] Top clients by revenue
- [x] Recent invoices list

### PDF & Export
- [x] Native PDF generation (CoreGraphics)
- [x] Multi-language PDF (German/English)
- [x] Brand color on PDF
- [x] Logo on PDF
- [x] VAT exemption notice on PDF
- [x] Bank details on PDF

### Email
- [x] Open in mail client
- [x] Auto-export PDF to Downloads
- [x] Customizable email template
- [x] Placeholder insertion at cursor

### Search & Filter
- [x] Search by invoice #, client, notes
- [x] Filter by status
- [x] Sort by date/amount/client

### Templates
- [x] Save invoice as template
- [x] Apply template to new invoice

### Tax
- [x] VAT ID support
- [x] Tax number support
- [x] Kleinunternehmerregelung (§19 UStG)
- [x] VAT breakdown on invoices

### UI/UX
- [x] Theme support (System / Catppuccin)
- [x] Catppuccin Mocha (dark) / Latte (light)
- [x] Accent color picker
- [x] Brand color picker
- [x] Logo upload
- [x] Keyboard shortcuts (layout-independent)
- [x] Clean onboarding flow
- [x] Onboarding pre-populates when restarting

### Multi-Currency
- [x] Per-invoice currency selection (EUR, USD, GBP, CHF)
- [x] Base currency selection in onboarding
- [x] Currency picker in invoice editor
- [x] Exchange rate tracking when marking paid
- [x] Auto-fetch exchange rates (Frankfurter API)
- [x] Manual exchange rate fallback
- [x] Dashboard shows amounts in base currency
- [x] Invoice list shows original + converted amounts

### Email
- [x] Open in mail client
- [x] Auto-export PDF to Downloads
- [x] Customizable email template
- [x] Placeholder insertion at cursor
- [x] Placeholders delete as atomic blocks
- [x] Email template language selection (German/English)

### Themes
- [x] Custom themes via JSON files
- [x] Load from `~/Library/Application Support/Mira/Themes/*.json`
- [x] Theme preview cards with color swatches
- [x] Import themes from JSON file (file picker)
- [x] Export themes to JSON file
- [x] Delete custom themes (right-click context menu)
- [x] Theme metadata display (author, version, accent count)

### PDF Templates
- [x] Separate German/English PDF templates
- [x] Footer, Closing Message, Notes/Terms per language
- [x] Resizable template text editors
- [x] Clickable placeholder insertion

### Onboarding
- [x] Full keyboard navigation (Tab/Enter/Escape)
- [x] Auto-focus first field on each step
- [x] Hide keyboard hints on text editor steps

### Technical
- [x] JSON file storage
- [x] DMG installer script
- [x] App bundle script
- [x] Self-signed code signing in CI/CD
- [x] Custom DMG background with arrow

## Next Up 🚧

### Priority
- [ ] Recurring invoices (monthly/weekly)
- [ ] Payment reminders (dunning levels)

### Export
- [ ] CSV export
- [ ] Backup/restore data
- [ ] VAT summary report for tax filing

### UX Improvements
- [ ] Duplicate invoice
- [ ] Bulk status change
- [ ] Invoice preview before export
- [ ] Dark mode PDF option

## Future 🔮

### Integrations
- [ ] ZUGFeRD/XRechnung e-invoice
- [ ] Stripe payment links
- [ ] PayPal.me links
- [ ] Bank CSV import for reconciliation

### Advanced
- [ ] Client portal (web)
- [ ] iOS companion app
- [ ] iCloud sync
- [ ] Receipt/expense tracking

### Monetization (Way Later)
- [ ] License key system
- [ ] Gumroad/LemonSqueezy integration
- [ ] Pro features gating

---

Version: 0.2.39

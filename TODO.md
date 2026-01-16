# Invoice App - TODO & Ideas

## 🐛 Bug Fixes
- [ ] Invoice editor/detail views need theme colors applied
- [ ] Form fields in sheets don't use theme colors (system Forms)
- [ ] Logo picker needs theme-aware styling

## 🎨 UI/UX Improvements
- [ ] Add hover states on sidebar buttons
- [ ] Add subtle animations on view transitions
- [ ] Empty states with illustrations (no invoices, no clients)
- [ ] Keyboard shortcuts (⌘N new invoice, ⌘, settings, etc.)
- [ ] Drag & drop line items to reorder
- [ ] Quick actions menu (right-click on invoice)
- [ ] Search with keyboard shortcut (⌘F)
- [ ] Toast notifications for actions (saved, sent, etc.)

## 📄 Invoice Features
- [ ] PDF export (proper native PDF, not HTML)
- [ ] Email invoice directly from app
- [ ] Duplicate invoice
- [ ] Invoice templates (save line item sets)
- [ ] Recurring invoices (weekly/monthly/yearly)
- [ ] Credit notes / corrections
- [ ] Partial payments tracking
- [ ] Payment reminders (auto or manual)
- [ ] Attach files to invoices
- [ ] Multi-language invoices (DE/EN switch per client)
- [ ] Custom invoice number formats (e.g., {YEAR}-{CLIENT}-{NUM})

## 👥 Client Features
- [ ] Client notes / activity history
- [ ] Multiple contacts per client
- [ ] Client-specific default rates
- [ ] Import clients from CSV
- [ ] Client tags / categories
- [ ] Quick client creation from invoice editor

## 📊 Dashboard & Reporting
- [ ] Revenue chart (monthly/yearly)
- [ ] Outstanding vs paid visualization
- [ ] Top clients by revenue
- [ ] Invoice aging report
- [ ] VAT summary for tax filing
- [ ] Export reports to CSV/PDF
- [ ] Year-over-year comparison
- [ ] Forecast based on recurring invoices

## 💾 Data & Storage
- [ ] SQLite or SwiftData instead of UserDefaults (for larger datasets)
- [ ] iCloud sync
- [ ] Export/import all data (backup)
- [ ] Data encryption at rest
- [ ] Auto-backup to folder

## 🔗 Integrations
- [ ] Bank connection (FinTS) for payment matching
- [ ] Stripe/PayPal payment links on invoices
- [ ] Calendar integration (due dates)
- [ ] Accounting software export (DATEV, lexoffice)
- [ ] ZUGFeRD/XRechnung PDF generation (German e-invoice standard)

## ⚙️ Settings & Preferences
- [ ] Multiple business profiles
- [ ] Custom PDF templates
- [ ] Email templates (customizable)
- [ ] Notification preferences
- [ ] Auto-save drafts
- [ ] Default line items / services library

## 🚀 Performance
- [ ] Lazy loading for large invoice lists
- [ ] Pagination for clients/invoices
- [ ] Background PDF generation
- [ ] Caching for frequently accessed data

## 🧪 Quality
- [ ] Unit tests for models
- [ ] UI tests for critical flows
- [ ] Accessibility audit (VoiceOver support)
- [ ] Localization (German, English)

## 💡 Nice-to-Have
- [ ] Widget for dashboard stats
- [ ] Menu bar quick access
- [ ] Touch Bar support (if applicable)
- [ ] Siri shortcuts ("Create invoice for [Client]")
- [ ] Dark mode invoice PDF option
- [ ] QR code on invoice (for payment)

---

## Priority Order (MVP+)
1. ✅ Proper PDF export (native CoreGraphics PDF)
2. ✅ JSON file storage (in ~/Library/Application Support/InvoiceApp/)
3. ✅ Keyboard shortcuts (⌘N new invoice, ⌘⇧N new client, ⌘1-3 nav, ⌘, settings)
4. Email integration
5. VAT summary report
6. Recurring invoices

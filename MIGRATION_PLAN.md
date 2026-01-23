# Mira - SwiftData + Encryption + CloudKit Migration

## Overview
Migrate from plain JSON file storage to encrypted SwiftData with CloudKit sync.

## Current State
- JSON files in `~/Library/Application Support/Mira/`
- No encryption
- No sync

## Target State
- SwiftData with `ModelContainer`
- Sensitive fields encrypted with CryptoKit (AES-GCM)
- Encryption key stored in Keychain
- CloudKit sync via SwiftData's CloudKit integration

---

## Sensitive Fields (to encrypt)

### CompanyProfile
- `iban` ⚠️
- `bic` ⚠️
- `vatId`
- `taxNumber`
- `bankName`
- `accountHolder`

### Client
- `vatId`
- `taxNumber`
- `email` ⚠️
- `phone`

### Invoice
- `paymentReference`
- `internalNotes`

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Views                            │
├─────────────────────────────────────────────────────┤
│              DataManager (ObservableObject)         │
│    ┌─────────────┐  ┌─────────────┐                │
│    │ ModelContext│  │EncryptionSvc│                │
│    └──────┬──────┘  └──────┬──────┘                │
│           │                │                        │
│    ┌──────▼────────────────▼──────┐                │
│    │      SwiftData Models        │                │
│    │   (with encrypted fields)    │                │
│    └──────────────┬───────────────┘                │
│                   │                                 │
│    ┌──────────────▼───────────────┐                │
│    │    ModelContainer            │                │
│    │  (CloudKit enabled)          │                │
│    └──────────────────────────────┘                │
└─────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Encryption Service ✅
- [x] Create `EncryptionService` with CryptoKit
- [x] AES-GCM for field encryption
- [x] Keychain storage for encryption key (iCloud Keychain enabled)
- [x] Auto-generate key on first use
- [x] Key export/import for backup

### Phase 2: SwiftData Models ✅
- [x] `SDCompanyProfile` - company data with encrypted bank/tax fields
- [x] `SDClient` - client data with encrypted contact/tax fields
- [x] `SDInvoice` - invoice data with encrypted internal notes
- [x] `SDLineItem` - line items (Codable struct, stored as JSON)
- [x] `SDInvoiceTemplate` - templates
- [x] Add encrypted computed properties
- [x] Migration helpers (legacy ↔ SwiftData)

### Phase 3: Data Layer ✅
- [x] `DataContainer` - SwiftData container with CloudKit config
- [x] `MigrationService` - JSON → SwiftData migration
- [x] Backup old JSON before migration
- [x] Rollback support
- [ ] `DataManager` - ObservableObject wrapper (optional, may not need)

### Phase 4: View Updates
- [ ] Update `MiraApp` with ModelContainer
- [ ] Update all views to use @Query / @Environment
- [ ] Remove old JSON persistence code

### Phase 5: CloudKit
- [ ] Add CloudKit capability to project
- [ ] Create iCloud container
- [ ] Enable CloudKit in ModelContainer
- [ ] Test sync between devices

### Phase 6: Polish
- [ ] Error handling for sync conflicts
- [ ] Offline indicator
- [ ] Sync status UI
- [ ] Migration rollback if needed

---

## Files to Create

```
Sources/Mira/
├── Services/
│   ├── EncryptionService.swift    ← CryptoKit + Keychain
│   ├── DataManager.swift          ← Central data access
│   └── MigrationService.swift     ← JSON → SwiftData
├── Models/
│   ├── SwiftData/
│   │   ├── SDCompanyProfile.swift
│   │   ├── SDClient.swift
│   │   ├── SDInvoice.swift
│   │   ├── SDLineItem.swift
│   │   └── SDInvoiceTemplate.swift
│   └── (keep old models for migration)
```

---

## Notes

- SwiftData requires macOS 14+ (already required by Mira ✅)
- CloudKit requires Apple Developer account for container
- Encryption key stays LOCAL (not synced) - each device has own key
- Encrypted fields sync as opaque Data blobs
- First device to set up becomes "source of truth" for encryption

---

## Risk Mitigation

1. **Data loss**: Backup JSON before migration, keep old files for 30 days
2. **Encryption key loss**: Document key recovery (export to secure location)
3. **Sync conflicts**: SwiftData handles merge, test thoroughly
4. **Migration failure**: Rollback mechanism, keep old code path

---

Started: 2026-01-23

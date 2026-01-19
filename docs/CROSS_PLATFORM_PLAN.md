# Mira Cross-Platform Plan

## Overview

**Goal:** Make Mira available on macOS, Windows, Linux, and Web while keeping a single source of truth for business logic.

**Architecture:** Separate the app into a Swift backend core and platform-specific UI frontends.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      MiraCore (Swift)                        │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │    Models    │  │   Services   │  │  PDF Engine  │       │
│  │              │  │              │  │              │       │
│  │ - Invoice    │  │ - DataStore  │  │ - Generator  │       │
│  │ - Client     │  │ - Calculator │  │ - Templates  │       │
│  │ - Company    │  │ - Validator  │  │ - Exporter   │       │
│  │ - LineItem   │  │ - Importer   │  │              │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │              REST API Server (Vapor)              │       │
│  │                                                   │       │
│  │  GET  /api/invoices      - List invoices         │       │
│  │  POST /api/invoices      - Create invoice        │       │
│  │  GET  /api/invoices/:id  - Get invoice           │       │
│  │  PUT  /api/invoices/:id  - Update invoice        │       │
│  │  POST /api/invoices/:id/pdf - Generate PDF       │       │
│  │  GET  /api/clients       - List clients          │       │
│  │  ...                                             │       │
│  └──────────────────────────────────────────────────┘       │
│                                                              │
└─────────────────────────────┬────────────────────────────────┘
                              │
                              │ HTTP / localhost:8742
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Mira macOS   │    │ Mira Desktop  │    │   Mira Web    │
│   (SwiftUI)   │    │   (Flutter)   │    │    (React)    │
│               │    │               │    │               │
│  - Native UX  │    │ - Windows     │    │ - Any browser │
│  - App Store  │    │ - Linux       │    │ - Mobile web  │
│               │    │ - macOS alt   │    │ - PWA option  │
└───────────────┘    └───────────────┘    └───────────────┘
```

---

## Phase 1: Extract MiraCore (2-3 weeks)

### Step 1.1: Create Swift Package Structure

```
Mira/
├── Package.swift
├── Sources/
│   ├── MiraCore/           # Shared business logic
│   │   ├── Models/
│   │   │   ├── Invoice.swift
│   │   │   ├── Client.swift
│   │   │   ├── CompanyProfile.swift
│   │   │   ├── LineItem.swift
│   │   │   └── ...
│   │   ├── Services/
│   │   │   ├── DataStore.swift
│   │   │   ├── InvoiceCalculator.swift
│   │   │   ├── PDFGenerator.swift
│   │   │   └── ...
│   │   └── MiraCore.swift  # Public API
│   │
│   ├── MiraAPI/            # REST API server
│   │   ├── Server.swift
│   │   ├── Routes/
│   │   │   ├── InvoiceRoutes.swift
│   │   │   ├── ClientRoutes.swift
│   │   │   └── ...
│   │   └── ...
│   │
│   └── MiraApp/            # SwiftUI macOS app
│       ├── App/
│       ├── Views/
│       └── ...
```

### Step 1.2: Define MiraCore Public API

```swift
// MiraCore/MiraCore.swift

public class MiraCore {
    public static let shared = MiraCore()
    
    // Data Access
    public var invoices: [Invoice] { get }
    public var clients: [Client] { get }
    public var companyProfile: CompanyProfile? { get set }
    
    // Invoice Operations
    public func createInvoice(_ invoice: Invoice) throws -> Invoice
    public func updateInvoice(_ invoice: Invoice) throws -> Invoice
    public func deleteInvoice(id: UUID) throws
    public func getInvoice(id: UUID) -> Invoice?
    
    // Client Operations
    public func createClient(_ client: Client) throws -> Client
    public func updateClient(_ client: Client) throws -> Client
    public func deleteClient(id: UUID) throws
    
    // PDF Generation
    public func generatePDF(for invoice: Invoice, language: Language) throws -> Data
    
    // Import/Export
    public func exportData() throws -> Data
    public func importData(_ data: Data) throws
    
    // Statistics
    public func getStatistics(for period: DateRange) -> Statistics
}
```

### Step 1.3: Make Models Codable & Cross-Platform

```swift
// Ensure all models are JSON-serializable
public struct Invoice: Codable, Identifiable, Sendable {
    public var id: UUID
    public var number: String
    public var clientId: UUID
    public var date: Date
    public var dueDate: Date
    public var lineItems: [LineItem]
    public var status: InvoiceStatus
    // ...
}

// Use only cross-platform types
// ❌ NSColor, CGColor (Apple-only)
// ✅ String hex colors "#FF5733"
// ❌ NSImage, UIImage
// ✅ Data (raw image bytes)
```

---

## Phase 2: Build REST API Server (2-3 weeks)

### Step 2.1: Add Vapor Dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
],
targets: [
    .target(name: "MiraCore", dependencies: []),
    .executableTarget(
        name: "MiraAPI",
        dependencies: [
            "MiraCore",
            .product(name: "Vapor", package: "vapor"),
        ]
    ),
]
```

### Step 2.2: Define API Routes

```swift
// MiraAPI/Routes/InvoiceRoutes.swift

import Vapor
import MiraCore

func invoiceRoutes(_ app: Application) throws {
    let invoices = app.grouped("api", "invoices")
    
    // GET /api/invoices
    invoices.get { req -> [Invoice] in
        return MiraCore.shared.invoices
    }
    
    // GET /api/invoices/:id
    invoices.get(":id") { req -> Invoice in
        guard let id = req.parameters.get("id", as: UUID.self),
              let invoice = MiraCore.shared.getInvoice(id: id) else {
            throw Abort(.notFound)
        }
        return invoice
    }
    
    // POST /api/invoices
    invoices.post { req -> Invoice in
        let input = try req.content.decode(CreateInvoiceInput.self)
        return try MiraCore.shared.createInvoice(input.toInvoice())
    }
    
    // PUT /api/invoices/:id
    invoices.put(":id") { req -> Invoice in
        let invoice = try req.content.decode(Invoice.self)
        return try MiraCore.shared.updateInvoice(invoice)
    }
    
    // DELETE /api/invoices/:id
    invoices.delete(":id") { req -> HTTPStatus in
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        try MiraCore.shared.deleteInvoice(id: id)
        return .ok
    }
    
    // POST /api/invoices/:id/pdf
    invoices.post(":id", "pdf") { req -> Response in
        guard let id = req.parameters.get("id", as: UUID.self),
              let invoice = MiraCore.shared.getInvoice(id: id) else {
            throw Abort(.notFound)
        }
        
        let language = try? req.query.get(String.self, at: "language") ?? "en"
        let pdfData = try MiraCore.shared.generatePDF(for: invoice, language: Language(rawValue: language) ?? .english)
        
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/pdf"],
            body: .init(data: pdfData)
        )
    }
}
```

### Step 2.3: API Server Entry Point

```swift
// MiraAPI/main.swift

import Vapor
import MiraCore

@main
struct MiraAPIServer {
    static func main() async throws {
        let app = Application()
        defer { app.shutdown() }
        
        // CORS for web frontend
        app.middleware.use(CORSMiddleware(configuration: .init(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .PUT, .DELETE],
            allowedHeaders: [.accept, .contentType]
        )))
        
        // Routes
        try invoiceRoutes(app)
        try clientRoutes(app)
        try companyRoutes(app)
        try statisticsRoutes(app)
        
        // Start on localhost:8742
        app.http.server.configuration.port = 8742
        
        print("🚀 Mira API running on http://localhost:8742")
        try app.run()
    }
}
```

### Step 2.4: Embed Server in macOS App

```swift
// MiraApp/App/MiraApp.swift

import SwiftUI
import MiraAPI

@main
struct MiraApp: App {
    init() {
        // Start API server in background
        Task {
            try? await MiraAPIServer.start()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## Phase 3: Platform Frontends

### Option A: Flutter (Windows, Linux, macOS)

**Pros:**
- Single codebase for all desktop platforms
- Great developer experience
- Hot reload
- Large ecosystem

**Cons:**
- Different look from native macOS
- Larger bundle size
- Learning Dart

```dart
// lib/services/mira_api.dart

class MiraAPI {
  static const baseUrl = 'http://localhost:8742/api';
  
  Future<List<Invoice>> getInvoices() async {
    final response = await http.get(Uri.parse('$baseUrl/invoices'));
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Invoice.fromJson(json)).toList();
  }
  
  Future<Invoice> createInvoice(Invoice invoice) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invoices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(invoice.toJson()),
    );
    return Invoice.fromJson(jsonDecode(response.body));
  }
  
  Future<Uint8List> generatePDF(String invoiceId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invoices/$invoiceId/pdf'),
    );
    return response.bodyBytes;
  }
}
```

### Option B: Tauri + React/Vue (Windows, Linux, macOS)

**Pros:**
- Tiny bundle size (~10MB vs ~100MB Electron)
- Web tech (familiar if you know React)
- Native performance
- Can embed Swift backend

**Cons:**
- Rust knowledge helpful
- Newer ecosystem

```typescript
// src/api/invoices.ts

const API_BASE = 'http://localhost:8742/api';

export async function getInvoices(): Promise<Invoice[]> {
  const response = await fetch(`${API_BASE}/invoices`);
  return response.json();
}

export async function createInvoice(invoice: Partial<Invoice>): Promise<Invoice> {
  const response = await fetch(`${API_BASE}/invoices`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(invoice),
  });
  return response.json();
}
```

### Option C: Web App (Browser)

**Pros:**
- Works everywhere (any device with browser)
- Easy updates (no app store)
- Can be PWA (installable)

**Cons:**
- Needs hosted backend (can't run locally)
- Less native feel
- Offline support tricky

**For web deployment:**
- Deploy API to cloud (Fly.io, Railway, etc.)
- Deploy frontend to Vercel/Netlify
- Add authentication layer

---

## Phase 4: Distribution

### macOS (Current)
- Direct .dmg download
- Possibly Mac App Store later
- Sparkle for updates ✅

### Windows (Flutter)
```yaml
# pubspec.yaml
msix_config:
  display_name: Mira
  publisher: Snupai
  identity_name: com.snupai.mira
```
- Build: `flutter build windows`
- Distribute: MSIX installer, Windows Store, or direct .exe

### Linux (Flutter)
```bash
flutter build linux
# Creates: build/linux/x64/release/bundle/
```
- Distribute: AppImage, Flatpak, Snap, or .deb/.rpm

### Web
```bash
flutter build web
# Deploy to Vercel/Netlify
```

---

## File/Data Sync Considerations

### Local-First Architecture

Each platform stores data locally:
- macOS: `~/Library/Application Support/Mira/`
- Windows: `%APPDATA%/Mira/`
- Linux: `~/.local/share/Mira/`

### Future: Cloud Sync

Options for syncing across devices:
1. **iCloud** (Apple only)
2. **Dropbox/Google Drive** (sync data folder)
3. **Custom backend** (PostgreSQL + API)
4. **CRDTs** (conflict-free sync like Notion)

---

## Recommended Path

### If you want quick Windows/Linux support:
1. ✅ Extract MiraCore (Phase 1)
2. ✅ Build REST API (Phase 2)  
3. ✅ Build Flutter frontend (Phase 3A)
4. Ship separate apps that all talk to same API

### If you want web support:
1. ✅ Extract MiraCore
2. ✅ Build REST API
3. ✅ Deploy API to cloud
4. ✅ Build React/Vue frontend
5. Add authentication

### Estimated Timeline

| Phase | Duration | Result |
|-------|----------|--------|
| Extract MiraCore | 2-3 weeks | Reusable Swift package |
| Build REST API | 2-3 weeks | Local API server |
| Flutter Desktop | 3-4 weeks | Windows + Linux apps |
| Web Frontend | 2-3 weeks | Browser version |
| **Total** | **9-13 weeks** | **All platforms** |

---

## Summary

```
                    Today                          Future
                      │                              │
                      ▼                              ▼
              ┌───────────────┐           ┌───────────────────────┐
              │  Mira macOS   │           │      MiraCore         │
              │   (SwiftUI)   │    ──►    │   (Swift Package)     │
              │   Monolithic  │           │                       │
              └───────────────┘           └───────────┬───────────┘
                                                      │
                                          ┌───────────┼───────────┐
                                          │           │           │
                                          ▼           ▼           ▼
                                      SwiftUI     Flutter       Web
                                      (macOS)   (Win/Linux)  (Browser)
```

The key insight: **Keep Swift for what it's good at** (business logic, PDF generation, data handling) and **use the right tool for each platform's UI**.

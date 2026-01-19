# Mira Cross-Platform Plan (Rust Core)

## Overview

**Goal:** Make Mira available on macOS, Windows, Linux, and Web using a shared Rust core with platform-native UI frontends.

**Why Rust?**
- 🚀 Blazing fast, memory safe
- 🔗 Best-in-class FFI (Foreign Function Interface) support
- 📦 Compiles to native libraries for any platform
- 🌐 Compiles to WebAssembly for web
- 🏢 Used by: 1Password, Figma, Discord, Dropbox

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    mira-core (Rust)                         │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │    Models    │  │   Services   │  │  PDF Engine  │       │
│  │              │  │              │  │              │       │
│  │ - Invoice    │  │ - DataStore  │  │ - Generator  │       │
│  │ - Client     │  │ - Calculator │  │ - Templates  │       │
│  │ - Company    │  │ - Validator  │  │ - Renderer   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
│  Compiles to:                                                │
│  ├── libmira.dylib  (macOS)                                 │
│  ├── libmira.dll    (Windows)                               │
│  ├── libmira.so     (Linux)                                 │
│  └── mira.wasm      (WebAssembly)                           │
│                                                              │
└─────────────────────────────┬────────────────────────────────┘
                              │
                              │ FFI / Native Bindings
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Mira macOS   │    │ Mira Desktop  │    │   Mira Web    │
│   (SwiftUI)   │    │   (Flutter)   │    │    (React)    │
│               │    │               │    │               │
│ Swift ←→ Rust │    │ Dart ←→ Rust  │    │ JS ←→ WASM   │
│   via C FFI   │    │  via dart:ffi │    │ via wasm-pack │
└───────────────┘    └───────────────┘    └───────────────┘
```

---

## Why Rust Over REST API?

| Aspect | REST API | Rust Core |
|--------|----------|-----------|
| **Performance** | Network overhead | Native speed |
| **Offline** | Needs server running | Works standalone |
| **Distribution** | Ship server + client | Ship single binary |
| **Complexity** | HTTP serialization | Direct function calls |
| **Bundle size** | Server + client code | Just the library |
| **Latency** | ~1-10ms per call | ~0.001ms per call |

---

## Phase 1: Learn Rust Basics (1-2 weeks)

### Step 1.1: Install Rust

```bash
# Install rustup (Rust toolchain manager)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Verify installation
rustc --version
cargo --version
```

### Step 1.2: Learn Rust Fundamentals

**Resources:**
- [The Rust Book](https://doc.rust-lang.org/book/) - Official guide
- [Rust by Example](https://doc.rust-lang.org/rust-by-example/)
- [Rustlings](https://github.com/rust-lang/rustlings) - Small exercises

**Key concepts to understand:**
- Ownership & borrowing
- Structs & enums
- Error handling (Result, Option)
- Traits (like Swift protocols)
- Cargo (package manager)

### Step 1.3: Build a Tiny POC

```rust
// src/lib.rs - Hello World library

#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn greet(name: *const c_char) -> *mut c_char {
    let name = unsafe { CStr::from_ptr(name).to_str().unwrap() };
    let greeting = format!("Hello, {}!", name);
    CString::new(greeting).unwrap().into_raw()
}
```

```swift
// Swift side - call Rust
@_silgen_name("add")
func rustAdd(_ a: Int32, _ b: Int32) -> Int32

let result = rustAdd(2, 3) // Returns 5
```

---

## Phase 2: Build mira-core in Rust (4-6 weeks)

### Step 2.1: Project Structure

```
mira-core/
├── Cargo.toml
├── src/
│   ├── lib.rs              # Library entry point
│   ├── models/
│   │   ├── mod.rs
│   │   ├── invoice.rs
│   │   ├── client.rs
│   │   ├── company.rs
│   │   └── line_item.rs
│   ├── services/
│   │   ├── mod.rs
│   │   ├── data_store.rs
│   │   ├── calculator.rs
│   │   └── validator.rs
│   ├── pdf/
│   │   ├── mod.rs
│   │   ├── generator.rs
│   │   └── templates.rs
│   └── ffi/
│       ├── mod.rs
│       ├── swift.rs        # Swift-specific bindings
│       ├── dart.rs         # Flutter-specific bindings
│       └── wasm.rs         # WebAssembly bindings
├── tests/
└── examples/
```

### Step 2.2: Cargo.toml Configuration

```toml
[package]
name = "mira-core"
version = "0.1.0"
edition = "2021"

[lib]
name = "mira"
crate-type = ["cdylib", "staticlib"]  # Dynamic + static library

[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }
thiserror = "1.0"           # Error handling
printpdf = "0.6"            # PDF generation
rust_decimal = "1.0"        # Precise money calculations

[target.'cfg(target_arch = "wasm32")'.dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"
web-sys = "0.3"

[build-dependencies]
cbindgen = "0.24"           # Generate C headers for FFI
```

### Step 2.3: Define Core Models

```rust
// src/models/invoice.rs

use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Invoice {
    pub id: Uuid,
    pub number: String,
    pub client_id: Uuid,
    pub date: DateTime<Utc>,
    pub due_date: DateTime<Utc>,
    pub line_items: Vec<LineItem>,
    pub status: InvoiceStatus,
    pub notes: Option<String>,
    pub currency: Currency,
    pub vat_rate: Decimal,
    pub is_vat_exempt: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LineItem {
    pub id: Uuid,
    pub description: String,
    pub quantity: Decimal,
    pub unit_price: Decimal,
    pub vat_rate: Decimal,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum InvoiceStatus {
    Draft,
    Sent,
    Paid,
    Overdue,
    Cancelled,
}

impl Invoice {
    pub fn subtotal(&self) -> Decimal {
        self.line_items.iter()
            .map(|item| item.quantity * item.unit_price)
            .sum()
    }
    
    pub fn vat_amount(&self) -> Decimal {
        if self.is_vat_exempt {
            Decimal::ZERO
        } else {
            self.subtotal() * self.vat_rate / Decimal::from(100)
        }
    }
    
    pub fn total(&self) -> Decimal {
        self.subtotal() + self.vat_amount()
    }
}
```

### Step 2.4: Implement Data Store

```rust
// src/services/data_store.rs

use crate::models::*;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use uuid::Uuid;

pub struct DataStore {
    data_dir: PathBuf,
    invoices: HashMap<Uuid, Invoice>,
    clients: HashMap<Uuid, Client>,
    company: Option<CompanyProfile>,
}

impl DataStore {
    pub fn new(data_dir: PathBuf) -> Result<Self, DataStoreError> {
        fs::create_dir_all(&data_dir)?;
        
        let mut store = Self {
            data_dir,
            invoices: HashMap::new(),
            clients: HashMap::new(),
            company: None,
        };
        
        store.load_all()?;
        Ok(store)
    }
    
    pub fn get_invoices(&self) -> Vec<&Invoice> {
        self.invoices.values().collect()
    }
    
    pub fn get_invoice(&self, id: Uuid) -> Option<&Invoice> {
        self.invoices.get(&id)
    }
    
    pub fn create_invoice(&mut self, invoice: Invoice) -> Result<&Invoice, DataStoreError> {
        let id = invoice.id;
        self.invoices.insert(id, invoice);
        self.save_invoices()?;
        Ok(self.invoices.get(&id).unwrap())
    }
    
    pub fn update_invoice(&mut self, invoice: Invoice) -> Result<&Invoice, DataStoreError> {
        let id = invoice.id;
        self.invoices.insert(id, invoice);
        self.save_invoices()?;
        Ok(self.invoices.get(&id).unwrap())
    }
    
    pub fn delete_invoice(&mut self, id: Uuid) -> Result<(), DataStoreError> {
        self.invoices.remove(&id);
        self.save_invoices()?;
        Ok(())
    }
    
    fn save_invoices(&self) -> Result<(), DataStoreError> {
        let path = self.data_dir.join("invoices.json");
        let data = serde_json::to_string_pretty(&self.invoices)?;
        fs::write(path, data)?;
        Ok(())
    }
    
    fn load_all(&mut self) -> Result<(), DataStoreError> {
        // Load invoices
        let invoices_path = self.data_dir.join("invoices.json");
        if invoices_path.exists() {
            let data = fs::read_to_string(invoices_path)?;
            self.invoices = serde_json::from_str(&data)?;
        }
        
        // Load clients, company, etc.
        // ...
        
        Ok(())
    }
}
```

### Step 2.5: PDF Generation

```rust
// src/pdf/generator.rs

use crate::models::*;
use printpdf::*;
use std::io::BufWriter;

pub struct PdfGenerator {
    template: PdfTemplate,
}

impl PdfGenerator {
    pub fn new(template: PdfTemplate) -> Self {
        Self { template }
    }
    
    pub fn generate(&self, invoice: &Invoice, company: &CompanyProfile, client: &Client) -> Result<Vec<u8>, PdfError> {
        let (doc, page1, layer1) = PdfDocument::new(
            &format!("Invoice {}", invoice.number),
            Mm(210.0),  // A4 width
            Mm(297.0),  // A4 height
            "Layer 1"
        );
        
        let layer = doc.get_page(page1).get_layer(layer1);
        
        // Render header
        self.render_header(&layer, company);
        
        // Render client info
        self.render_client(&layer, client);
        
        // Render invoice details
        self.render_invoice_details(&layer, invoice);
        
        // Render line items table
        self.render_line_items(&layer, &invoice.line_items);
        
        // Render totals
        self.render_totals(&layer, invoice);
        
        // Render footer
        self.render_footer(&layer, company);
        
        // Save to bytes
        let mut buffer = BufWriter::new(Vec::new());
        doc.save(&mut buffer)?;
        
        Ok(buffer.into_inner()?)
    }
    
    fn render_header(&self, layer: &PdfLayerReference, company: &CompanyProfile) {
        // Add company logo, name, address
        // ...
    }
    
    fn render_line_items(&self, layer: &PdfLayerReference, items: &[LineItem]) {
        // Render table with columns: Description, Qty, Price, Total
        // ...
    }
    
    // ... more render methods
}
```

---

## Phase 3: FFI Bindings (2-3 weeks)

### Step 3.1: C-Compatible Interface

```rust
// src/ffi/mod.rs

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// Initialize the Mira core with a data directory path
#[no_mangle]
pub extern "C" fn mira_init(data_dir: *const c_char) -> *mut MiraCore {
    let data_dir = unsafe { CStr::from_ptr(data_dir).to_str().unwrap() };
    let core = MiraCore::new(data_dir.into()).unwrap();
    Box::into_raw(Box::new(core))
}

/// Free the Mira core instance
#[no_mangle]
pub extern "C" fn mira_free(core: *mut MiraCore) {
    if !core.is_null() {
        unsafe { drop(Box::from_raw(core)) };
    }
}

/// Get all invoices as JSON string
#[no_mangle]
pub extern "C" fn mira_get_invoices(core: *const MiraCore) -> *mut c_char {
    let core = unsafe { &*core };
    let invoices = core.get_invoices();
    let json = serde_json::to_string(&invoices).unwrap();
    CString::new(json).unwrap().into_raw()
}

/// Free a string returned by Mira
#[no_mangle]
pub extern "C" fn mira_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { drop(CString::from_raw(s)) };
    }
}

/// Create an invoice from JSON, returns new invoice JSON
#[no_mangle]
pub extern "C" fn mira_create_invoice(core: *mut MiraCore, json: *const c_char) -> *mut c_char {
    let core = unsafe { &mut *core };
    let json_str = unsafe { CStr::from_ptr(json).to_str().unwrap() };
    
    let invoice: Invoice = serde_json::from_str(json_str).unwrap();
    let created = core.create_invoice(invoice).unwrap();
    
    let result = serde_json::to_string(created).unwrap();
    CString::new(result).unwrap().into_raw()
}

/// Generate PDF for invoice, returns bytes
#[no_mangle]
pub extern "C" fn mira_generate_pdf(
    core: *const MiraCore,
    invoice_id: *const c_char,
    out_len: *mut usize,
) -> *mut u8 {
    let core = unsafe { &*core };
    let id_str = unsafe { CStr::from_ptr(invoice_id).to_str().unwrap() };
    let id: Uuid = id_str.parse().unwrap();
    
    let pdf_data = core.generate_pdf(id).unwrap();
    
    unsafe { *out_len = pdf_data.len() };
    
    let mut boxed = pdf_data.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}

/// Free PDF bytes
#[no_mangle]
pub extern "C" fn mira_free_bytes(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        unsafe {
            drop(Vec::from_raw_parts(ptr, len, len));
        }
    }
}
```

### Step 3.2: Generate C Header with cbindgen

```rust
// build.rs

fn main() {
    let crate_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    
    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_language(cbindgen::Language::C)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("include/mira.h");
}
```

Generated header:
```c
// include/mira.h

#ifndef MIRA_H
#define MIRA_H

#include <stdint.h>
#include <stdbool.h>

typedef struct MiraCore MiraCore;

MiraCore* mira_init(const char* data_dir);
void mira_free(MiraCore* core);

char* mira_get_invoices(const MiraCore* core);
char* mira_create_invoice(MiraCore* core, const char* json);
char* mira_update_invoice(MiraCore* core, const char* json);
bool mira_delete_invoice(MiraCore* core, const char* id);

uint8_t* mira_generate_pdf(const MiraCore* core, const char* invoice_id, size_t* out_len);

void mira_free_string(char* s);
void mira_free_bytes(uint8_t* ptr, size_t len);

#endif
```

### Step 3.3: Build for All Platforms

```bash
# Add target platforms
rustup target add x86_64-apple-darwin      # macOS Intel
rustup target add aarch64-apple-darwin     # macOS Apple Silicon
rustup target add x86_64-pc-windows-msvc   # Windows
rustup target add x86_64-unknown-linux-gnu # Linux
rustup target add wasm32-unknown-unknown   # WebAssembly

# Build for macOS (universal)
cargo build --release --target x86_64-apple-darwin
cargo build --release --target aarch64-apple-darwin
lipo -create \
  target/x86_64-apple-darwin/release/libmira.dylib \
  target/aarch64-apple-darwin/release/libmira.dylib \
  -output libmira.dylib

# Build for Windows
cargo build --release --target x86_64-pc-windows-msvc

# Build for Linux
cargo build --release --target x86_64-unknown-linux-gnu

# Build for WebAssembly
wasm-pack build --target web
```

---

## Phase 4: Swift Integration (1-2 weeks)

### Step 4.1: Create Swift Package Wrapper

```swift
// Sources/MiraCore/MiraCore.swift

import Foundation

public class MiraCore {
    private var handle: OpaquePointer?
    
    public init(dataDirectory: URL) throws {
        let path = dataDirectory.path
        handle = mira_init(path)
        guard handle != nil else {
            throw MiraError.initializationFailed
        }
    }
    
    deinit {
        if let handle = handle {
            mira_free(handle)
        }
    }
    
    public func getInvoices() -> [Invoice] {
        guard let handle = handle else { return [] }
        
        let jsonPtr = mira_get_invoices(handle)
        defer { mira_free_string(jsonPtr) }
        
        guard let jsonPtr = jsonPtr else { return [] }
        let json = String(cString: jsonPtr)
        
        return try! JSONDecoder().decode([Invoice].self, from: json.data(using: .utf8)!)
    }
    
    public func createInvoice(_ invoice: Invoice) throws -> Invoice {
        guard let handle = handle else {
            throw MiraError.notInitialized
        }
        
        let json = try JSONEncoder().encode(invoice)
        let jsonString = String(data: json, encoding: .utf8)!
        
        let resultPtr = mira_create_invoice(handle, jsonString)
        defer { mira_free_string(resultPtr) }
        
        guard let resultPtr = resultPtr else {
            throw MiraError.operationFailed
        }
        
        let resultJson = String(cString: resultPtr)
        return try JSONDecoder().decode(Invoice.self, from: resultJson.data(using: .utf8)!)
    }
    
    public func generatePDF(invoiceId: UUID) throws -> Data {
        guard let handle = handle else {
            throw MiraError.notInitialized
        }
        
        var length: Int = 0
        let bytesPtr = mira_generate_pdf(handle, invoiceId.uuidString, &length)
        defer { mira_free_bytes(bytesPtr, length) }
        
        guard let bytesPtr = bytesPtr else {
            throw MiraError.pdfGenerationFailed
        }
        
        return Data(bytes: bytesPtr, count: length)
    }
}
```

### Step 4.2: XCFramework for Distribution

```bash
# Create XCFramework containing all Apple platforms
xcodebuild -create-xcframework \
  -library target/aarch64-apple-darwin/release/libmira.a \
  -headers include/ \
  -library target/x86_64-apple-darwin/release/libmira.a \
  -headers include/ \
  -output MiraCore.xcframework
```

---

## Phase 5: Flutter Integration (2-3 weeks)

### Step 5.1: Dart FFI Bindings

```dart
// lib/src/ffi/mira_bindings.dart

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef MiraInitNative = Pointer<Void> Function(Pointer<Utf8> dataDir);
typedef MiraInit = Pointer<Void> Function(Pointer<Utf8> dataDir);

typedef MiraGetInvoicesNative = Pointer<Utf8> Function(Pointer<Void> core);
typedef MiraGetInvoices = Pointer<Utf8> Function(Pointer<Void> core);

class MiraBindings {
  late final DynamicLibrary _lib;
  
  late final MiraInit miraInit;
  late final MiraGetInvoices miraGetInvoices;
  // ... more bindings
  
  MiraBindings() {
    _lib = _loadLibrary();
    
    miraInit = _lib
        .lookup<NativeFunction<MiraInitNative>>('mira_init')
        .asFunction();
    
    miraGetInvoices = _lib
        .lookup<NativeFunction<MiraGetInvoicesNative>>('mira_get_invoices')
        .asFunction();
  }
  
  DynamicLibrary _loadLibrary() {
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libmira.dylib');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('mira.dll');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libmira.so');
    }
    throw UnsupportedError('Unsupported platform');
  }
}
```

### Step 5.2: Dart Wrapper Class

```dart
// lib/src/mira_core.dart

import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'ffi/mira_bindings.dart';
import 'models/invoice.dart';

class MiraCore {
  final MiraBindings _bindings;
  late final Pointer<Void> _handle;
  
  MiraCore(String dataDir) : _bindings = MiraBindings() {
    final dataDirPtr = dataDir.toNativeUtf8();
    _handle = _bindings.miraInit(dataDirPtr);
    calloc.free(dataDirPtr);
  }
  
  List<Invoice> getInvoices() {
    final jsonPtr = _bindings.miraGetInvoices(_handle);
    final json = jsonPtr.toDartString();
    _bindings.miraFreeString(jsonPtr);
    
    final List<dynamic> data = jsonDecode(json);
    return data.map((e) => Invoice.fromJson(e)).toList();
  }
  
  Invoice createInvoice(Invoice invoice) {
    final jsonStr = jsonEncode(invoice.toJson());
    final jsonPtr = jsonStr.toNativeUtf8();
    
    final resultPtr = _bindings.miraCreateInvoice(_handle, jsonPtr);
    calloc.free(jsonPtr);
    
    final resultJson = resultPtr.toDartString();
    _bindings.miraFreeString(resultPtr);
    
    return Invoice.fromJson(jsonDecode(resultJson));
  }
}
```

---

## Phase 6: WebAssembly (2-3 weeks)

### Step 6.1: WASM-Specific Bindings

```rust
// src/ffi/wasm.rs

use wasm_bindgen::prelude::*;
use crate::MiraCore;

#[wasm_bindgen]
pub struct WasmMiraCore {
    inner: MiraCore,
}

#[wasm_bindgen]
impl WasmMiraCore {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Result<WasmMiraCore, JsValue> {
        // Use IndexedDB or localStorage for persistence in browser
        let core = MiraCore::new_with_web_storage()
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        Ok(Self { inner: core })
    }
    
    #[wasm_bindgen]
    pub fn get_invoices(&self) -> String {
        serde_json::to_string(&self.inner.get_invoices()).unwrap()
    }
    
    #[wasm_bindgen]
    pub fn create_invoice(&mut self, json: &str) -> Result<String, JsValue> {
        let invoice: Invoice = serde_json::from_str(json)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        
        let created = self.inner.create_invoice(invoice)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        
        Ok(serde_json::to_string(&created).unwrap())
    }
    
    #[wasm_bindgen]
    pub fn generate_pdf(&self, invoice_id: &str) -> Result<Vec<u8>, JsValue> {
        let id: Uuid = invoice_id.parse()
            .map_err(|e| JsValue::from_str(&format!("Invalid UUID: {}", e)))?;
        
        self.inner.generate_pdf(id)
            .map_err(|e| JsValue::from_str(&e.to_string()))
    }
}
```

### Step 6.2: JavaScript/TypeScript Usage

```typescript
// src/lib/mira.ts

import init, { WasmMiraCore } from 'mira-core';

let core: WasmMiraCore | null = null;

export async function initMira(): Promise<void> {
  await init();
  core = new WasmMiraCore();
}

export function getInvoices(): Invoice[] {
  if (!core) throw new Error('Mira not initialized');
  return JSON.parse(core.get_invoices());
}

export function createInvoice(invoice: Partial<Invoice>): Invoice {
  if (!core) throw new Error('Mira not initialized');
  return JSON.parse(core.create_invoice(JSON.stringify(invoice)));
}

export function generatePdf(invoiceId: string): Uint8Array {
  if (!core) throw new Error('Mira not initialized');
  return core.generate_pdf(invoiceId);
}
```

---

## Summary: Platform Build Matrix

| Platform | UI Framework | Rust Target | Library Format |
|----------|--------------|-------------|----------------|
| macOS | SwiftUI | `aarch64-apple-darwin` | `.dylib` / `.xcframework` |
| Windows | Flutter | `x86_64-pc-windows-msvc` | `.dll` |
| Linux | Flutter | `x86_64-unknown-linux-gnu` | `.so` |
| Web | React/Vue | `wasm32-unknown-unknown` | `.wasm` |
| iOS | SwiftUI | `aarch64-apple-ios` | `.a` (static) |
| Android | Flutter | `aarch64-linux-android` | `.so` |

---

## Estimated Timeline

| Phase | Duration | Result |
|-------|----------|--------|
| Learn Rust | 1-2 weeks | Basic Rust proficiency |
| Build mira-core | 4-6 weeks | Full Rust core library |
| FFI Bindings | 2-3 weeks | C-compatible interface |
| Swift Integration | 1-2 weeks | SwiftUI app works |
| Flutter Integration | 2-3 weeks | Windows/Linux apps |
| WebAssembly | 2-3 weeks | Web app works |
| **Total** | **12-19 weeks** | **All platforms** |

---

## Advantages of This Approach

1. **Single source of truth** - All business logic in Rust
2. **Native performance** - No interpreter overhead
3. **Type safety** - Rust's compiler catches bugs early
4. **Memory safety** - No crashes from memory issues
5. **Easy distribution** - Single library per platform
6. **Future-proof** - Rust has 6-week release cycle, great tooling

## Challenges

1. **Learning curve** - Rust is different from Swift
2. **FFI complexity** - Memory management across boundaries
3. **Build pipeline** - Cross-compilation setup
4. **Debugging** - Harder to debug across FFI boundary

---

## Next Steps

1. **Week 1-2:** Learn Rust basics, complete Rustlings exercises
2. **Week 3:** Build simple FFI POC (add numbers, return strings)
3. **Week 4:** Port one model (Invoice) to Rust
4. **Week 5+:** Incrementally port more functionality

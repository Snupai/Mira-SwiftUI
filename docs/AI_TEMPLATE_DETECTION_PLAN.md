# AI Invoice Template Detection - Implementation Plan

## Overview

**Goal:** Allow users to upload an existing invoice (PDF/Word/image) and have Mira automatically detect the layout, styling, and field positions to create a matching template for future invoices.

**User Flow:**
1. User chooses "Import Existing Invoice" during onboarding
2. Uploads a PDF/Word/image of their current invoice design
3. Mira analyzes it and shows detected regions
4. User confirms/adjusts detection
5. Mira generates a template that matches the style
6. All future invoices use this template

---

## Phase 1: Research & Proof of Concept (1-2 weeks)

### Step 1.1: Choose AI/ML Approach

**Option A: Apple Vision Framework (Local, Free)**
- Built into macOS - no API costs
- `VNRecognizeTextRequest` for OCR
- `VNDetectRectanglesRequest` for layout detection
- `VNDetectContoursRequest` for shape detection
- ✅ Pros: Free, private, works offline
- ⚠️ Cons: Less smart, need manual region classification

**Option B: OpenAI GPT-4 Vision (Cloud, Paid)**
- Send invoice image → get structured JSON back
- "Analyze this invoice, detect regions, return coordinates"
- ✅ Pros: Very smart, understands context
- ⚠️ Cons: API costs, requires internet, privacy concerns

**Option C: Hybrid (Recommended)**
- Use Apple Vision for OCR and basic detection
- Use local ML model for region classification
- Optional: GPT-4 Vision for complex layouts

### Step 1.2: Build Proof of Concept

```swift
// POC: Detect text regions in invoice image
import Vision

func analyzeInvoice(image: CGImage) async -> [DetectedRegion] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    
    let handler = VNImageRequestHandler(cgImage: image)
    try? handler.perform([request])
    
    // Group text into regions (header, line items, footer, etc.)
    return groupTextIntoRegions(request.results)
}
```

### Step 1.3: Define Region Types

```swift
enum InvoiceRegion: String, Codable {
    case logo
    case companyHeader      // Company name, address
    case clientSection      // Bill to / Ship to
    case invoiceMetadata    // Invoice #, date, due date
    case lineItemsTable     // The main items table
    case subtotals          // Subtotal, tax, total
    case paymentInfo        // Bank details, payment terms
    case footer             // Notes, thank you message
}

struct DetectedRegion {
    var type: InvoiceRegion
    var bounds: CGRect       // Position on page (0-1 normalized)
    var confidence: Float
    var extractedText: String?
}
```

---

## Phase 2: Core Detection Engine (2-3 weeks)

### Step 2.1: Document Parsing

**PDF Parsing:**
```swift
import PDFKit

func extractFromPDF(url: URL) -> (image: CGImage, text: [TextBlock]) {
    let document = PDFDocument(url: url)!
    let page = document.page(at: 0)!
    
    // Render to image for vision analysis
    let image = page.thumbnail(of: CGSize(width: 2000, height: 2800), for: .mediaBox)
    
    // Extract text with positions
    let text = page.attributedString?.extractBlocks()
    
    return (image.cgImage!, text)
}
```

**Word (.docx) Parsing:**
- Use `ZIPFoundation` to unzip .docx
- Parse `word/document.xml` for content
- Parse `word/styles.xml` for formatting
- Libraries: `AEXML` or `SWXMLHash`

### Step 2.2: Layout Analysis

```swift
struct LayoutAnalyzer {
    func analyze(image: CGImage, textBlocks: [TextBlock]) -> InvoiceLayout {
        // 1. Detect horizontal lines (table separators)
        let lines = detectLines(in: image)
        
        // 2. Find the line items table
        let table = detectTable(lines: lines, text: textBlocks)
        
        // 3. Classify regions above/below table
        let header = classifyHeader(textBlocks.filter { $0.y < table.top })
        let footer = classifyFooter(textBlocks.filter { $0.y > table.bottom })
        
        // 4. Detect logo (largest image/non-text region in top area)
        let logo = detectLogo(in: image, above: table.top)
        
        return InvoiceLayout(
            logo: logo,
            header: header,
            table: table,
            footer: footer
        )
    }
}
```

### Step 2.3: Style Extraction

```swift
struct StyleExtractor {
    func extract(from textBlocks: [TextBlock]) -> InvoiceStyle {
        // Find most common fonts
        let fonts = textBlocks.map { $0.font }.mostCommon()
        
        // Extract colors
        let colors = textBlocks.map { $0.color }.unique()
        
        // Detect primary/secondary/accent
        return InvoiceStyle(
            primaryFont: fonts.first,
            headingFont: findHeadingFont(textBlocks),
            primaryColor: colors.dominant,
            accentColor: colors.accent
        )
    }
}
```

---

## Phase 3: Template Generation (2-3 weeks)

### Step 3.1: Map Detection to Template

```swift
struct TemplateGenerator {
    func generate(from layout: InvoiceLayout, style: InvoiceStyle) -> PDFTemplate {
        var template = PDFTemplate()
        
        // Map detected regions to template fields
        template.logoPosition = layout.logo?.bounds
        template.headerLayout = mapHeaderFields(layout.header)
        template.tableStyle = mapTableStyle(layout.table)
        template.footerLayout = mapFooterFields(layout.footer)
        
        // Apply extracted styles
        template.fonts = style.fonts
        template.colors = style.colors
        
        return template
    }
}
```

### Step 3.2: Template Storage Format

```json
{
  "name": "Imported Template",
  "version": "1.0",
  "pageSize": { "width": 595, "height": 842 },
  "margins": { "top": 50, "right": 50, "bottom": 50, "left": 50 },
  "regions": [
    {
      "type": "logo",
      "bounds": { "x": 0.05, "y": 0.03, "width": 0.25, "height": 0.08 }
    },
    {
      "type": "companyHeader",
      "bounds": { "x": 0.6, "y": 0.03, "width": 0.35, "height": 0.12 },
      "fields": ["companyName", "street", "city", "country"]
    },
    {
      "type": "lineItemsTable",
      "bounds": { "x": 0.05, "y": 0.35, "width": 0.9, "height": 0.4 },
      "columns": ["description", "quantity", "unitPrice", "total"]
    }
  ],
  "style": {
    "primaryFont": "Helvetica",
    "headingFont": "Helvetica-Bold",
    "fontSize": { "heading": 18, "body": 10, "small": 8 },
    "colors": { "primary": "#333333", "accent": "#2563eb" }
  }
}
```

### Step 3.3: PDF Renderer Updates

Update existing `PDFGenerator` to support template-based rendering:

```swift
class PDFGenerator {
    var template: PDFTemplate?
    
    func generatePDF(invoice: Invoice) -> Data {
        if let template = template {
            return generateFromTemplate(invoice, template)
        } else {
            return generateDefault(invoice)
        }
    }
    
    private func generateFromTemplate(_ invoice: Invoice, _ template: PDFTemplate) -> Data {
        // Render each region at its specified position
        for region in template.regions {
            switch region.type {
            case .logo: renderLogo(at: region.bounds)
            case .companyHeader: renderCompanyHeader(at: region.bounds)
            case .lineItemsTable: renderTable(invoice.lineItems, at: region.bounds)
            // etc.
            }
        }
    }
}
```

---

## Phase 4: User Interface (1-2 weeks)

### Step 4.1: Import Flow

```
┌─────────────────────────────────────────┐
│  Import Your Invoice Design             │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │                                 │   │
│  │     Drop PDF, Word, or image   │   │
│  │         here to upload         │   │
│  │                                 │   │
│  │        📄 Browse Files          │   │
│  │                                 │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Supported: PDF, DOCX, PNG, JPG         │
└─────────────────────────────────────────┘
```

### Step 4.2: Detection Preview

```
┌─────────────────────────────────────────────────────┐
│  We detected these regions:                          │
│                                                      │
│  ┌──────────────────────┐  ┌─────────────────────┐  │
│  │                      │  │ ✓ Logo              │  │
│  │   [Invoice Preview   │  │ ✓ Company Header    │  │
│  │    with colored      │  │ ✓ Client Section    │  │
│  │    region overlays]  │  │ ✓ Invoice Details   │  │
│  │                      │  │ ✓ Line Items Table  │  │
│  │                      │  │ ✓ Totals            │  │
│  │                      │  │ ○ Payment Info      │  │
│  └──────────────────────┘  │ ○ Footer Notes      │  │
│                            └─────────────────────┘  │
│                                                      │
│  ⚠️ We couldn't detect Payment Info.                │
│     [Add Manually]  [Skip]                          │
│                                                      │
│            [Back]              [Use This Template]  │
└─────────────────────────────────────────────────────┘
```

### Step 4.3: Manual Adjustment

Allow users to:
- Drag region boundaries to adjust
- Change region type (misclassified header → footer)
- Add missing regions
- Remove incorrect detections

---

## Phase 5: Polish & Edge Cases (1-2 weeks)

### Edge Cases to Handle

1. **Multi-page invoices** - Only analyze first page for template
2. **Handwritten invoices** - Reject with helpful message
3. **Very simple invoices** - Offer to enhance with more sections
4. **Foreign languages** - Should work, test with German/French
5. **Rotated/skewed scans** - Auto-rotate using Vision
6. **Low quality images** - Warn user, try anyway
7. **Password-protected PDFs** - Ask for password or reject

### Quality Checks

```swift
struct TemplateValidator {
    func validate(_ template: PDFTemplate) -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Must have essential regions
        if !template.hasRegion(.lineItemsTable) {
            issues.append(.critical("No line items table detected"))
        }
        
        // Check for overlapping regions
        if template.hasOverlappingRegions() {
            issues.append(.warning("Some regions overlap"))
        }
        
        // Check confidence scores
        for region in template.regions where region.confidence < 0.7 {
            issues.append(.warning("Low confidence for \(region.type)"))
        }
        
        return ValidationResult(issues: issues)
    }
}
```

---

## Tech Stack Summary

| Component | Technology | Notes |
|-----------|------------|-------|
| OCR | Apple Vision | Free, local, good accuracy |
| Layout Detection | Apple Vision + custom ML | CoreML model for classification |
| PDF Parsing | PDFKit | Built into macOS |
| Word Parsing | ZIPFoundation + AEXML | Parse .docx XML |
| Image Processing | Core Image | Preprocessing, rotation |
| ML Classification | CreateML / CoreML | Train region classifier |
| Optional AI | OpenAI Vision API | For complex layouts |

---

## MVP vs Full Version

### MVP (v1)
- [x] PDF upload only
- [x] Basic region detection (header, table, footer)
- [x] Style extraction (fonts, colors)
- [x] Generate similar-looking template
- [ ] Manual adjustment UI

### Full Version (v2)
- [ ] Word/Google Docs support
- [ ] Advanced region detection (all types)
- [ ] Logo extraction and reuse
- [ ] Multi-page analysis
- [ ] Template fine-tuning editor
- [ ] Template sharing/export

---

## Estimated Timeline

| Phase | Duration | Milestone |
|-------|----------|-----------|
| Phase 1: Research | 1-2 weeks | Working POC with Vision |
| Phase 2: Detection | 2-3 weeks | Accurate region detection |
| Phase 3: Generation | 2-3 weeks | Template-based PDF output |
| Phase 4: UI | 1-2 weeks | Full import flow |
| Phase 5: Polish | 1-2 weeks | Production ready |
| **Total** | **7-12 weeks** | **Feature complete** |

---

## Next Steps

1. **Start with POC** - Test Apple Vision on sample invoices
2. **Collect samples** - Get 10-20 different invoice designs to test
3. **Build region classifier** - Train CoreML model on labeled regions
4. **Iterate** - Test, fix edge cases, improve accuracy

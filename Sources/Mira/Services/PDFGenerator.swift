import SwiftUI
#if os(macOS)
import AppKit
import PDFKit

enum PDFLanguage: String, CaseIterable {
    case german = "Deutsch"
    case english = "English"
}

struct PDFStrings {
    let invoice: String
    let invoiceDate: String
    let invoiceNumber: String
    let dueDate: String
    let to: String
    let description: String
    let quantity: String
    let unitPrice: String
    let vat: String
    let total: String
    let subtotal: String
    let totalAmount: String
    let bankDetails: String
    let accountHolder: String
    let bank: String
    let reference: String
    let vatExemptNotice: String
    let vatId: String
    let taxNumber: String
    
    static let german = PDFStrings(
        invoice: "Rechnung",
        invoiceDate: "Rechnungsdatum:",
        invoiceNumber: "Rechnungsnummer:",
        dueDate: "Fällig bis:",
        to: "An:",
        description: "Beschreibung",
        quantity: "Menge",
        unitPrice: "Einzelpreis",
        vat: "MwSt.",
        total: "Gesamt",
        subtotal: "Zwischensumme",
        totalAmount: "Gesamtbetrag",
        bankDetails: "Bankverbindung",
        accountHolder: "Kontoinhaber:",
        bank: "Bank:",
        reference: "Verwendungszweck:",
        vatExemptNotice: "Gemäß §19 UStG wird keine Umsatzsteuer berechnet.",
        vatId: "USt-IdNr.:",
        taxNumber: "Steuernr.:"
    )
    
    static let english = PDFStrings(
        invoice: "Invoice",
        invoiceDate: "Invoice Date:",
        invoiceNumber: "Invoice Number:",
        dueDate: "Due Date:",
        to: "To:",
        description: "Description",
        quantity: "Qty",
        unitPrice: "Unit Price",
        vat: "VAT",
        total: "Total",
        subtotal: "Subtotal",
        totalAmount: "Total Amount",
        bankDetails: "Bank Details",
        accountHolder: "Account Holder:",
        bank: "Bank:",
        reference: "Reference:",
        vatExemptNotice: "VAT exempt according to §19 UStG (small business regulation).",
        vatId: "VAT ID:",
        taxNumber: "Tax No.:"
    )
    
    static func forLanguage(_ lang: PDFLanguage) -> PDFStrings {
        switch lang {
        case .german: return .german
        case .english: return .english
        }
    }
}

class PDFGenerator {
    
    static func generateInvoicePDF(
        invoice: Invoice,
        client: Client,
        companyProfile: CompanyProfile,
        language: PDFLanguage = .german
    ) -> Data? {
        let strings = PDFStrings.forLanguage(language)
        let pdfWidth: CGFloat = 595.28  // A4
        let pdfHeight: CGFloat = 841.89
        let margin: CGFloat = 50
        
        let pdfData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }
        
        var mediaBox = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
        
        guard let cgContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        
        // Start PDF page
        cgContext.beginPDFPage(nil)
        
        // Create NSGraphicsContext for proper text rendering
        let nsContext = NSGraphicsContext(cgContext: cgContext, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        
        // Apply flip transform for top-left origin
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: pdfHeight)
        transform.scaleX(by: 1, yBy: -1)
        transform.concat()
        
        let brandColor = NSColor(companyProfile.brandColor)
        var yPosition: CGFloat = margin
        
        // Currency formatter
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = invoice.currency.rawValue
        currencyFormatter.locale = Locale(identifier: "de_DE")
        
        // Date formatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        
        // === HEADER ===
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 22),
            .foregroundColor: brandColor
        ]
        let title = companyProfile.companyName
        title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttrs)
        
        let invoiceLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 22),
            .foregroundColor: NSColor.black
        ]
        let titleWidth = title.size(withAttributes: titleAttrs).width
        " – \(strings.invoice)".draw(at: CGPoint(x: margin + titleWidth, y: yPosition), withAttributes: invoiceLabelAttrs)
        
        // Logo
        if let logoData = companyProfile.logoData, let logoImage = NSImage(data: logoData) {
            let logoMaxHeight: CGFloat = 50
            let logoMaxWidth: CGFloat = 120
            let logoAspect = logoImage.size.width / max(logoImage.size.height, 1)
            var logoWidth = logoMaxWidth
            var logoHeight = logoWidth / max(logoAspect, 0.1)
            if logoHeight > logoMaxHeight {
                logoHeight = logoMaxHeight
                logoWidth = logoHeight * logoAspect
            }
            let logoRect = CGRect(x: pdfWidth - margin - logoWidth, y: yPosition, width: logoWidth, height: logoHeight)
            logoImage.draw(in: logoRect)
        }
        
        yPosition += 45
        
        // === SENDER INFO ===
        let smallFont = NSFont.systemFont(ofSize: 9)
        let normalFont = NSFont.systemFont(ofSize: 10)
        let grayColor = NSColor.darkGray
        
        let normalAttrs: [NSAttributedString.Key: Any] = [.font: normalFont, .foregroundColor: NSColor.black]
        let grayAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: grayColor]
        
        let fromLines = [
            companyProfile.ownerName.isEmpty ? companyProfile.companyName : companyProfile.ownerName,
            companyProfile.street,
            "\(companyProfile.postalCode) \(companyProfile.city)",
            companyProfile.email,
            companyProfile.phone
        ].filter { !$0.isEmpty }
        
        for line in fromLines {
            line.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: normalAttrs)
            yPosition += 14
        }
        
        yPosition += 10
        
        // === RECIPIENT ===
        strings.to.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 10), .foregroundColor: NSColor.black])
        yPosition += 16
        
        let toLines = [
            client.name,
            client.contactPerson,
            client.street,
            "\(client.postalCode) \(client.city)"
        ].filter { !$0.isEmpty }
        
        for line in toLines {
            line.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: normalAttrs)
            yPosition += 14
        }
        
        // === INVOICE META (right side) ===
        let metaX: CGFloat = pdfWidth - margin - 180
        var metaY: CGFloat = 100
        
        let metaItems = [
            (strings.invoiceDate, dateFormatter.string(from: invoice.issueDate)),
            (strings.invoiceNumber, invoice.invoiceNumber),
            (strings.dueDate, dateFormatter.string(from: invoice.dueDate))
        ]
        
        for (label, value) in metaItems {
            label.draw(at: CGPoint(x: metaX, y: metaY), withAttributes: grayAttrs)
            let boldAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: NSColor.black]
            value.draw(at: CGPoint(x: metaX + 95, y: metaY), withAttributes: boldAttrs)
            metaY += 14
        }
        
        yPosition = max(yPosition + 20, 200)
        
        // === LINE ITEMS TABLE ===
        let tableX = margin
        let tableWidth = pdfWidth - 2 * margin
        let colWidths: [CGFloat] = [tableWidth * 0.42, tableWidth * 0.12, tableWidth * 0.16, tableWidth * 0.12, tableWidth * 0.18]
        
        // Table header
        let headerHeight: CGFloat = 24
        let headerRect = NSRect(x: tableX, y: yPosition, width: tableWidth, height: headerHeight)
        brandColor.setFill()
        NSBezierPath(rect: headerRect).fill()
        
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 9), .foregroundColor: NSColor.white]
        let headers = [strings.description, strings.quantity, strings.unitPrice, strings.vat, strings.total]
        var colX = tableX + 6
        for (i, header) in headers.enumerated() {
            header.draw(at: CGPoint(x: colX, y: yPosition + 6), withAttributes: headerAttrs)
            colX += colWidths[i]
        }
        
        yPosition += headerHeight
        
        // Table rows
        let rowAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.black]
        
        for (index, item) in invoice.lineItems.enumerated() {
            let rowHeight: CGFloat = 28
            let bgColor = index % 2 == 0 ? NSColor.white : NSColor(white: 0.97, alpha: 1)
            let rowRect = NSRect(x: tableX, y: yPosition, width: tableWidth, height: rowHeight)
            bgColor.setFill()
            NSBezierPath(rect: rowRect).fill()
            
            colX = tableX + 6
            let vatRate = companyProfile.isVatExempt ? 0.0 : item.vatRate
            let itemTotal = item.quantity * item.unitPrice
            let rowData = [
                item.description,
                "\(formatQty(item.quantity)) \(item.unit)",
                currencyFormatter.string(from: NSNumber(value: item.unitPrice)) ?? "",
                "\(Int(vatRate))%",
                currencyFormatter.string(from: NSNumber(value: itemTotal)) ?? ""
            ]
            
            for (i, text) in rowData.enumerated() {
                text.draw(at: CGPoint(x: colX, y: yPosition + 8), withAttributes: rowAttrs)
                colX += colWidths[i]
            }
            
            yPosition += rowHeight
        }
        
        // Table border
        NSColor.lightGray.setStroke()
        let tablePath = NSBezierPath(rect: NSRect(x: tableX, y: yPosition - CGFloat(invoice.lineItems.count) * 28 - headerHeight, width: tableWidth, height: CGFloat(invoice.lineItems.count) * 28 + headerHeight))
        tablePath.lineWidth = 0.5
        tablePath.stroke()
        
        yPosition += 16
        
        // === TOTALS ===
        let totalsX = pdfWidth - margin - 180
        
        let subtotalLabel = strings.subtotal
        let subtotalValue = currencyFormatter.string(from: NSNumber(value: invoice.subtotal)) ?? ""
        subtotalLabel.draw(at: CGPoint(x: totalsX, y: yPosition), withAttributes: grayAttrs)
        subtotalValue.draw(at: CGPoint(x: totalsX + 100, y: yPosition), withAttributes: rowAttrs)
        yPosition += 16
        
        // VAT breakdown (only if not exempt)
        if !companyProfile.isVatExempt {
            for breakdown in invoice.taxBreakdown {
                let taxLabel = "\(strings.vat) \(Int(breakdown.rate))%"
                let taxValue = currencyFormatter.string(from: NSNumber(value: breakdown.amount)) ?? ""
                taxLabel.draw(at: CGPoint(x: totalsX, y: yPosition), withAttributes: grayAttrs)
                taxValue.draw(at: CGPoint(x: totalsX + 100, y: yPosition), withAttributes: rowAttrs)
                yPosition += 16
            }
        }
        
        // Total line
        brandColor.setStroke()
        let linePath = NSBezierPath()
        linePath.move(to: CGPoint(x: totalsX, y: yPosition + 2))
        linePath.line(to: CGPoint(x: pdfWidth - margin, y: yPosition + 2))
        linePath.lineWidth = 2
        linePath.stroke()
        yPosition += 8
        
        let totalAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.black]
        let totalColorAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: brandColor]
        strings.totalAmount.draw(at: CGPoint(x: totalsX, y: yPosition), withAttributes: totalAttrs)
        let displayTotal = companyProfile.isVatExempt ? invoice.subtotal : invoice.total
        let totalValue = currencyFormatter.string(from: NSNumber(value: displayTotal)) ?? ""
        totalValue.draw(at: CGPoint(x: totalsX + 100, y: yPosition), withAttributes: totalColorAttrs)
        
        // === FOOTER (fixed at bottom) ===
        let footerY = pdfHeight - margin - 15
        
        // === BANK DETAILS BOX (fixed above footer) ===
        let bankBoxHeight: CGFloat = 70
        let bankBoxY = footerY - 30 - bankBoxHeight
        let bankRect = NSRect(x: margin, y: bankBoxY, width: tableWidth, height: bankBoxHeight)
        NSColor(white: 0.96, alpha: 1).setFill()
        NSBezierPath(rect: bankRect).fill()
        
        let bankTitleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 10), .foregroundColor: NSColor.black]
        strings.bankDetails.draw(at: CGPoint(x: margin + 12, y: bankBoxY + 10), withAttributes: bankTitleAttrs)
        
        let bankY = bankBoxY + 30
        let bankCol1X = margin + 12
        let bankCol2X = margin + 230
        
        let bankData = [
            (strings.accountHolder, companyProfile.accountHolder.isEmpty ? companyProfile.companyName : companyProfile.accountHolder),
            ("IBAN:", companyProfile.iban)
        ]
        let bankData2 = [
            (strings.bank, companyProfile.bankName),
            ("BIC:", companyProfile.bic)
        ]
        
        let bankLabelAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8), .foregroundColor: grayColor]
        let bankValueAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8, weight: .medium), .foregroundColor: NSColor.black]
        
        var by = bankY
        for (label, value) in bankData {
            label.draw(at: CGPoint(x: bankCol1X, y: by), withAttributes: bankLabelAttrs)
            value.draw(at: CGPoint(x: bankCol1X + 70, y: by), withAttributes: bankValueAttrs)
            by += 14
        }
        
        by = bankY
        for (label, value) in bankData2 {
            label.draw(at: CGPoint(x: bankCol2X, y: by), withAttributes: bankLabelAttrs)
            value.draw(at: CGPoint(x: bankCol2X + 40, y: by), withAttributes: bankValueAttrs)
            by += 14
        }
        
        // === VAT EXEMPTION NOTICE (right above bank box) ===
        if companyProfile.isVatExempt {
            let exemptY = bankBoxY - 20
            let exemptAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.darkGray]
            strings.vatExemptNotice.draw(at: CGPoint(x: margin, y: exemptY), withAttributes: exemptAttrs)
        }
        
        // === FOOTER LINE ===
        NSColor.lightGray.setStroke()
        let footerLine = NSBezierPath()
        footerLine.move(to: CGPoint(x: margin, y: footerY - 8))
        footerLine.line(to: CGPoint(x: pdfWidth - margin, y: footerY - 8))
        footerLine.lineWidth = 0.5
        footerLine.stroke()
        
        var footerParts = [companyProfile.companyName]
        if !companyProfile.isVatExempt && !companyProfile.vatId.isEmpty { footerParts.append("\(strings.vatId) \(companyProfile.vatId)") }
        if !companyProfile.taxNumber.isEmpty { footerParts.append("\(strings.taxNumber) \(companyProfile.taxNumber)") }
        
        let footerText = footerParts.joined(separator: " · ")
        let footerAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 7), .foregroundColor: NSColor.gray]
        let footerSize = footerText.size(withAttributes: footerAttrs)
        footerText.draw(at: CGPoint(x: (pdfWidth - footerSize.width) / 2, y: footerY), withAttributes: footerAttrs)
        
        // Restore graphics state and end PDF
        NSGraphicsContext.restoreGraphicsState()
        cgContext.endPDFPage()
        cgContext.closePDF()
        
        return pdfData as Data
    }
    
    private static func formatQty(_ q: Double) -> String {
        q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(format: "%.2f", q)
    }
    
    static func saveInvoicePDF(invoice: Invoice, client: Client, companyProfile: CompanyProfile, to url: URL, language: PDFLanguage = .german) -> Bool {
        guard let data = generateInvoicePDF(invoice: invoice, client: client, companyProfile: companyProfile, language: language) else {
            return false
        }
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Error saving PDF: \(error)")
            return false
        }
    }
}
#endif

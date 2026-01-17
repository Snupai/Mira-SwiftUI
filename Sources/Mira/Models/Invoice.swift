import Foundation

struct Invoice: Codable, Identifiable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sentAt: Date?
    var paidAt: Date?
    
    // Invoice Details
    var invoiceNumber: String = ""
    var clientId: UUID
    var status: InvoiceStatus = .draft
    
    // Dates
    var issueDate: Date = Date()
    var dueDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    var serviceDate: Date?
    var serviceDateEnd: Date?
    
    // Line Items
    var lineItems: [LineItem] = []
    
    // Amounts (calculated)
    var currency: Currency = .eur
    var discountPercent: Double = 0
    var discountFixed: Double = 0
    
    // Payment
    var paymentReference: String = ""
    var paymentNotes: String = ""
    
    // Currency conversion (for invoices in non-base currency)
    var paidExchangeRate: Double?      // Exchange rate at time of payment (e.g., 1 USD = 0.92 EUR)
    var paidAmountInBaseCurrency: Double?  // Total converted to base currency
    
    // Notes
    var notes: String = ""
    var internalNotes: String = ""
    
    // Custom Fields
    var poNumber: String = ""
    var projectCode: String = ""
    
    // PDF Archival
    var archivedPDFHash: String?
    var archivedPDFData: Data?
    
    // Versioning
    var version: Int = 1
    var previousVersionId: UUID?
    
    // MARK: - Computed Properties
    
    var subtotal: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }
    
    var totalDiscount: Double {
        let percentDiscount = subtotal * (discountPercent / 100)
        return percentDiscount + discountFixed
    }
    
    var taxableAmount: Double {
        subtotal - totalDiscount
    }
    
    var taxBreakdown: [(rate: Double, amount: Double)] {
        var breakdown: [Double: Double] = [:]
        for item in lineItems {
            let taxAmount = item.total * (item.vatRate / 100)
            breakdown[item.vatRate, default: 0] += taxAmount
        }
        return breakdown.map { (rate: $0.key, amount: $0.value) }.sorted { $0.rate < $1.rate }
    }
    
    var totalTax: Double {
        taxBreakdown.reduce(0) { $0 + $1.amount }
    }
    
    var total: Double {
        taxableAmount + totalTax
    }
    
    var isOverdue: Bool {
        status == .sent && dueDate < Date()
    }
    
    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
    
    var isLocked: Bool {
        status != .draft
    }
    
    // MARK: - Status Transitions
    
    mutating func markAsSent() {
        guard status == .draft else { return }
        status = .sent
        sentAt = Date()
        updatedAt = Date()
    }
    
    mutating func markAsPaid(exchangeRate: Double? = nil, amountInBaseCurrency: Double? = nil) {
        guard status == .sent || status == .overdue else { return }
        status = .paid
        paidAt = Date()
        paidExchangeRate = exchangeRate
        paidAmountInBaseCurrency = amountInBaseCurrency
        updatedAt = Date()
    }
    
    mutating func markAsOverdue() {
        guard status == .sent else { return }
        status = .overdue
        updatedAt = Date()
    }
    
    mutating func cancel() {
        guard status != .paid else { return }
        status = .cancelled
        updatedAt = Date()
    }
}

// MARK: - Invoice Status

enum InvoiceStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .sent: return "blue"
        case .paid: return "green"
        case .overdue: return "red"
        case .cancelled: return "orange"
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "doc"
        case .sent: return "paperplane.fill"
        case .paid: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Line Item

struct LineItem: Codable, Identifiable {
    var id: UUID = UUID()
    var description: String = ""
    var quantity: Double = 1
    var unit: String = "Stück"
    var unitPrice: Double = 0
    var vatRate: Double = 19.0
    
    var total: Double {
        quantity * unitPrice
    }
    
    var totalWithTax: Double {
        total * (1 + vatRate / 100)
    }
}

// MARK: - Service Template

struct ServiceTemplate: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var description: String = ""
    var defaultQuantity: Double = 1
    var unit: String = "Stück"
    var unitPrice: Double = 0
    var vatRate: Double = 19.0
    
    func toLineItem() -> LineItem {
        LineItem(
            description: description.isEmpty ? name : description,
            quantity: defaultQuantity,
            unit: unit,
            unitPrice: unitPrice,
            vatRate: vatRate
        )
    }
}

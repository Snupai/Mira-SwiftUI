import Foundation
import SwiftData

/// SwiftData model for invoices
@Model
final class SDInvoice {
    // MARK: - Identifiers
    var id: UUID = UUID()
    
    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sentAt: Date?
    var paidAt: Date?
    
    // MARK: - Invoice Details
    var invoiceNumber: String = ""
    var statusRaw: String = InvoiceStatus.draft.rawValue
    
    // MARK: - Dates
    var issueDate: Date = Date()
    var dueDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    var serviceDate: Date?
    var serviceDateEnd: Date?
    
    // MARK: - Line Items (stored as JSON Data)
    var lineItemsData: Data?
    
    // MARK: - Amounts
    var currencyRaw: String = Currency.eur.rawValue
    var discountPercent: Double = 0
    var discountFixed: Double = 0
    
    // MARK: - Payment (encrypted)
    var encryptedPaymentReference: Data?
    var paymentNotes: String = ""
    
    // MARK: - Currency Conversion
    var paidExchangeRate: Double?
    var paidAmountInBaseCurrency: Double?
    
    // MARK: - Notes
    var notes: String = ""
    var encryptedInternalNotes: Data?
    
    // MARK: - Custom Fields
    var poNumber: String = ""
    var projectCode: String = ""
    
    // MARK: - PDF Archival
    var archivedPDFHash: String?
    var archivedPDFData: Data?
    
    // MARK: - Versioning
    var version: Int = 1
    var previousVersionId: UUID?
    
    // MARK: - Relationships
    var client: SDClient?
    
    // MARK: - Initializer
    
    init() {}
    
    // MARK: - Computed Properties
    
    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }
    
    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .eur }
        set { currencyRaw = newValue.rawValue }
    }
    
    var lineItems: [SDLineItem] {
        get {
            guard let data = lineItemsData else { return [] }
            do {
                return try JSONDecoder().decode([SDLineItem].self, from: data)
            } catch {
                print("⚠️ Failed to decode line items: \(error)")
                return []
            }
        }
        set {
            do {
                lineItemsData = try JSONEncoder().encode(newValue)
            } catch {
                print("⚠️ Failed to encode line items: \(error)")
                lineItemsData = nil
            }
        }
    }
    
    var paymentReference: String {
        get { decryptString(encryptedPaymentReference) }
        set { encryptedPaymentReference = encryptString(newValue) }
    }
    
    var internalNotes: String {
        get { decryptString(encryptedInternalNotes) }
        set { encryptedInternalNotes = encryptString(newValue) }
    }
    
    // MARK: - Calculated Properties
    
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
    
    func markAsSent() {
        guard status == .draft else { return }
        status = .sent
        sentAt = Date()
        updatedAt = Date()
    }
    
    func markAsPaid(exchangeRate: Double? = nil, amountInBaseCurrency: Double? = nil) {
        guard status == .sent || status == .overdue else { return }
        status = .paid
        paidAt = Date()
        paidExchangeRate = exchangeRate
        paidAmountInBaseCurrency = amountInBaseCurrency
        updatedAt = Date()
    }
    
    func markAsOverdue() {
        guard status == .sent else { return }
        status = .overdue
        updatedAt = Date()
    }
    
    func cancel() {
        guard status != .paid else { return }
        status = .cancelled
        updatedAt = Date()
    }
    
    // MARK: - Encryption Helpers
    
    private func encryptString(_ value: String) -> Data? {
        guard !value.isEmpty else { return nil }
        do {
            return try EncryptionService.shared.encrypt(Data(value.utf8))
        } catch {
            print("⚠️ Encryption failed: \(error)")
            return nil
        }
    }
    
    private func decryptString(_ data: Data?) -> String {
        guard let data = data, !data.isEmpty else { return "" }
        do {
            let decrypted = try EncryptionService.shared.decrypt(data)
            return String(data: decrypted, encoding: .utf8) ?? ""
        } catch {
            print("⚠️ Decryption failed: \(error)")
            return ""
        }
    }
}

// MARK: - Line Item (Codable struct for JSON storage)

struct SDLineItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var itemDescription: String = ""
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
    
    // Migration from LineItem
    init(from legacy: LineItem) {
        self.id = legacy.id
        self.itemDescription = legacy.description
        self.quantity = legacy.quantity
        self.unit = legacy.unit
        self.unitPrice = legacy.unitPrice
        self.vatRate = legacy.vatRate
    }
    
    init(id: UUID = UUID(), itemDescription: String = "", quantity: Double = 1, unit: String = "Stück", unitPrice: Double = 0, vatRate: Double = 19.0) {
        self.id = id
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.vatRate = vatRate
    }
    
    func toLegacy() -> LineItem {
        LineItem(
            id: id,
            description: itemDescription,
            quantity: quantity,
            unit: unit,
            unitPrice: unitPrice,
            vatRate: vatRate
        )
    }
}

// MARK: - Migration Helper

extension SDInvoice {
    /// Create from legacy Invoice (for migration)
    convenience init(from legacy: Invoice, client: SDClient?) {
        self.init()
        
        self.id = legacy.id
        self.createdAt = legacy.createdAt
        self.updatedAt = legacy.updatedAt
        self.sentAt = legacy.sentAt
        self.paidAt = legacy.paidAt
        
        self.invoiceNumber = legacy.invoiceNumber
        self.status = legacy.status
        
        self.issueDate = legacy.issueDate
        self.dueDate = legacy.dueDate
        self.serviceDate = legacy.serviceDate
        self.serviceDateEnd = legacy.serviceDateEnd
        
        self.lineItems = legacy.lineItems.map { SDLineItem(from: $0) }
        
        self.currency = legacy.currency
        self.discountPercent = legacy.discountPercent
        self.discountFixed = legacy.discountFixed
        
        self.paymentReference = legacy.paymentReference
        self.paymentNotes = legacy.paymentNotes
        
        self.paidExchangeRate = legacy.paidExchangeRate
        self.paidAmountInBaseCurrency = legacy.paidAmountInBaseCurrency
        
        self.notes = legacy.notes
        self.internalNotes = legacy.internalNotes
        
        self.poNumber = legacy.poNumber
        self.projectCode = legacy.projectCode
        
        self.archivedPDFHash = legacy.archivedPDFHash
        self.archivedPDFData = legacy.archivedPDFData
        
        self.version = legacy.version
        self.previousVersionId = legacy.previousVersionId
        
        self.client = client
    }
    
    /// Convert to legacy Invoice (for compatibility during migration)
    func toLegacy() -> Invoice {
        var invoice = Invoice(clientId: client?.id ?? UUID())
        
        invoice.id = id
        invoice.createdAt = createdAt
        invoice.updatedAt = updatedAt
        invoice.sentAt = sentAt
        invoice.paidAt = paidAt
        
        invoice.invoiceNumber = invoiceNumber
        invoice.status = status
        
        invoice.issueDate = issueDate
        invoice.dueDate = dueDate
        invoice.serviceDate = serviceDate
        invoice.serviceDateEnd = serviceDateEnd
        
        invoice.lineItems = lineItems.map { $0.toLegacy() }
        
        invoice.currency = currency
        invoice.discountPercent = discountPercent
        invoice.discountFixed = discountFixed
        
        invoice.paymentReference = paymentReference
        invoice.paymentNotes = paymentNotes
        
        invoice.paidExchangeRate = paidExchangeRate
        invoice.paidAmountInBaseCurrency = paidAmountInBaseCurrency
        
        invoice.notes = notes
        invoice.internalNotes = internalNotes
        
        invoice.poNumber = poNumber
        invoice.projectCode = projectCode
        
        invoice.archivedPDFHash = archivedPDFHash
        invoice.archivedPDFData = archivedPDFData
        
        invoice.version = version
        invoice.previousVersionId = previousVersionId
        
        return invoice
    }
}

import Foundation
import SwiftData

/// SwiftData model for invoice templates
@Model
final class SDInvoiceTemplate {
    // MARK: - Identifiers
    var id: UUID = UUID()
    
    // MARK: - Basic Info
    var name: String = ""
    var templateDescription: String = ""
    
    // MARK: - Template Content
    var lineItemsData: Data?
    var notes: String = ""
    var paymentNotes: String = ""
    
    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Relationships
    var defaultClient: SDClient?
    
    // MARK: - Initializer
    
    init() {}
    
    // MARK: - Computed Properties
    
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
    
    var isEmpty: Bool {
        name.isEmpty
    }
}

// MARK: - Migration Helper

extension SDInvoiceTemplate {
    /// Create from legacy InvoiceTemplate (for migration)
    convenience init(from legacy: InvoiceTemplate, defaultClient: SDClient?) {
        self.init()
        
        self.id = legacy.id
        self.name = legacy.name
        self.templateDescription = legacy.description
        self.lineItems = legacy.lineItems.map { SDLineItem(from: $0) }
        self.notes = legacy.notes
        self.paymentNotes = legacy.paymentNotes
        self.createdAt = legacy.createdAt
        self.defaultClient = defaultClient
    }
    
    /// Convert to legacy InvoiceTemplate (for compatibility during migration)
    func toLegacy() -> InvoiceTemplate {
        var template = InvoiceTemplate()
        
        template.id = id
        template.name = name
        template.description = templateDescription
        template.lineItems = lineItems.map { $0.toLegacy() }
        template.notes = notes
        template.paymentNotes = paymentNotes
        template.createdAt = createdAt
        template.defaultClientId = defaultClient?.id
        
        return template
    }
}

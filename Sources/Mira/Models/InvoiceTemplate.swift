import Foundation

struct InvoiceTemplate: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var description: String = ""
    var createdAt: Date = Date()
    
    // Template content
    var lineItems: [LineItem] = []
    var notes: String = ""
    var paymentNotes: String = ""
    var defaultClientId: UUID? = nil
    
    var isEmpty: Bool { name.isEmpty }
}

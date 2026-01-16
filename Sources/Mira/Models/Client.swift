import Foundation

struct Client: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Basic Info
    var name: String = ""
    var contactPerson: String = ""
    var email: String = ""
    var phone: String = ""
    
    // Billing Address
    var street: String = ""
    var city: String = ""
    var postalCode: String = ""
    var country: String = "Germany"
    
    // Tax & Legal
    var vatId: String = ""
    var taxNumber: String = ""
    
    // Defaults (per-client overrides)
    var defaultCurrency: Currency?
    var defaultPaymentTermsDays: Int?
    var defaultVatRate: Double?
    var language: String = "de"
    
    // Notes
    var notes: String = ""
    
    var isComplete: Bool {
        !name.isEmpty && !email.isEmpty
    }
    
    var formattedAddress: String {
        [
            street,
            "\(postalCode) \(city)",
            country
        ].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
    }
    
    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

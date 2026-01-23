import Foundation
import SwiftData

/// SwiftData model for client with encrypted sensitive fields
@Model
final class SDClient {
    // MARK: - Identifiers
    var id: UUID = UUID()
    
    // MARK: - Basic Info
    var name: String = ""
    var contactPerson: String = ""
    
    // MARK: - Contact (encrypted)
    var encryptedEmail: Data?
    var encryptedPhone: Data?
    
    // MARK: - Billing Address
    var street: String = ""
    var city: String = ""
    var postalCode: String = ""
    var country: String = "Germany"
    
    // MARK: - Tax & Legal (encrypted)
    var encryptedVatId: Data?
    var encryptedTaxNumber: Data?
    
    // MARK: - Defaults
    var defaultCurrencyRaw: String?
    var defaultPaymentTermsDays: Int?
    var defaultVatRate: Double?
    var language: String = "de"
    
    // MARK: - Notes
    var notes: String = ""
    
    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Relationships
    @Relationship(deleteRule: .nullify, inverse: \SDInvoice.client)
    var invoices: [SDInvoice]? = []
    
    // MARK: - Initializer
    
    init() {}
    
    // MARK: - Computed Properties (Decrypted Access)
    
    var email: String {
        get { decryptString(encryptedEmail) }
        set { encryptedEmail = encryptString(newValue) }
    }
    
    var phone: String {
        get { decryptString(encryptedPhone) }
        set { encryptedPhone = encryptString(newValue) }
    }
    
    var vatId: String {
        get { decryptString(encryptedVatId) }
        set { encryptedVatId = encryptString(newValue) }
    }
    
    var taxNumber: String {
        get { decryptString(encryptedTaxNumber) }
        set { encryptedTaxNumber = encryptString(newValue) }
    }
    
    var defaultCurrency: Currency? {
        get {
            guard let raw = defaultCurrencyRaw else { return nil }
            return Currency(rawValue: raw)
        }
        set { defaultCurrencyRaw = newValue?.rawValue }
    }
    
    var isComplete: Bool {
        !name.isEmpty && !email.isEmpty
    }
    
    var formattedAddress: String {
        [street, "\(postalCode) \(city)", country]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }
    
    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
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

// MARK: - Hashable

extension SDClient: Hashable {
    static func == (lhs: SDClient, rhs: SDClient) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Migration Helper

extension SDClient {
    /// Create from legacy Client (for migration)
    convenience init(from legacy: Client) {
        self.init()
        
        self.id = legacy.id
        self.name = legacy.name
        self.contactPerson = legacy.contactPerson
        
        // These will be encrypted via computed properties
        self.email = legacy.email
        self.phone = legacy.phone
        self.vatId = legacy.vatId
        self.taxNumber = legacy.taxNumber
        
        self.street = legacy.street
        self.city = legacy.city
        self.postalCode = legacy.postalCode
        self.country = legacy.country
        
        self.defaultCurrencyRaw = legacy.defaultCurrency?.rawValue
        self.defaultPaymentTermsDays = legacy.defaultPaymentTermsDays
        self.defaultVatRate = legacy.defaultVatRate
        self.language = legacy.language
        
        self.notes = legacy.notes
        self.createdAt = legacy.createdAt
        self.updatedAt = legacy.updatedAt
    }
    
    /// Convert to legacy Client (for compatibility during migration)
    func toLegacy() -> Client {
        var client = Client()
        
        client.id = id
        client.name = name
        client.contactPerson = contactPerson
        client.email = email
        client.phone = phone
        
        client.street = street
        client.city = city
        client.postalCode = postalCode
        client.country = country
        
        client.vatId = vatId
        client.taxNumber = taxNumber
        
        client.defaultCurrency = defaultCurrency
        client.defaultPaymentTermsDays = defaultPaymentTermsDays
        client.defaultVatRate = defaultVatRate
        client.language = language
        
        client.notes = notes
        client.createdAt = createdAt
        client.updatedAt = updatedAt
        
        return client
    }
}

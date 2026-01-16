import Foundation
import SwiftUI

struct CompanyProfile: Codable, Identifiable {
    var id: UUID = UUID()
    
    // Basic Info
    var companyName: String = ""
    var ownerName: String = ""
    var email: String = ""
    var phone: String = ""
    var website: String = ""
    
    // Address
    var street: String = ""
    var city: String = ""
    var postalCode: String = ""
    var country: String = "Germany"
    
    // Legal & Tax (DE focused)
    var vatId: String = ""           // USt-IdNr.
    var taxNumber: String = ""       // Steuernummer
    var companyRegistry: String = "" // Handelsregister
    var isVatExempt: Bool = false    // Kleinunternehmerregelung §19 UStG
    
    // Bank Details
    var bankName: String = ""
    var iban: String = ""
    var bic: String = ""
    var accountHolder: String = ""
    
    // Branding
    var logoData: Data? = nil
    var brandColorHex: String = "#0066CC"  // Default blue
    
    // Defaults
    var defaultCurrency: Currency = .eur
    var defaultPaymentTermsDays: Int = 14
    var defaultVatRate: Double = 19.0
    var invoiceNumberPrefix: String = "INV-"
    var nextInvoiceNumber: Int = 1
    
    // Formatting
    var locale: String = "de_DE"
    var dateFormat: String = "dd.MM.yyyy"
    
    // Email template
    var emailTemplate: String = """
Guten Tag,

anbei erhalten Sie die Rechnung {invoiceNumber} über {totalAmount}.

Bitte überweisen Sie den Betrag bis zum {dueDate} auf das folgende Konto:

Kontoinhaber: {accountHolder}
IBAN: {iban}
BIC: {bic}
Verwendungszweck: {invoiceNumber}

Bei Fragen stehe ich Ihnen gerne zur Verfügung.

Mit freundlichen Grüßen
{companyName}
"""
    
    // Computed brand color
    var brandColor: Color {
        Color(hex: brandColorHex) ?? .blue
    }
    
    var isComplete: Bool {
        !companyName.isEmpty &&
        !email.isEmpty &&
        !street.isEmpty &&
        !city.isEmpty &&
        !postalCode.isEmpty &&
        !iban.isEmpty
    }
    
    var formattedAddress: String {
        [
            street,
            "\(postalCode) \(city)",
            country
        ].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
    }
    
    func generateInvoiceNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        return "\(invoiceNumberPrefix)\(year)-\(String(format: "%04d", nextInvoiceNumber))"
    }
}

enum Currency: String, Codable, CaseIterable {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case chf = "CHF"
    
    var symbol: String {
        switch self {
        case .eur: return "€"
        case .usd: return "$"
        case .gbp: return "£"
        case .chf: return "CHF"
        }
    }
}

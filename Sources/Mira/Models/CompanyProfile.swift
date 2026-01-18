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
    
    // Email templates - one for each language
    var emailTemplateGerman: String = CompanyProfile.germanEmailTemplate
    var emailTemplateEnglish: String = CompanyProfile.englishEmailTemplate
    
    // PDF templates - separate for each language
    var pdfTemplateLanguage: PDFTemplateLanguage = .german
    
    // German PDF templates
    var pdfFooterTemplateGerman: String = PDFTemplateLanguage.german.defaultFooter
    var pdfClosingTemplateGerman: String = PDFTemplateLanguage.german.defaultClosing
    var pdfNotesTemplateGerman: String = ""
    
    // English PDF templates
    var pdfFooterTemplateEnglish: String = PDFTemplateLanguage.english.defaultFooter
    var pdfClosingTemplateEnglish: String = PDFTemplateLanguage.english.defaultClosing
    var pdfNotesTemplateEnglish: String = ""
    
    // Legacy (for backward compatibility)
    var pdfFooterTemplate: String = PDFTemplateLanguage.german.defaultFooter
    var pdfNotesTemplate: String = ""
    var pdfClosingTemplate: String = PDFTemplateLanguage.german.defaultClosing
    
    // Default templates for each language
    static let germanEmailTemplate = """
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
    
    static let englishEmailTemplate = """
Dear {clientName},

Please find attached invoice {invoiceNumber} for {totalAmount}.

Payment is due by {dueDate}. Please transfer the amount to the following account:

Account Holder: {accountHolder}
IBAN: {iban}
BIC: {bic}
Reference: {invoiceNumber}

If you have any questions, please don't hesitate to contact me.

Best regards,
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

enum EmailTemplateLanguage: String, Codable, CaseIterable {
    case german = "German"
    case english = "English"
    
    var icon: String {
        switch self {
        case .german: return "🇩🇪"
        case .english: return "🇬🇧"
        }
    }
    
    var defaultTemplate: String {
        switch self {
        case .german: return CompanyProfile.germanEmailTemplate
        case .english: return CompanyProfile.englishEmailTemplate
        }
    }
}

enum PDFTemplateLanguage: String, Codable, CaseIterable {
    case german = "German"
    case english = "English"
    
    var icon: String {
        switch self {
        case .german: return "🇩🇪"
        case .english: return "🇬🇧"
        }
    }
    
    var defaultFooter: String {
        switch self {
        case .german:
            return "{companyName} · USt-IdNr.: {vatId} · Steuernr.: {taxNumber}"
        case .english:
            return "{companyName} · VAT ID: {vatId} · Tax No.: {taxNumber}"
        }
    }
    
    var defaultClosing: String {
        switch self {
        case .german:
            return "Vielen Dank für Ihr Vertrauen!"
        case .english:
            return "Thank you for your business!"
        }
    }
    
    var defaultNotes: String {
        switch self {
        case .german:
            return "Zahlungsbedingungen: Zahlbar innerhalb von {paymentTerms} Tagen ohne Abzug."
        case .english:
            return "Payment Terms: Due within {paymentTerms} days without deduction."
        }
    }
}

/// Template variable replacement for PDF and email templates
struct TemplateVariables {
    static let availableVariables: [(key: String, description: String, descriptionDE: String)] = [
        ("{invoiceNumber}", "Invoice number", "Rechnungsnummer"),
        ("{companyName}", "Your company name", "Firmenname"),
        ("{clientName}", "Client name", "Kundenname"),
        ("{totalAmount}", "Total invoice amount", "Gesamtbetrag"),
        ("{subtotal}", "Subtotal (before VAT)", "Zwischensumme"),
        ("{dueDate}", "Payment due date", "Fälligkeitsdatum"),
        ("{issueDate}", "Invoice date", "Rechnungsdatum"),
        ("{vatId}", "VAT ID number", "USt-IdNr."),
        ("{taxNumber}", "Tax number", "Steuernummer"),
        ("{iban}", "Bank IBAN", "IBAN"),
        ("{bic}", "Bank BIC/SWIFT", "BIC"),
        ("{accountHolder}", "Bank account holder", "Kontoinhaber"),
        ("{bankName}", "Bank name", "Bankname"),
        ("{paymentTerms}", "Payment terms in days", "Zahlungsfrist in Tagen"),
        ("{ownerName}", "Owner/contact name", "Inhaber"),
        ("{email}", "Email address", "E-Mail"),
        ("{phone}", "Phone number", "Telefon"),
        ("{website}", "Website URL", "Webseite"),
    ]
    
    static func replace(
        in template: String,
        invoice: Any? = nil,  // Invoice type
        client: Any? = nil,   // Client type  
        profile: CompanyProfile,
        currencyFormatter: NumberFormatter? = nil,
        dateFormatter: DateFormatter? = nil
    ) -> String {
        var result = template
        
        // Profile variables (always available)
        result = result.replacingOccurrences(of: "{companyName}", with: profile.companyName)
        result = result.replacingOccurrences(of: "{ownerName}", with: profile.ownerName)
        result = result.replacingOccurrences(of: "{email}", with: profile.email)
        result = result.replacingOccurrences(of: "{phone}", with: profile.phone)
        result = result.replacingOccurrences(of: "{website}", with: profile.website)
        result = result.replacingOccurrences(of: "{vatId}", with: profile.vatId)
        result = result.replacingOccurrences(of: "{taxNumber}", with: profile.taxNumber)
        result = result.replacingOccurrences(of: "{iban}", with: profile.iban)
        result = result.replacingOccurrences(of: "{bic}", with: profile.bic)
        result = result.replacingOccurrences(of: "{bankName}", with: profile.bankName)
        result = result.replacingOccurrences(of: "{accountHolder}", with: profile.accountHolder.isEmpty ? profile.companyName : profile.accountHolder)
        result = result.replacingOccurrences(of: "{paymentTerms}", with: "\(profile.defaultPaymentTermsDays)")
        
        // Remove empty variable placeholders for cleaner output
        if profile.vatId.isEmpty {
            result = result.replacingOccurrences(of: "USt-IdNr.: {vatId}", with: "")
            result = result.replacingOccurrences(of: "VAT ID: {vatId}", with: "")
            result = result.replacingOccurrences(of: " · {vatId}", with: "")
        }
        if profile.taxNumber.isEmpty {
            result = result.replacingOccurrences(of: "Steuernr.: {taxNumber}", with: "")
            result = result.replacingOccurrences(of: "Tax No.: {taxNumber}", with: "")
            result = result.replacingOccurrences(of: " · {taxNumber}", with: "")
        }
        
        // Clean up double separators
        result = result.replacingOccurrences(of: " ·  · ", with: " · ")
        result = result.replacingOccurrences(of: " · · ", with: " · ")
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: " ·"))
        
        return result
    }
}

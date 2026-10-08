import Foundation
import SwiftData
import SwiftUI

/// SwiftData model for company profile with encrypted sensitive fields
@Model
final class SDCompanyProfile {
    // MARK: - Identifiers
    var id: UUID = UUID()
    
    // MARK: - Basic Info
    var companyName: String = ""
    var ownerName: String = ""
    var email: String = ""
    var phone: String = ""
    var website: String = ""
    
    // MARK: - Address
    var street: String = ""
    var city: String = ""
    var postalCode: String = ""
    var country: String = "Germany"
    
    // MARK: - Legal & Tax (stored encrypted)
    /// Encrypted VAT ID (USt-IdNr.)
    var encryptedVatId: Data?
    /// Encrypted Tax Number (Steuernummer)
    var encryptedTaxNumber: Data?
    var companyRegistry: String = ""
    var isVatExempt: Bool = false
    
    // MARK: - Bank Details (stored encrypted)
    /// Encrypted bank name
    var encryptedBankName: Data?
    /// Encrypted IBAN
    var encryptedIban: Data?
    /// Encrypted BIC
    var encryptedBic: Data?
    /// Encrypted account holder
    var encryptedAccountHolder: Data?
    
    // MARK: - Branding
    var logoData: Data?
    var brandColorHex: String = "#0066CC"
    
    // MARK: - Defaults
    var defaultCurrencyRaw: String = Currency.eur.rawValue
    var defaultPaymentTermsDays: Int = 14
    var defaultVatRate: Double = 19.0
    var invoiceNumberPrefix: String = "INV-"
    var nextInvoiceNumber: Int = 1
    
    // MARK: - Formatting
    var locale: String = "de_DE"
    var dateFormat: String = "dd.MM.yyyy"
    
    // MARK: - Export
    var defaultExportPath: String = ""  // Empty = ask each time
    
    // MARK: - Email Templates
    var emailTemplateGerman: String = SDCompanyProfile.defaultGermanEmailTemplate
    var emailTemplateEnglish: String = SDCompanyProfile.defaultEnglishEmailTemplate
    
    // MARK: - PDF Templates
    var pdfTemplateLanguageRaw: String = "German"
    var pdfFooterTemplateGerman: String = ""
    var pdfClosingTemplateGerman: String = "Vielen Dank für Ihr Vertrauen!"
    var pdfNotesTemplateGerman: String = ""
    var pdfFooterTemplateEnglish: String = ""
    var pdfClosingTemplateEnglish: String = "Thank you for your business!"
    var pdfNotesTemplateEnglish: String = ""
    
    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Initializer
    
    init() {}
    
    // MARK: - Computed Properties (Decrypted Access)
    
    var vatId: String {
        get { decryptString(encryptedVatId) }
        set { encryptedVatId = encryptString(newValue) }
    }
    
    var taxNumber: String {
        get { decryptString(encryptedTaxNumber) }
        set { encryptedTaxNumber = encryptString(newValue) }
    }
    
    var bankName: String {
        get { decryptString(encryptedBankName) }
        set { encryptedBankName = encryptString(newValue) }
    }
    
    var iban: String {
        get { decryptString(encryptedIban) }
        set { encryptedIban = encryptString(newValue) }
    }
    
    var bic: String {
        get { decryptString(encryptedBic) }
        set { encryptedBic = encryptString(newValue) }
    }
    
    var accountHolder: String {
        get { decryptString(encryptedAccountHolder) }
        set { encryptedAccountHolder = encryptString(newValue) }
    }
    
    var defaultCurrency: Currency {
        get { Currency(rawValue: defaultCurrencyRaw) ?? .eur }
        set { defaultCurrencyRaw = newValue.rawValue }
    }
    
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
        [street, "\(postalCode) \(city)", country]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }
    
    func generateInvoiceNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        return "\(invoiceNumberPrefix)\(year)-\(String(format: "%04d", nextInvoiceNumber))"
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
    
    // MARK: - Default Templates
    
    static let defaultGermanEmailTemplate = """
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
    
    static let defaultEnglishEmailTemplate = """
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
}

// MARK: - Migration Helper

extension SDCompanyProfile {
    /// Create from legacy CompanyProfile (for migration)
    convenience init(from legacy: CompanyProfile) {
        self.init()
        
        self.id = legacy.id
        update(from: legacy)
    }
    
    func update(from profile: CompanyProfile) {
        companyName = profile.companyName
        ownerName = profile.ownerName
        email = profile.email
        phone = profile.phone
        website = profile.website
        street = profile.street
        city = profile.city
        postalCode = profile.postalCode
        country = profile.country
        companyRegistry = profile.companyRegistry
        isVatExempt = profile.isVatExempt
        logoData = profile.logoData
        brandColorHex = profile.brandColorHex
        defaultPaymentTermsDays = profile.defaultPaymentTermsDays
        defaultVatRate = profile.defaultVatRate
        invoiceNumberPrefix = profile.invoiceNumberPrefix
        nextInvoiceNumber = profile.nextInvoiceNumber
        locale = profile.locale
        dateFormat = profile.dateFormat
        defaultExportPath = profile.defaultExportPath
        emailTemplateGerman = profile.emailTemplateGerman
        emailTemplateEnglish = profile.emailTemplateEnglish
        pdfFooterTemplateGerman = profile.pdfFooterTemplateGerman
        pdfClosingTemplateGerman = profile.pdfClosingTemplateGerman
        pdfNotesTemplateGerman = profile.pdfNotesTemplateGerman
        pdfFooterTemplateEnglish = profile.pdfFooterTemplateEnglish
        pdfClosingTemplateEnglish = profile.pdfClosingTemplateEnglish
        pdfNotesTemplateEnglish = profile.pdfNotesTemplateEnglish
        if vatId != profile.vatId { vatId = profile.vatId }
        if taxNumber != profile.taxNumber { taxNumber = profile.taxNumber }
        if bankName != profile.bankName { bankName = profile.bankName }
        if iban != profile.iban { iban = profile.iban }
        if bic != profile.bic { bic = profile.bic }
        if accountHolder != profile.accountHolder { accountHolder = profile.accountHolder }
        defaultCurrency = profile.defaultCurrency
        pdfTemplateLanguageRaw = profile.pdfTemplateLanguage.rawValue
        updatedAt = Date()
    }

    /// Convert to legacy CompanyProfile (for compatibility during migration)
    func toLegacy() -> CompanyProfile {
        var profile = CompanyProfile()
        
        profile.id = id
        profile.companyName = companyName
        profile.ownerName = ownerName
        profile.email = email
        profile.phone = phone
        profile.website = website
        
        profile.street = street
        profile.city = city
        profile.postalCode = postalCode
        profile.country = country
        
        profile.vatId = vatId
        profile.taxNumber = taxNumber
        profile.companyRegistry = companyRegistry
        profile.isVatExempt = isVatExempt
        
        profile.bankName = bankName
        profile.iban = iban
        profile.bic = bic
        profile.accountHolder = accountHolder
        
        profile.logoData = logoData
        profile.brandColorHex = brandColorHex
        
        profile.defaultCurrency = defaultCurrency
        profile.defaultPaymentTermsDays = defaultPaymentTermsDays
        profile.defaultVatRate = defaultVatRate
        profile.invoiceNumberPrefix = invoiceNumberPrefix
        profile.nextInvoiceNumber = nextInvoiceNumber
        
        profile.locale = locale
        profile.dateFormat = dateFormat
        profile.defaultExportPath = defaultExportPath
        profile.pdfTemplateLanguage = PDFTemplateLanguage(rawValue: pdfTemplateLanguageRaw) ?? .german
        
        profile.emailTemplateGerman = emailTemplateGerman
        profile.emailTemplateEnglish = emailTemplateEnglish
        
        profile.pdfFooterTemplateGerman = pdfFooterTemplateGerman
        profile.pdfClosingTemplateGerman = pdfClosingTemplateGerman
        profile.pdfNotesTemplateGerman = pdfNotesTemplateGerman
        profile.pdfFooterTemplateEnglish = pdfFooterTemplateEnglish
        profile.pdfClosingTemplateEnglish = pdfClosingTemplateEnglish
        profile.pdfNotesTemplateEnglish = pdfNotesTemplateEnglish
        
        return profile
    }
}

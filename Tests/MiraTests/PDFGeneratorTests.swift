import XCTest
import PDFKit
@testable import Mira

/// Smoke + content tests for `PDFGenerator`.
///
/// We extract text from the rendered PDF (via `PDFKit.PDFDocument`) and assert
/// that the per-locale labels appear, rather than pixel-diffing the layout.
/// That keeps tests stable across font/render-engine changes while still
/// catching regressions in the German/English string tables and basic invoice
/// data flow.
final class PDFGeneratorTests: XCTestCase {

    // MARK: - Smoke

    func testGeneratesNonEmptyPDFInGerman() throws {
        let (invoice, client, profile) = makeFixtures()
        let data = PDFGenerator.generateInvoicePDF(
            invoice: invoice,
            client: client,
            companyProfile: profile,
            language: .german
        )
        let pdf = try XCTUnwrap(data, "PDF generation returned nil")
        XCTAssertGreaterThan(pdf.count, 1000, "PDF data is suspiciously small")
    }

    func testGeneratesNonEmptyPDFInEnglish() throws {
        let (invoice, client, profile) = makeFixtures()
        let data = PDFGenerator.generateInvoicePDF(
            invoice: invoice,
            client: client,
            companyProfile: profile,
            language: .english
        )
        let pdf = try XCTUnwrap(data, "PDF generation returned nil")
        XCTAssertGreaterThan(pdf.count, 1000)
    }

    // MARK: - Page count

    func testInvoiceFitsOnAtLeastOnePage() throws {
        let (invoice, client, profile) = makeFixtures()
        let data = try XCTUnwrap(
            PDFGenerator.generateInvoicePDF(invoice: invoice, client: client, companyProfile: profile)
        )
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
    }

    // MARK: - Locale labels appear in extracted text

    func testGermanPDFContainsGermanLabels() throws {
        let (invoice, client, profile) = makeFixtures()
        let text = try extractedText(invoice: invoice, client: client, profile: profile, language: .german)

        XCTAssertTrue(text.contains("Rechnung"), "Missing German invoice header")
        // "Beschreibung" — column header
        XCTAssertTrue(text.contains("Beschreibung"), "Missing German description column")
    }

    func testEnglishPDFContainsEnglishLabels() throws {
        let (invoice, client, profile) = makeFixtures()
        let text = try extractedText(invoice: invoice, client: client, profile: profile, language: .english)

        XCTAssertTrue(text.contains("Invoice"), "Missing English invoice header")
        XCTAssertTrue(text.contains("Description"), "Missing English description column")
    }

    func testInvoiceNumberAppearsInPDF() throws {
        var (invoice, client, profile) = makeFixtures()
        invoice.invoiceNumber = "INV-TEST-12345"

        let text = try extractedText(invoice: invoice, client: client, profile: profile, language: .english)
        XCTAssertTrue(text.contains("INV-TEST-12345"), "Invoice number not rendered in PDF")
    }

    func testKleinunternehmerNoticeAppearsWhenExempt() throws {
        var (invoice, client, profile) = makeFixtures()
        profile.isVatExempt = true
        invoice.lineItems = invoice.lineItems.map { item in
            var copy = item
            copy.vatRate = 0
            return copy
        }

        let text = try extractedText(invoice: invoice, client: client, profile: profile, language: .german)
        // The notice mentions §19 UStG.
        XCTAssertTrue(text.contains("§19"), "Kleinunternehmer §19 notice missing for VAT-exempt profile")
    }

    // MARK: - Helpers

    private func extractedText(
        invoice: Invoice,
        client: Client,
        profile: CompanyProfile,
        language: PDFLanguage
    ) throws -> String {
        let data = try XCTUnwrap(
            PDFGenerator.generateInvoicePDF(invoice: invoice, client: client, companyProfile: profile, language: language)
        )
        let document = try XCTUnwrap(PDFDocument(data: data))
        var combined = ""
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let text = page.string {
                combined += text + "\n"
            }
        }
        return combined
    }

    private func makeFixtures() -> (Invoice, Client, CompanyProfile) {
        var profile = CompanyProfile()
        profile.companyName = "Snupai Studios"
        profile.ownerName = "Snupai"
        profile.email = "hello@snupai.dev"
        profile.street = "Beispielstr. 1"
        profile.city = "Berlin"
        profile.postalCode = "10115"
        profile.country = "Germany"
        profile.iban = "DE89370400440532013000"
        profile.bic = "COBADEFFXXX"
        profile.vatId = "DE123456789"
        profile.brandColorHex = "#0066CC"

        var client = Client()
        client.name = "Acme Corp"
        client.email = "billing@acme.com"
        client.street = "Hauptstr. 42"
        client.city = "Munich"
        client.postalCode = "80331"
        client.country = "Germany"

        var invoice = Invoice(clientId: client.id)
        invoice.invoiceNumber = "INV-2026-0001"
        invoice.lineItems = [
            LineItem(description: "Development Services", quantity: 10, unit: "h", unitPrice: 120, vatRate: 19),
            LineItem(description: "Design Review", quantity: 2, unit: "h", unitPrice: 90, vatRate: 19)
        ]

        return (invoice, client, profile)
    }
}

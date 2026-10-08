import XCTest
import SwiftData
import PDFKit
@testable import Mira

final class InvoiceWorkflowTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value + "T12:00:00Z")!
    }
    private func invoice(status: InvoiceStatus = .sent, currency: Currency = .eur) -> Invoice {
        var invoice = Invoice(clientId: UUID())
        invoice.invoiceNumber = "INV-2026-0001"
        invoice.status = status
        invoice.currency = currency
        invoice.issueDate = date("2026-09-20")
        invoice.dueDate = date("2026-10-07")
        invoice.lineItems = [LineItem(description: "Design", quantity: 2, unitPrice: 100, vatRate: 19)]
        return invoice
    }

    func testOverdueBeginsOnDayAfterDueDate() {
        let due = date("2026-10-08")
        XCTAssertEqual(InvoiceStatus.effective(.sent, dueDate: due, at: due.addingTimeInterval(3600), calendar: calendar), .sent)
        XCTAssertEqual(InvoiceStatus.effective(.sent, dueDate: due, at: date("2026-10-09"), calendar: calendar), .overdue)
        for status in [InvoiceStatus.draft, .paid, .cancelled, .overdue] {
            XCTAssertEqual(InvoiceStatus.effective(status, dueDate: due, at: date("2026-10-09"), calendar: calendar), status)
        }
    }

    func testValidationRejectsMissingClientAndEmptyItems() {
        let issues = InvoiceValidation.issues(for: Invoice(clientId: UUID()), hasClient: false, existingNumbers: [])
        XCTAssertTrue(issues.contains("Select a client."))
        XCTAssertTrue(issues.contains("Enter an invoice number."))
        XCTAssertTrue(issues.contains("Add at least one line item."))
    }

    func testValidationRejectsDuplicatesAndInvalidRows() {
        var invoice = invoice()
        invoice.invoiceNumber = " inv-2026-0001 "
        invoice.dueDate = date("2026-09-19")
        invoice.lineItems = [LineItem(description: " ", quantity: 0, unitPrice: -.infinity)]
        let issues = InvoiceValidation.issues(for: invoice, hasClient: true, existingNumbers: ["INV-2026-0001"], calendar: calendar)
        XCTAssertTrue(issues.contains("This invoice number is already in use."))
        XCTAssertTrue(issues.contains("Due date must be on or after the issue date."))
        XCTAssertTrue(issues.contains("Add a description for item 1."))
        XCTAssertTrue(issues.contains("Item 1 needs a quantity greater than zero."))
        XCTAssertTrue(issues.contains("Item 1 needs a valid, nonnegative price."))
    }

    func testValidationAllowsDueDateOnIssueDayAndZeroPrice() {
        var invoice = invoice()
        invoice.dueDate = invoice.issueDate.addingTimeInterval(-3600)
        invoice.lineItems[0].unitPrice = 0
        XCTAssertTrue(InvoiceValidation.issues(for: invoice, hasClient: true, existingNumbers: [], calendar: calendar).isEmpty)
    }

    func testCollectedRevenueUsesPaymentDate() {
        var invoice = invoice(status: .paid)
        invoice.issueDate = date("2025-12-20")
        invoice.paidAt = date("2026-10-08")
        let metrics = DashboardMetrics(invoices: [InvoiceSummary(invoice, client: nil, isVatExempt: false)], baseCurrency: .eur, now: date("2026-10-08"), calendar: calendar)
        XCTAssertEqual(metrics.month.baseAmount, 238, accuracy: 0.001)
        XCTAssertEqual(metrics.year.baseAmount, 238, accuracy: 0.001)
        XCTAssertEqual(metrics.revenue.last?.amount, 238)
    }

    func testOutstandingIncludesDerivedOverdueAndSeparatesCurrencies() {
        let local = invoice()
        let foreign = invoice(currency: .usd)
        let metrics = DashboardMetrics(invoices: [local, foreign].map { InvoiceSummary($0, client: nil, isVatExempt: false) }, baseCurrency: .eur, now: date("2026-10-08"), calendar: calendar)
        XCTAssertEqual(metrics.outstanding.count, 2)
        XCTAssertEqual(metrics.overdue.count, 2)
        XCTAssertEqual(metrics.outstanding.baseAmount, 238)
        XCTAssertEqual(metrics.outstanding.excluded[.usd], 238)
        XCTAssertNotNil(metrics.outstanding.exclusionDescription)
    }

    func testPaidConversionAndMissingDatesAreExplicit() {
        var converted = invoice(status: .paid, currency: .usd)
        converted.paidAt = date("2026-10-08")
        converted.paidAmountInBaseCurrency = 220
        var missingRate = converted
        missingRate.id = UUID()
        missingRate.paidAmountInBaseCurrency = nil
        var missingDate = converted
        missingDate.id = UUID()
        missingDate.paidAt = nil
        let metrics = DashboardMetrics(invoices: [converted, missingRate, missingDate].map { InvoiceSummary($0, client: nil, isVatExempt: false) }, baseCurrency: .eur, now: date("2026-10-08"), calendar: calendar)
        XCTAssertEqual(metrics.month.baseAmount, 220)
        XCTAssertEqual(metrics.month.excluded[.usd], 238)
        XCTAssertEqual(metrics.revenueExclusions.excluded[.usd], 238)
        XCTAssertEqual(metrics.missingPaymentDates, 1)
    }

    @MainActor
    func testSummaryMatchesStoredAmountsAndRelationship() async throws {
        let client = SDClient()
        client.name = "Acme"
        var value = invoice()
        value.discountFixed = 10
        let stored = SDInvoice(from: value, client: client)
        let summary = InvoiceSummary(stored, isVatExempt: false)
        XCTAssertEqual(summary.clientId, client.id)
        XCTAssertEqual(summary.clientName, "Acme")
        XCTAssertEqual(summary.amount, value.total)
        XCTAssertEqual(InvoiceSummary(stored, isVatExempt: true).amount, value.taxableAmount)
    }

    @MainActor
    func testCompanyDefaultsPersistWithoutOpeningSettings() async throws {
        let schema = DataContainer.schema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        var profile = CompanyProfile()
        profile.companyName = "Mira Test"
        profile.defaultCurrency = .gbp
        profile.isVatExempt = true
        profile.defaultVatRate = 0
        profile.defaultPaymentTermsDays = 30
        profile.defaultExportPath = "/tmp/mira-export-test"
        profile.pdfTemplateLanguage = .english
        let stored = SDCompanyProfile(from: profile)
        context.insert(stored)
        try context.save()
        let fresh = ModelContext(container)
        let reloaded = try XCTUnwrap(fresh.fetch(FetchDescriptor<SDCompanyProfile>()).first)
        XCTAssertEqual(reloaded.defaultCurrency, .gbp)
        XCTAssertTrue(reloaded.isVatExempt)
        XCTAssertEqual(reloaded.defaultPaymentTermsDays, 30)
        XCTAssertEqual(reloaded.toLegacy().defaultExportPath, profile.defaultExportPath)
        XCTAssertEqual(reloaded.toLegacy().pdfTemplateLanguage, .english)
        var updated = reloaded.toLegacy()
        updated.defaultCurrency = .chf
        updated.defaultPaymentTermsDays = 60
        updated.pdfClosingTemplateEnglish = "Thank you!"
        reloaded.update(from: updated)
        try fresh.save()
        let third = ModelContext(container)
        let saved = try XCTUnwrap(third.fetch(FetchDescriptor<SDCompanyProfile>()).first)
        XCTAssertEqual(saved.defaultCurrency, .chf)
        XCTAssertEqual(saved.defaultPaymentTermsDays, 60)
        XCTAssertEqual(saved.pdfClosingTemplateEnglish, "Thank you!")
    }

    @MainActor
    func testClientEditsAndInvoiceHistoryUseFreshSwiftDataContext() async throws {
        let schema = DataContainer.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        let client = SDClient()
        client.name = "Before"
        let stored = SDInvoice(from: invoice(), client: client)
        context.insert(client)
        context.insert(stored)
        try context.save()
        client.name = "After"
        client.updatedAt = Date()
        try context.save()
        let fresh = ModelContext(container)
        let invoices = try fresh.fetch(FetchDescriptor<SDInvoice>())
        XCTAssertEqual(invoices.filter { $0.client?.id == client.id }.count, 1)
        XCTAssertEqual(invoices.first?.client?.name, "After")
    }

    @MainActor
    func testPDFExportProducesReadableDocumentAndReportsFailure() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mira-pdf-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var profile = CompanyProfile()
        profile.companyName = "Mira Studio"
        profile.isVatExempt = true
        var client = Client()
        client.name = "Acme Studio"
        let value = invoice()
        let output = folder.appendingPathComponent("invoice.pdf")
        XCTAssertTrue(PDFGenerator.saveInvoicePDF(invoice: value, client: client, companyProfile: profile, to: output, language: .english))
        let pdf = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(pdf.pageCount, 1)
        let text = try XCTUnwrap(pdf.string)
        XCTAssertTrue(text.contains(value.invoiceNumber))
        XCTAssertTrue(text.contains("Design"))
        let missing = folder.appendingPathComponent("missing/invoice.pdf")
        XCTAssertFalse(PDFGenerator.saveInvoicePDF(invoice: value, client: client, companyProfile: profile, to: missing, language: .english))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }

    func testLargeDatasetAggregation() {
        var paid = invoice(status: .paid)
        paid.paidAt = date("2026-10-08")
        let summaries = (0..<10_000).map { _ -> InvoiceSummary in
            var copy = paid
            copy.id = UUID()
            return InvoiceSummary(copy, client: nil, isVatExempt: true)
        }
        let now = date("2026-10-08")
        let metrics = DashboardMetrics(invoices: summaries, baseCurrency: .eur, now: now, calendar: calendar)
        XCTAssertEqual(metrics.month.count, 10_000)
        XCTAssertEqual(metrics.month.baseAmount, 2_000_000)
        measure { _ = DashboardMetrics(invoices: summaries, baseCurrency: .eur, now: now, calendar: calendar) }
    }
}

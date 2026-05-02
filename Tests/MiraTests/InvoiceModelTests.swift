import XCTest
@testable import Mira

/// Pure-logic tests for `Invoice` math, status transitions, and Kleinunternehmer.
///
/// These are the highest-leverage tests in the project: they're fast, deterministic,
/// and protect the math users base their tax filings on.
final class InvoiceModelTests: XCTestCase {

    // MARK: - Math

    func testSubtotalSumsLineItems() {
        var invoice = makeInvoice()
        invoice.lineItems = [
            LineItem(description: "Service A", quantity: 2, unit: "h", unitPrice: 100, vatRate: 19),
            LineItem(description: "Service B", quantity: 1, unit: "h", unitPrice: 50, vatRate: 19)
        ]
        XCTAssertEqual(invoice.subtotal, 250, accuracy: 0.0001)
    }

    func testPercentDiscountReducesTaxableAmount() {
        var invoice = makeInvoice()
        invoice.lineItems = [
            LineItem(description: "Service", quantity: 1, unit: "h", unitPrice: 1000, vatRate: 19)
        ]
        invoice.discountPercent = 10
        XCTAssertEqual(invoice.totalDiscount, 100, accuracy: 0.0001)
        XCTAssertEqual(invoice.taxableAmount, 900, accuracy: 0.0001)
    }

    func testFixedAndPercentDiscountStack() {
        var invoice = makeInvoice()
        invoice.lineItems = [
            LineItem(description: "Service", quantity: 1, unit: "h", unitPrice: 1000, vatRate: 19)
        ]
        invoice.discountPercent = 10
        invoice.discountFixed = 50
        XCTAssertEqual(invoice.totalDiscount, 150, accuracy: 0.0001)
        XCTAssertEqual(invoice.taxableAmount, 850, accuracy: 0.0001)
    }

    func testTaxBreakdownGroupsByRate() {
        var invoice = makeInvoice()
        invoice.lineItems = [
            LineItem(description: "Standard", quantity: 1, unit: "h", unitPrice: 100, vatRate: 19),
            LineItem(description: "Reduced", quantity: 1, unit: "h", unitPrice: 100, vatRate: 7),
            LineItem(description: "Standard 2", quantity: 1, unit: "h", unitPrice: 50, vatRate: 19)
        ]
        let breakdown = Dictionary(uniqueKeysWithValues: invoice.taxBreakdown.map { ($0.rate, $0.amount) })
        XCTAssertEqual(breakdown[19] ?? 0, 28.5, accuracy: 0.0001)
        XCTAssertEqual(breakdown[7] ?? 0, 7.0, accuracy: 0.0001)
    }

    func testTotalIncludesTaxOnNonExemptInvoice() {
        // Note: the model itself doesn't gate on isVatExempt — that's handled at PDF render time.
        // The math here simply respects per-line VAT rates.
        var invoice = makeInvoice()
        invoice.lineItems = [
            LineItem(description: "Service", quantity: 1, unit: "h", unitPrice: 100, vatRate: 19)
        ]
        XCTAssertEqual(invoice.subtotal, 100, accuracy: 0.0001)
        XCTAssertEqual(invoice.totalTax, 19, accuracy: 0.0001)
        XCTAssertEqual(invoice.total, 119, accuracy: 0.0001)
    }

    func testEmptyInvoiceHasZeroTotals() {
        let invoice = makeInvoice()
        XCTAssertEqual(invoice.subtotal, 0)
        XCTAssertEqual(invoice.totalTax, 0)
        XCTAssertEqual(invoice.total, 0)
    }

    // MARK: - Kleinunternehmer toggle

    func testKleinunternehmerProfileFlagPersistsThroughCodable() throws {
        var profile = CompanyProfile()
        profile.companyName = "Snupai Studios"
        profile.isVatExempt = true

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(CompanyProfile.self, from: data)

        XCTAssertTrue(decoded.isVatExempt)
        XCTAssertEqual(decoded.companyName, "Snupai Studios")
    }

    // MARK: - Status transitions

    func testDraftCanBeMarkedSent() {
        var invoice = makeInvoice()
        XCTAssertEqual(invoice.status, .draft)
        invoice.markAsSent()
        XCTAssertEqual(invoice.status, .sent)
        XCTAssertNotNil(invoice.sentAt)
    }

    func testSentCanBeMarkedPaid() {
        var invoice = makeInvoice()
        invoice.markAsSent()
        invoice.markAsPaid(exchangeRate: 1.08, amountInBaseCurrency: 1080)
        XCTAssertEqual(invoice.status, .paid)
        XCTAssertNotNil(invoice.paidAt)
        XCTAssertEqual(invoice.paidExchangeRate, 1.08)
        XCTAssertEqual(invoice.paidAmountInBaseCurrency, 1080)
    }

    func testOverdueCanBeMarkedPaid() {
        var invoice = makeInvoice()
        invoice.markAsSent()
        invoice.markAsOverdue()
        XCTAssertEqual(invoice.status, .overdue)
        invoice.markAsPaid()
        XCTAssertEqual(invoice.status, .paid)
    }

    func testPaidCannotBeCancelled() {
        var invoice = makeInvoice()
        invoice.markAsSent()
        invoice.markAsPaid()
        invoice.cancel()
        XCTAssertEqual(invoice.status, .paid, "cancel() must be a no-op once paid")
    }

    func testDraftCannotJumpDirectlyToPaid() {
        var invoice = makeInvoice()
        invoice.markAsPaid()
        XCTAssertEqual(invoice.status, .draft, "markAsPaid must require sent/overdue first")
    }

    func testIsLockedOutsideDraft() {
        var invoice = makeInvoice()
        XCTAssertFalse(invoice.isLocked)
        invoice.markAsSent()
        XCTAssertTrue(invoice.isLocked)
    }

    // MARK: - Helpers

    private func makeInvoice() -> Invoice {
        Invoice(clientId: UUID())
    }
}

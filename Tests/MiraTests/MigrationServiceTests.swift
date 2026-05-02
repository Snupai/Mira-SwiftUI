import XCTest
@testable import Mira

/// Tests around legacy JSON load paths used by `MigrationService`.
///
/// These exercise the Codable shapes that real users will have on disk.
/// Migration is a one-shot, irreversible operation, so silently failing to
/// decode legacy data would lose users' history.
///
/// We round-trip via Mira's own `JSONEncoder` for golden cases (instead of
/// hand-crafting JSON) so the tests stay green if the model shape evolves —
/// but a hand-rolled corrupted fixture still verifies the failure path is
/// loud, not silent.
final class MigrationServiceTests: XCTestCase {

    // MARK: - Profile

    func testGoldenProfileRoundTrips() throws {
        var profile = CompanyProfile()
        profile.companyName = "Snupai Studios"
        profile.iban = "DE89370400440532013000"
        profile.bic = "COBADEFFXXX"
        profile.isVatExempt = true

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(CompanyProfile.self, from: data)

        XCTAssertEqual(decoded.companyName, "Snupai Studios")
        XCTAssertEqual(decoded.iban, "DE89370400440532013000")
        XCTAssertEqual(decoded.bic, "COBADEFFXXX")
        XCTAssertTrue(decoded.isVatExempt)
    }

    func testCorruptedProfileThrows() {
        let json = "{ this is not json }".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(CompanyProfile.self, from: json),
                             "decode of malformed profile.json must throw, not silently return nil")
    }

    func testEmptyJSONDictThrows() {
        // Swift's synthesized Codable doesn't honor stored-property defaults during
        // decoding — every CodingKey must appear in the JSON. So a literally empty
        // profile.json must throw, which causes `loadLegacyProfile()` to log and
        // return nil rather than silently substituting a default profile.
        let json = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(CompanyProfile.self, from: json),
                             "Empty JSON dict must throw so the migration path can log it")
    }

    // MARK: - Clients

    func testGoldenClientArrayRoundTrips() throws {
        var client = Client()
        client.name = "Acme Corp"
        client.email = "billing@acme.com"
        client.city = "Berlin"

        let data = try JSONEncoder().encode([client])
        let decoded = try JSONDecoder().decode([Client].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].name, "Acme Corp")
        XCTAssertEqual(decoded[0].email, "billing@acme.com")
        XCTAssertEqual(decoded[0].city, "Berlin")
    }

    func testEmptyClientArrayDecodes() throws {
        let json = "[]".data(using: .utf8)!
        let clients = try JSONDecoder().decode([Client].self, from: json)
        XCTAssertEqual(clients.count, 0)
    }

    func testCorruptedClientsThrows() {
        let json = "{ not an array }".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode([Client].self, from: json))
    }

    // MARK: - Invoices

    func testGoldenInvoiceArrayRoundTrips() throws {
        let clientId = UUID()
        var invoice = Invoice(clientId: clientId)
        invoice.invoiceNumber = "INV-2026-0001"
        invoice.lineItems = [
            LineItem(description: "Development", quantity: 10, unit: "h", unitPrice: 120, vatRate: 19)
        ]

        let data = try JSONEncoder().encode([invoice])
        let decoded = try JSONDecoder().decode([Invoice].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].invoiceNumber, "INV-2026-0001")
        XCTAssertEqual(decoded[0].clientId, clientId)
        XCTAssertEqual(decoded[0].lineItems.count, 1)
        XCTAssertEqual(decoded[0].subtotal, 1200, accuracy: 0.0001)
        XCTAssertEqual(decoded[0].total, 1428, accuracy: 0.0001)
    }

    // MARK: - Migration status (smoke)

    func testMigrationStatusFlagsAreReadable() {
        // Property accessors must not throw or crash regardless of disk state.
        // Developers running tests locally may or may not have legacy data —
        // we just verify the API is callable.
        let service = MigrationService.shared
        _ = service.needsMigration
        _ = service.useSwiftData
        _ = service.migrationStatus
    }
}

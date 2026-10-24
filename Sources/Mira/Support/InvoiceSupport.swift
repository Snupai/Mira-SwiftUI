import Foundation
import SwiftData

/// Lightweight list data: decode items once, without decrypting unrelated invoice fields.
struct InvoiceSummary: Identifiable {
    let id: UUID
    let clientId: UUID?
    let invoiceNumber: String
    let clientName: String
    let clientEmail: String
    let notes: String
    let status: InvoiceStatus
    let issueDate: Date
    let dueDate: Date
    let createdAt: Date
    let paidAt: Date?
    let currency: Currency
    let amount: Double
    let paidAmountInBaseCurrency: Double?

    init(_ invoice: Invoice, client: Client?, isVatExempt: Bool) {
        id = invoice.id
        clientId = invoice.clientId
        invoiceNumber = invoice.invoiceNumber
        clientName = client?.name ?? "Unknown client"
        clientEmail = client?.email ?? ""
        notes = invoice.notes
        status = invoice.status
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        createdAt = invoice.createdAt
        paidAt = invoice.paidAt
        currency = invoice.currency
        amount = isVatExempt ? invoice.taxableAmount : invoice.total
        paidAmountInBaseCurrency = invoice.paidAmountInBaseCurrency
    }

    init(_ invoice: SDInvoice, isVatExempt: Bool) {
        id = invoice.id
        clientId = invoice.client?.id
        invoiceNumber = invoice.invoiceNumber
        clientName = invoice.client?.name ?? "Unknown client"
        clientEmail = invoice.client?.email ?? ""
        notes = invoice.notes
        status = invoice.status
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        createdAt = invoice.createdAt
        paidAt = invoice.paidAt
        currency = invoice.currency
        let items = invoice.lineItems
        let subtotal = items.reduce(0) { $0 + $1.total }
        let discounted = subtotal - subtotal * invoice.discountPercent / 100 - invoice.discountFixed
        let tax = items.reduce(0) { $0 + $1.total * $1.vatRate / 100 }
        amount = isVatExempt ? discounted : discounted + tax
        paidAmountInBaseCurrency = invoice.paidAmountInBaseCurrency
    }

    var statusTitle: String { effectiveStatus().rawValue }

    func effectiveStatus(at now: Date = Date(), calendar: Calendar = .current) -> InvoiceStatus {
        InvoiceStatus.effective(status, dueDate: dueDate, at: now, calendar: calendar)
    }

    func baseAmount(in currency: Currency) -> Double? {
        if status == .paid, let converted = paidAmountInBaseCurrency { return converted }
        return self.currency == currency ? amount : nil
    }
}

struct InvoiceTotals {
    var baseAmount: Double = 0
    var excluded: [Currency: Double] = [:]
    var count = 0

    mutating func add(_ invoice: InvoiceSummary, baseCurrency: Currency) {
        count += 1
        if let amount = invoice.baseAmount(in: baseCurrency) {
            baseAmount += amount
        } else {
            excluded[invoice.currency, default: 0] += invoice.amount
        }
    }

    var exclusionDescription: String? {
        guard !excluded.isEmpty else { return nil }
        return "Plus " + excluded.keys.sorted { $0.rawValue < $1.rawValue }.map {
            MiraFormat.currency(excluded[$0] ?? 0, $0)
        }.joined(separator: ", ") + " (not converted)"
    }
}

struct DashboardMetrics {
    var month = InvoiceTotals()
    var year = InvoiceTotals()
    var outstanding = InvoiceTotals()
    var overdue = InvoiceTotals()
    var revenueExclusions = InvoiceTotals()
    var missingPaymentDates = 0
    var revenue: [(month: String, amount: Double)] = []
    var topClients: [(id: UUID, name: String, total: Double)] = []

    init(invoices: [InvoiceSummary], baseCurrency: Currency, now: Date = Date(), calendar: Calendar = .current) {
        let dates = (0..<6).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: now) }
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let yearInterval = calendar.dateInterval(of: .year, for: now)
        let revenueIntervals = dates.compactMap { calendar.dateInterval(of: .month, for: $0) }
        func contains(_ interval: DateInterval?, _ date: Date) -> Bool {
            guard let interval else { return false }
            return date >= interval.start && date < interval.end
        }
        var amounts = Array(repeating: 0.0, count: dates.count)
        var clients: [UUID: (name: String, total: Double)] = [:]
        for invoice in invoices {
            let status = invoice.effectiveStatus(at: now, calendar: calendar)
            if status == .sent || status == .overdue { outstanding.add(invoice, baseCurrency: baseCurrency) }
            if status == .overdue { overdue.add(invoice, baseCurrency: baseCurrency) }
            guard status == .paid else { continue }
            guard let paid = invoice.paidAt else { missingPaymentDates += 1; continue }
            if contains(monthInterval, paid) { month.add(invoice, baseCurrency: baseCurrency) }
            if contains(yearInterval, paid) {
                year.add(invoice, baseCurrency: baseCurrency)
                if let id = invoice.clientId, let amount = invoice.baseAmount(in: baseCurrency) {
                    let previous = clients[id]?.total ?? 0
                    clients[id] = (invoice.clientName, previous + amount)
                }
            }
            if let index = revenueIntervals.firstIndex(where: { contains($0, paid) }),
               let amount = invoice.baseAmount(in: baseCurrency) { amounts[index] += amount }
            if revenueIntervals.contains(where: { contains($0, paid) }), invoice.baseAmount(in: baseCurrency) == nil {
                revenueExclusions.add(invoice, baseCurrency: baseCurrency)
            }
        }
        revenue = zip(dates, amounts).map { ($0.0.formatted(.dateTime.month(.abbreviated)), $0.1) }
        topClients = clients.map { (id: $0.key, name: $0.value.name, total: $0.value.total) }
            .sorted { $0.total > $1.total }
    }
}

enum MiraFormat {
    static func currency(_ value: Double, _ currency: Currency) -> String {
        value.formatted(.currency(code: currency.rawValue))
    }
    static func date(_ date: Date) -> String { date.formatted(date: .abbreviated, time: .omitted) }
}

enum InvoiceValidation {
    static func issues(for invoice: Invoice, hasClient: Bool, existingNumbers: [String], calendar: Calendar = .current) -> [String] {
        var issues: [String] = []
        let number = invoice.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hasClient { issues.append("Select a client.") }
        if number.isEmpty { issues.append("Enter an invoice number.") }
        else if existingNumbers.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(number) == .orderedSame }) {
            issues.append("This invoice number is already in use.")
        }
        if calendar.startOfDay(for: invoice.dueDate) < calendar.startOfDay(for: invoice.issueDate) {
            issues.append("Due date must be on or after the issue date.")
        }
        if invoice.lineItems.isEmpty { issues.append("Add at least one line item.") }
        for (index, item) in invoice.lineItems.enumerated() {
            if item.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Add a description for item \(index + 1).") }
            if !item.quantity.isFinite || item.quantity <= 0 { issues.append("Item \(index + 1) needs a quantity greater than zero.") }
            if !item.unitPrice.isFinite || item.unitPrice < 0 { issues.append("Item \(index + 1) needs a valid, nonnegative price.") }
        }
        return issues
    }
}

enum MiraPersistenceError: LocalizedError {
    case missingRecord
    case missingClient
    case exportFailed
    var errorDescription: String? {
        switch self {
        case .missingRecord: return "This record is no longer available. Close this window and refresh the list."
        case .missingClient: return "The selected client is no longer available. Select another client."
        case .exportFailed: return "The PDF could not be saved. Choose a writable folder and try again."
        }
    }
}

@MainActor
enum CompanyProfileStore {
    static func resolve(_ profiles: [SDCompanyProfile], legacy: CompanyProfile?) -> CompanyProfile? {
        MigrationService.shared.useSwiftData ? profiles.first?.toLegacy() : legacy
    }

    static func save(_ profile: CompanyProfile, profiles: [SDCompanyProfile], context: ModelContext, appState: AppState) throws {
        if MigrationService.shared.useSwiftData {
            guard let stored = profiles.first else { throw MiraPersistenceError.missingRecord }
            stored.update(from: profile)
            do { try context.save() }
            catch { context.rollback(); throw error }
        } else {
            try appState.persistCompanyProfile(profile)
            appState.companyProfile = profile
        }
    }
}

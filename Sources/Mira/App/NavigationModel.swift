import SwiftUI
import Observation

/// Top-level sections shown in the sidebar.
enum MainSection: String, Hashable, CaseIterable, Identifiable {
    case overview
    case invoices
    case clients

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .invoices: return "Invoices"
        case .clients: return "Clients"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .invoices: return "doc.text"
        case .clients: return "person.2"
        }
    }
}

/// Sheets presented from the main window.
enum MainSheet: Identifiable {
    case newInvoice(clientID: UUID?)
    case editInvoice(Invoice)
    case newClient
    case editClient(Client)
    case shortcuts

    var id: String {
        switch self {
        case .newInvoice: return "newInvoice"
        case .editInvoice(let invoice): return "editInvoice-\(invoice.id)"
        case .newClient: return "newClient"
        case .editClient(let client): return "editClient-\(client.id)"
        case .shortcuts: return "shortcuts"
        }
    }
}

/// UI navigation state shared across the main window: which section is open,
/// which invoice/client is selected, and which sheet is up. Kept separate from
/// `AppState` (legacy data) so views can observe navigation without
/// re-rendering on every data change.
@MainActor
@Observable
final class NavigationModel {
    var section: MainSection = .overview
    var invoiceFilter: InvoiceStatus? = nil
    var selectedInvoiceID: UUID? = nil
    var selectedClientID: UUID? = nil
    var sheet: MainSheet? = nil

    func showInvoices(filter: InvoiceStatus? = nil) {
        section = .invoices
        invoiceFilter = filter
    }

    func reveal(invoiceID: UUID) {
        section = .invoices
        invoiceFilter = nil
        selectedInvoiceID = invoiceID
    }

    func reveal(clientID: UUID) {
        section = .clients
        selectedClientID = clientID
    }
}

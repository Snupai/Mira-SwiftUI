import SwiftUI
import SwiftData

/// Invoices as a sortable, searchable table with the selected invoice in a
/// trailing inspector. Double-click a draft to edit it.
struct InvoicesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(NavigationModel.self) private var nav
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SDInvoice.issueDate, order: .reverse) private var sdInvoices: [SDInvoice]
    @Query private var sdClients: [SDClient]
    @Query private var sdProfiles: [SDCompanyProfile]

    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\Row.issueDate, order: .reverse)]
    @State private var showInspector = true
    @State private var pendingDelete: Invoice?

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }

    private var profile: CompanyProfile? {
        usesSwiftData ? sdProfiles.first?.toLegacy() : appState.companyProfile
    }
    private var isVatExempt: Bool { profile?.isVatExempt ?? false }
    private var baseCurrency: Currency { profile?.defaultCurrency ?? .eur }

    private var allInvoices: [Invoice] {
        usesSwiftData ? sdInvoices.map { $0.toLegacy() } : appState.invoices
    }
    private var allClients: [Client] {
        usesSwiftData ? sdClients.map { $0.toLegacy() } : appState.clients
    }
    private var clientsByID: [UUID: Client] {
        Dictionary(uniqueKeysWithValues: allClients.map { ($0.id, $0) })
    }

    // MARK: Rows

    struct Row: Identifiable {
        let id: UUID
        let number: String
        let clientName: String
        let issueDate: Date
        let dueDate: Date
        let amount: Double
        let currency: Currency
        let status: InvoiceStatus
        let statusRank: Int
        let invoice: Invoice
    }

    private func effectiveStatus(_ invoice: Invoice) -> InvoiceStatus {
        (invoice.status == .sent && invoice.isOverdue) ? .overdue : invoice.status
    }

    private var rows: [Row] {
        let clients = clientsByID
        var invoices = allInvoices

        if let filter = nav.invoiceFilter {
            invoices = invoices.filter { effectiveStatus($0) == filter }
        }
        if !searchText.isEmpty {
            let needle = searchText.lowercased()
            invoices = invoices.filter { inv in
                let client = clients[inv.clientId]
                return inv.invoiceNumber.lowercased().contains(needle)
                    || client?.name.lowercased().contains(needle) == true
                    || client?.email.lowercased().contains(needle) == true
                    || inv.notes.lowercased().contains(needle)
            }
        }
        let ranks: [InvoiceStatus: Int] = [.overdue: 0, .sent: 1, .draft: 2, .paid: 3, .cancelled: 4]
        return invoices.map { inv in
            let status = effectiveStatus(inv)
            return Row(
                id: inv.id,
                number: inv.invoiceNumber,
                clientName: clients[inv.clientId]?.name ?? "—",
                issueDate: inv.issueDate,
                dueDate: inv.dueDate,
                amount: isVatExempt ? inv.subtotal : inv.total,
                currency: inv.currency,
                status: status,
                statusRank: ranks[status, default: 9],
                invoice: inv
            )
        }
        .sorted(using: sortOrder)
    }

    private var outstanding: (count: Int, total: Double) {
        let open = allInvoices.filter { $0.status == .sent || $0.status == .overdue }
        let total = open.reduce(0.0) { sum, inv in
            inv.currency == baseCurrency ? sum + (isVatExempt ? inv.subtotal : inv.total) : sum
        }
        return (open.count, total)
    }

    private var subtitle: String {
        if nav.invoiceFilter != nil {
            let n = rows.count
            return "\(n) \(n == 1 ? "invoice" : "invoices")"
        }
        let o = outstanding
        if o.count == 0 { return "Nothing outstanding" }
        return "\(o.count) outstanding, \(Money.compact(o.total, baseCurrency))"
    }

    // MARK: Body

    var body: some View {
        @Bindable var nav = nav
        Group {
            if rows.isEmpty {
                emptyState
            } else {
                table
            }
        }
        .navigationTitle(nav.invoiceFilter?.rawValue ?? "Invoices")
        .navigationSubtitle(subtitle)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search invoices")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Picker("Status", selection: $nav.invoiceFilter) {
                    Text("All").tag(InvoiceStatus?.none)
                    Divider()
                    ForEach(InvoiceStatus.allCases, id: \.self) { status in
                        Label(status.rawValue, systemImage: status.symbol).tag(InvoiceStatus?.some(status))
                    }
                }
                .pickerStyle(.menu)
                .help("Filter by status")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("New invoice", systemImage: "plus") {
                    nav.sheet = .newInvoice(clientID: nil)
                }
                .help("New invoice (⌘N)")
            }
            ToolbarItem(placement: .automatic) {
                Button("Inspector", systemImage: "sidebar.trailing") {
                    withAnimation { showInspector.toggle() }
                }
                .help("Show or hide the inspector")
            }
        }
        .inspector(isPresented: $showInspector) {
            Group {
                if let id = nav.selectedInvoiceID, allInvoices.contains(where: { $0.id == id }) {
                    InvoiceInspector(invoiceID: id)
                } else {
                    ContentUnavailableView {
                        Label("No invoice selected", systemImage: "doc.text")
                    } description: {
                        Text("Select an invoice to see its preview, status and actions.")
                    }
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 340, max: 460)
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.invoiceNumber ?? "invoice")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete invoice", role: .destructive) {
                if let invoice = pendingDelete {
                    actions.delete(invoice)
                    if nav.selectedInvoiceID == invoice.id { nav.selectedInvoiceID = nil }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This permanently removes the invoice. Exported PDFs are not affected.")
        }
        .onChange(of: nav.selectedInvoiceID) { _, id in
            if id != nil && !showInspector { withAnimation { showInspector = true } }
        }
        .onAppear {
            // Demo/snapshot runs want something selected so the inspector has content.
            if DemoData.isEnabled, nav.selectedInvoiceID == nil {
                nav.selectedInvoiceID = rows.first(where: { $0.status == .sent })?.id ?? rows.first?.id
            }
        }
    }

    private var actions: InvoiceActions {
        InvoiceActions(modelContext: modelContext, appState: appState, sdInvoices: sdInvoices)
    }

    private var table: some View {
        @Bindable var nav = nav
        return Table(rows, selection: $nav.selectedInvoiceID, sortOrder: $sortOrder) {
            TableColumn("Number", value: \.number) { row in
                Text(row.number)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            .width(min: 112, ideal: 124)

            TableColumn("Client", value: \.clientName) { row in
                Text(row.clientName).lineLimit(1)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Issued", value: \.issueDate) { row in
                Text(Dates.medium.string(from: row.issueDate))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .width(min: 84, ideal: 100)

            TableColumn("Due", value: \.dueDate) { row in
                VStack(alignment: .leading, spacing: 1) {
                    Text(Dates.medium.string(from: row.dueDate))
                        .monospacedDigit()
                        .foregroundStyle(row.status == .overdue ? Color.red : .secondary)
                    if let relative = Dates.relativeDue(row.dueDate, status: row.status) {
                        Text(relative)
                            .font(.caption2)
                            .foregroundStyle(row.status == .overdue ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                    }
                }
            }
            .width(min: 112, ideal: 124)

            TableColumn("Amount", value: \.amount) { row in
                MoneyText(row.amount, row.currency, weight: .medium)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 92, ideal: 110)
            .alignment(.trailing)

            TableColumn("Status", value: \.statusRank) { row in
                StatusBadge(status: row.status)
            }
            .width(min: 76, ideal: 88)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first, let invoice = allInvoices.first(where: { $0.id == id }) {
                contextMenu(for: invoice)
            }
        } primaryAction: { ids in
            guard let id = ids.first, let invoice = allInvoices.first(where: { $0.id == id }) else { return }
            if invoice.status == .draft {
                nav.sheet = .editInvoice(invoice)
            } else {
                nav.selectedInvoiceID = id
                showInspector = true
            }
        }
        .tableStyle(.inset)
        .themedScrollBackground()
        .alternatingRowBackgrounds(.disabled)
    }

    @ViewBuilder
    private func contextMenu(for invoice: Invoice) -> some View {
        let client = clientsByID[invoice.clientId]
        if invoice.status == .draft {
            Button("Edit", systemImage: "pencil") { nav.sheet = .editInvoice(invoice) }
            Button("Mark as sent", systemImage: "paperplane") { actions.markSent(invoice) }
        }
        if invoice.status == .sent || invoice.status == .overdue {
            if invoice.currency == baseCurrency {
                Button("Mark as paid", systemImage: "checkmark.circle") { actions.markPaid(invoice) }
            }
            Button("Back to draft", systemImage: "arrow.uturn.backward") { actions.revertToDraft(invoice) }
        }
        Menu("Export PDF") {
            Button("Deutsch") { actions.exportPDF(invoice, client: client, profile: profile, language: .german) }
            Button("English") { actions.exportPDF(invoice, client: client, profile: profile, language: .english) }
        }
        if let client {
            Button("Show client", systemImage: "person") { nav.reveal(clientID: client.id) }
        }
        Divider()
        if invoice.status != .paid && invoice.status != .cancelled {
            Button("Cancel invoice", systemImage: "xmark.circle") { actions.cancel(invoice) }
        }
        Button("Delete…", systemImage: "trash", role: .destructive) { pendingDelete = invoice }
    }

    private var emptyState: some View {
        Group {
            if allInvoices.isEmpty {
                ContentUnavailableView {
                    Label("No invoices yet", systemImage: "doc.text")
                } description: {
                    Text("Create your first invoice. Pick a client, add what you did, and Mira handles numbering, VAT and the PDF.")
                } actions: {
                    Button("New invoice") { nav.sheet = .newInvoice(clientID: nil) }
                        .buttonStyle(.borderedProminent)
                }
            } else if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView {
                    Label("No \(nav.invoiceFilter?.rawValue.lowercased() ?? "") invoices", systemImage: nav.invoiceFilter?.symbol ?? "doc.text")
                } description: {
                    Text("Nothing has this status right now.")
                } actions: {
                    Button("Show all invoices") { nav.invoiceFilter = nil }
                }
            }
        }
    }
}

#Preview {
    InvoicesView()
        .environmentObject(AppState())
        .environment(NavigationModel())
}

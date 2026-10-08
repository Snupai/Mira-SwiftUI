import SwiftUI
import SwiftData

/// Owned by the window shell so browsing survives navigation.
struct InvoiceBrowsingState {
    var searchText = ""
    var selectedStatus: InvoiceStatus?
    var onlyOutstanding = false
    var paidPeriod: PaidInvoicePeriod?
    var sortOrder = [KeyPathComparator(\InvoiceSummary.issueDate, order: .reverse)]
}

struct InvoiceListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) var colors
    @Query(sort: \SDInvoice.issueDate, order: .reverse) private var sdInvoices: [SDInvoice]
    @Query private var sdProfiles: [SDCompanyProfile]
    @Binding var browsingState: InvoiceBrowsingState
    @State private var showingNewInvoice = false
    @State private var selectedInvoice: Invoice?
    @State private var editingInvoice: Invoice?

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }
    private var summaries: [InvoiceSummary] {
        let exempt = usesSwiftData ? sdProfiles.first?.isVatExempt ?? false : appState.companyProfile?.isVatExempt ?? false
        if usesSwiftData { return sdInvoices.map { InvoiceSummary($0, isVatExempt: exempt) } }
        let clients = Dictionary(appState.clients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return appState.invoices.map { InvoiceSummary($0, client: clients[$0.clientId], isVatExempt: exempt) }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let all = summaries
            let search = browsingState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let filtered = all.filter { invoice in
                let status = invoice.effectiveStatus(at: timeline.date)
                let statusMatches = browsingState.onlyOutstanding ? (status == .sent || status == .overdue) : (browsingState.selectedStatus == nil || status == browsingState.selectedStatus)
                let searchMatches = search.isEmpty || [invoice.invoiceNumber, invoice.clientName, invoice.clientEmail, invoice.notes]
                    .contains { $0.localizedCaseInsensitiveContains(search) }
                let periodMatches = browsingState.paidPeriod.map { period in
                    guard let paid = invoice.paidAt else { return false }
                    return Calendar.current.isDate(paid, equalTo: timeline.date, toGranularity: period == .month ? .month : .year)
                } ?? true
                return statusMatches && searchMatches && periodMatches
            }.sorted(using: browsingState.sortOrder)
            VStack(spacing: 0) {
                HStack {
                    Picker("Invoice status", selection: Binding(get: { browsingState.selectedStatus }, set: { browsingState.selectedStatus = $0; browsingState.onlyOutstanding = false; browsingState.paidPeriod = nil })) {
                        Text("All").tag(InvoiceStatus?.none)
                        ForEach(InvoiceStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(InvoiceStatus?.some(status))
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 480)
                    Spacer()
                    Text("\(filtered.count) of \(all.count)")
                        .font(.caption).foregroundStyle(colors.subtext)
                        .accessibilityLabel("\(filtered.count) of \(all.count) invoices")
                }
                .padding(16)
                if browsingState.onlyOutstanding || browsingState.paidPeriod != nil {
                    HStack {
                        Text(browsingState.onlyOutstanding ? "Outstanding invoices · Sent and Overdue" : "Collected this \(browsingState.paidPeriod == .month ? "month" : "year") · by payment date").font(.caption)
                        Button("Show All") { browsingState.onlyOutstanding = false; browsingState.paidPeriod = nil; browsingState.selectedStatus = nil }
                        Spacer()
                    }.padding(.horizontal, 16).padding(.bottom, 10)
                }
                Divider()
                if filtered.isEmpty {
                    ContentUnavailableView {
                        Label(all.isEmpty ? "No invoices yet" : "No matching invoices", systemImage: all.isEmpty ? "doc.text" : "magnifyingglass")
                    } description: {
                        Text(all.isEmpty ? "Create an invoice to start tracking your work." : "Try another search or clear your filters.")
                    } actions: {
                        if all.isEmpty { Button("Create your first invoice") { showingNewInvoice = true } }
                        else { Button("Clear filters") { browsingState.searchText = ""; browsingState.selectedStatus = nil; browsingState.onlyOutstanding = false; browsingState.paidPeriod = nil } }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    InvoiceTableView(invoices: filtered, now: timeline.date, sortOrder: $browsingState.sortOrder,
                        onOpen: openInvoice, onEdit: { editingInvoice = resolve($0) })
                }
            }
            .background(colors.base)
        }
        .navigationTitle("Invoices")
        .searchable(text: $browsingState.searchText, prompt: "Search invoices, clients…")
        .toolbar {
            ToolbarItem {
                Button("New Invoice", systemImage: "plus") { showingNewInvoice = true }
                    .miraPrimaryAction().help("New Invoice (⌘N)")
            }
        }
        .sheet(isPresented: $showingNewInvoice) {
            InvoiceEditorView(invoice: nil).environmentObject(appState).environment(\.themeColors, colors)
        }
        .sheet(item: $selectedInvoice) { invoice in
            InvoiceDetailView(invoice: invoice).environmentObject(appState).environment(\.themeColors, colors)
        }
        .sheet(item: $editingInvoice) { invoice in
            InvoiceEditorView(invoice: invoice).environmentObject(appState).environment(\.themeColors, colors)
        }
    }

    private func resolve(_ id: UUID) -> Invoice? {
        usesSwiftData ? sdInvoices.first { $0.id == id }?.toLegacy() : appState.invoices.first { $0.id == id }
    }
    private func openInvoice(_ id: UUID) { selectedInvoice = resolve(id) }
}

enum PaidInvoicePeriod { case month, year }


/// Selection stays local so arrow-key navigation does not rebuild the invoice projection.
private struct InvoiceTableView: View {
    @Environment(\.themeColors) private var colors
    let invoices: [InvoiceSummary]
    let now: Date
    @Binding var sortOrder: [KeyPathComparator<InvoiceSummary>]
    let onOpen: (UUID) -> Void
    let onEdit: (UUID) -> Void
    @State private var selection: UUID?
    @FocusState private var listFocused: Bool

    var body: some View {
        Table(invoices, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Invoice", value: \.invoiceNumber) { invoice in
                Text(invoice.invoiceNumber).fontWeight(.medium)
            }.width(min: 130, ideal: 170)
            TableColumn("Client", value: \.clientName).width(min: 100, ideal: 160)
            TableColumn("Issued", value: \.issueDate) { invoice in
                Text(MiraFormat.date(invoice.issueDate)).foregroundStyle(colors.subtext)
            }.width(min: 85, ideal: 110)
            TableColumn("Due", value: \.dueDate) { invoice in
                Text(MiraFormat.date(invoice.dueDate))
                    .foregroundStyle(invoice.effectiveStatus(at: now) == .overdue ? Color.red : colors.subtext)
            }.width(min: 85, ideal: 110)
            TableColumn("Amount", value: \.amount) { invoice in
                Text(MiraFormat.currency(invoice.amount, invoice.currency)).monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }.width(min: 100, ideal: 130)
            TableColumn("Status", value: \.statusTitle) { invoice in
                StatusBadge(status: invoice.effectiveStatus(at: now))
            }.width(90)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first {
                Button("Open Invoice") { onOpen(id) }
                if invoices.first(where: { $0.id == id })?.status == .draft {
                    Button("Edit Draft") { onEdit(id) }
                }
            }
        } primaryAction: { ids in
            if let id = ids.first { onOpen(id) }
        }
        .focusable()
        .focused($listFocused)
        .onChange(of: selection) { _, value in if value != nil { listFocused = true } }
        .onKeyPress(.return) {
            guard let selection else { return .ignored }
            onOpen(selection)
            return .handled
        }
        .onChange(of: invoices.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) { self.selection = nil }
        }
            .toolbar {
                ToolbarItem {
                    Button("Open", systemImage: "doc.text.magnifyingglass") {
                        if let selection { onOpen(selection) }
                    }
                    .disabled(selection == nil).help("Open selected invoice (Return)")
                }
            }
    }
}

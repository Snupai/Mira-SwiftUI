import SwiftUI
import SwiftData

/// Owned by the shell so search, filtering, and sorting survive section changes.
struct InvoiceBrowsingState {
    var searchText = ""
    var selectedStatus: InvoiceStatus?
    var sortBy: InvoiceListView.SortOption = .dateDesc
}

struct InvoiceListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) var colors
    @Environment(\.modelContext) private var modelContext
    
    // SwiftData queries
    @Query(sort: \SDInvoice.issueDate, order: .reverse) private var sdInvoices: [SDInvoice]
    @Query private var sdClients: [SDClient]
    @Query private var sdProfiles: [SDCompanyProfile]
    
    @Binding var browsingState: InvoiceBrowsingState
    @State private var showingNewInvoice = false
    @State private var selectedInvoice: Invoice?
    @State private var selectedSDInvoice: SDInvoice?
    
    enum SortOption: String, CaseIterable {
        case dateDesc = "Newest"
        case dateAsc = "Oldest"
        case amountDesc = "Highest"
        case amountAsc = "Lowest"
        case client = "Client"
    }
    
    // Use SwiftData if migrated or no legacy data exists
    private var usesSwiftData: Bool {
        MigrationService.shared.useSwiftData
    }
    
    var isVatExempt: Bool { 
        if let profile = sdProfiles.first {
            return profile.isVatExempt
        }
        return appState.companyProfile?.isVatExempt ?? false 
    }
    
    var baseCurrency: Currency { 
        if let profile = sdProfiles.first {
            return profile.defaultCurrency
        }
        return appState.companyProfile?.defaultCurrency ?? .eur 
    }
    
    private var allInvoices: [Invoice] {
        if usesSwiftData {
            return sdInvoices.map { $0.toLegacy() }
        }
        return appState.invoices
    }
    
    private var allClients: [Client] {
        if usesSwiftData {
            return sdClients.map { $0.toLegacy() }
        }
        return appState.clients
    }
    
    var filteredInvoices: [Invoice] {
        var invoices = allInvoices
        
        // Status filter
        if let status = browsingState.selectedStatus {
            invoices = invoices.filter { $0.status == status }
        }
        
        // Search filter
        if !browsingState.searchText.isEmpty {
            invoices = invoices.filter { inv in
                let client = allClients.first { $0.id == inv.clientId }
                let searchLower = browsingState.searchText.lowercased()
                return inv.invoiceNumber.lowercased().contains(searchLower) ||
                       client?.name.lowercased().contains(searchLower) == true ||
                       client?.email.lowercased().contains(searchLower) == true ||
                       inv.notes.lowercased().contains(searchLower)
            }
        }
        
        // Sort
        switch browsingState.sortBy {
        case .dateDesc: invoices.sort { $0.issueDate > $1.issueDate }
        case .dateAsc: invoices.sort { $0.issueDate < $1.issueDate }
        case .amountDesc: invoices.sort { $0.total > $1.total }
        case .amountAsc: invoices.sort { $0.total < $1.total }
        case .client:
            invoices.sort { inv1, inv2 in
                let c1 = allClients.first { $0.id == inv1.clientId }?.name ?? ""
                let c2 = allClients.first { $0.id == inv2.clientId }?.name ?? ""
                return c1 < c2
            }
        }
        
        return invoices
    }
    
    private var invoiceCount: Int {
        usesSwiftData ? sdInvoices.count : appState.invoices.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Status remains scoped to invoice content; search and actions use the toolbar.
            HStack(spacing: 6) {
                Picker("Invoice status", selection: $browsingState.selectedStatus) {
                    Text("All").tag(InvoiceStatus?.none)
                    Text("Draft").tag(InvoiceStatus?.some(.draft))
                    Text("Sent").tag(InvoiceStatus?.some(.sent))
                    Text("Paid").tag(InvoiceStatus?.some(.paid))
                    Text("Overdue").tag(InvoiceStatus?.some(.overdue))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 420)
                Spacer()
                Text("\(invoiceCount) invoices")
                    .font(.caption)
                    .foregroundStyle(colors.subtext)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider().background(colors.surface1)
            
            // List
            if filteredInvoices.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    if invoiceCount == 0 {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(colors.subtext)
                        Text("No invoices yet")
                            .font(.system(size: 17))
                            .foregroundColor(colors.subtext)
                        Button("Create your first invoice") { showingNewInvoice = true }
                            .buttonStyle(.plain)
                            .foregroundColor(colors.accent)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(colors.subtext)
                        Text("No matching invoices")
                            .font(.system(size: 15))
                            .foregroundColor(colors.subtext)
                        Button("Clear filters") {
                            browsingState.searchText = ""
                            browsingState.selectedStatus = nil
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(colors.accent)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredInvoices) { invoice in
                            InvoiceRow(
                                invoice: invoice,
                                client: allClients.first { $0.id == invoice.clientId },
                                colors: colors,
                                isVatExempt: isVatExempt,
                                baseCurrency: baseCurrency
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { selectedInvoice = invoice }
                            Divider().background(colors.surface0)
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .background(colors.base)
        .navigationTitle("Invoices")
        .searchable(text: $browsingState.searchText, prompt: "Search invoices, clients...")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Sort invoices", selection: $browsingState.sortBy) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label("Sort: \(browsingState.sortBy.rawValue)", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort invoices")
                .accessibilityLabel("Sort invoices: \(browsingState.sortBy.rawValue)")
            }
            ToolbarItem {
                Button("New Invoice", systemImage: "plus") { showingNewInvoice = true }
                    .miraPrimaryAction()
                    .help("New Invoice (⌘N)")
            }
        }
        .sheet(isPresented: $showingNewInvoice) {
            InvoiceEditorView(invoice: nil).environmentObject(appState).environment(\.themeColors, colors)
        }
        .sheet(item: $selectedInvoice) { invoice in
            InvoiceDetailView(invoice: invoice).environmentObject(appState).environment(\.themeColors, colors)
        }
    }
}

struct InvoiceRow: View {
    let invoice: Invoice
    let client: Client?
    let colors: ThemeColors
    let isVatExempt: Bool
    var baseCurrency: Currency = .eur
    
    var displayTotal: Double { isVatExempt ? invoice.subtotal : invoice.total }
    
    // Check if this is a foreign currency invoice with conversion data
    var hasConversionData: Bool {
        invoice.currency != baseCurrency && invoice.paidAmountInBaseCurrency != nil
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.invoiceNumber)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colors.text)
                Text(client?.name ?? "—")
                    .font(.system(size: 14))
                    .foregroundColor(colors.subtext)
            }
            
            Spacer()
            
            Text(formatDate(invoice.issueDate))
                .font(.system(size: 13))
                .foregroundColor(colors.subtext)
                .frame(width: 90)
            
            // Amount column - show original + converted if applicable
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(displayTotal, currency: invoice.currency))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colors.text)
                
                // Show converted amount for paid foreign currency invoices
                if hasConversionData, let baseAmount = invoice.paidAmountInBaseCurrency {
                    Text("≈ \(formatCurrency(baseAmount, currency: baseCurrency)) received")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }
            .frame(width: 140, alignment: .trailing)
            
            Text(invoice.status.rawValue)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
                .frame(width: 80)
        }
        .padding(.vertical, 14)
    }
    
    var statusColor: Color {
        switch invoice.status {
        case .paid: return .green
        case .overdue: return .red
        case .sent: return colors.accent
        case .cancelled: return .orange
        default: return colors.subtext
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
    
    func formatCurrency(_ value: Double, currency: Currency) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.rawValue
        return f.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0"
    }
}

struct InvoiceListView_Previews: PreviewProvider {
    static var previews: some View {
        InvoiceListView(browsingState: .constant(InvoiceBrowsingState())).environmentObject(AppState())
    }
}

import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) var colors
    @State private var searchText = ""
    @State private var selectedStatus: InvoiceStatus? = nil
    @State private var sortBy: SortOption = .dateDesc
    @State private var showingNewInvoice = false
    @State private var selectedInvoice: Invoice?
    
    enum SortOption: String, CaseIterable {
        case dateDesc = "Newest"
        case dateAsc = "Oldest"
        case amountDesc = "Highest"
        case amountAsc = "Lowest"
        case client = "Client"
    }
    
    var isVatExempt: Bool { appState.companyProfile?.isVatExempt ?? false }
    var baseCurrency: Currency { appState.companyProfile?.defaultCurrency ?? .eur }
    
    var filteredInvoices: [Invoice] {
        var invoices = appState.invoices
        
        // Status filter
        if let status = selectedStatus {
            invoices = invoices.filter { $0.status == status }
        }
        
        // Search filter
        if !searchText.isEmpty {
            invoices = invoices.filter { inv in
                let client = appState.clients.first { $0.id == inv.clientId }
                let searchLower = searchText.lowercased()
                return inv.invoiceNumber.lowercased().contains(searchLower) ||
                       client?.name.lowercased().contains(searchLower) == true ||
                       client?.email.lowercased().contains(searchLower) == true ||
                       inv.notes.lowercased().contains(searchLower)
            }
        }
        
        // Sort
        switch sortBy {
        case .dateDesc: invoices.sort { $0.issueDate > $1.issueDate }
        case .dateAsc: invoices.sort { $0.issueDate < $1.issueDate }
        case .amountDesc: invoices.sort { $0.total > $1.total }
        case .amountAsc: invoices.sort { $0.total < $1.total }
        case .client:
            invoices.sort { inv1, inv2 in
                let c1 = appState.clients.first { $0.id == inv1.clientId }?.name ?? ""
                let c2 = appState.clients.first { $0.id == inv2.clientId }?.name ?? ""
                return c1 < c2
            }
        }
        
        return invoices
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Invoices")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(colors.text)
                
                Text("\(appState.invoices.count)")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.surface1)
                    .foregroundColor(colors.subtext)
                    .clipShape(Capsule())
                
                Spacer()
                
                Button(action: { showingNewInvoice = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New Invoice")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 20)
            
            // Search & Filters
            HStack(spacing: 16) {
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(colors.subtext)
                    TextField("Search invoices, clients...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(colors.text)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(colors.subtext)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colors.surface0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 300)
                
                // Status Pills
                HStack(spacing: 6) {
                    StatusPill(title: "All", isSelected: selectedStatus == nil, colors: colors) { selectedStatus = nil }
                    StatusPill(title: "Draft", isSelected: selectedStatus == .draft, colors: colors) { selectedStatus = .draft }
                    StatusPill(title: "Sent", isSelected: selectedStatus == .sent, colors: colors) { selectedStatus = .sent }
                    StatusPill(title: "Paid", isSelected: selectedStatus == .paid, colors: colors) { selectedStatus = .paid }
                    StatusPill(title: "Overdue", isSelected: selectedStatus == .overdue, colors: colors) { selectedStatus = .overdue }
                }
                
                Spacer()
                
                // Sort
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: { sortBy = option }) {
                            HStack {
                                Text(option.rawValue)
                                if sortBy == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortBy.rawValue)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(colors.subtext)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(colors.surface0)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
            
            Divider().background(colors.surface1)
            
            // List
            if filteredInvoices.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    if appState.invoices.isEmpty {
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
                            searchText = ""
                            selectedStatus = nil
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
                                client: appState.clients.first { $0.id == invoice.clientId },
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
        .sheet(isPresented: $showingNewInvoice) {
            InvoiceEditorView(invoice: nil).environmentObject(appState).environment(\.themeColors, colors)
        }
        .sheet(item: $selectedInvoice) { invoice in
            InvoiceDetailView(invoice: invoice).environmentObject(appState).environment(\.themeColors, colors)
        }
    }
}

struct StatusPill: View {
    let title: String
    let isSelected: Bool
    let colors: ThemeColors
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? colors.accent : colors.surface0)
                .foregroundColor(isSelected ? .white : colors.text)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
        InvoiceListView().environmentObject(AppState())
    }
}
